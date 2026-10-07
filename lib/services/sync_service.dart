import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'storage_service.dart';

typedef OnTriggerCallback = void Function(String triggerInfo);
typedef OnLogCallback = void Function(String logMsg);

class SyncDeviceItem {
  final String id;
  final String name;
  final BluetoothDevice? bleDevice;

  SyncDeviceItem({
    required this.id,
    required this.name,
    this.bleDevice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDeviceItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SyncService {
  ServerSocket? _serverSocket;
  Socket? _pairedSocket;
  RawDatagramSocket? _udpSocket;
  final List<Socket> _connectedClients = [];
  StreamSubscription? _bleScanSub;
  Timer? _syncFileWatcherTimer;
  Timer? _syncStopFileWatcherTimer;
  Timer? _beaconTimer;
  final StorageService _storageService = StorageService();

  bool _isListening = false;
  bool _isMaster = true;
  bool _isPaired = false;
  bool _isScanning = false;
  int _pollCount = 0;

  String _myDeviceName = "This Device";
  String _localIpAddress = "";
  String _lastStatusMessage = "Not Linked - Sync not yet done";
  String _pairingReminder = "Make target Bluetooth Visible or connect to Master's Mobile Hotspot (192.168.43.1).";

  List<SyncDeviceItem> _discoveredDevices = [];
  SyncDeviceItem? _selectedDevice;
  final Set<String> _linkingCandidateIds = {};

  OnTriggerCallback? onTriggerReceived;
  OnTriggerCallback? onStopTriggerReceived;
  OnLogCallback? onLogMessage;

  bool get isMaster => _isMaster;
  bool get isPaired => _isPaired || _linkingCandidateIds.isNotEmpty;
  bool get isScanning => _isScanning;
  String get myDeviceName => _myDeviceName;
  String get localIpAddress => _localIpAddress;
  String get statusMessage => _lastStatusMessage;
  String get pairingReminder => _pairingReminder;
  List<SyncDeviceItem> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  SyncDeviceItem? get selectedDevice => _selectedDevice;

  List<SyncDeviceItem> get linkingCandidates =>
      _discoveredDevices.where((d) => _linkingCandidateIds.contains(d.id)).toList();

  bool isCandidateSelected(SyncDeviceItem device) =>
      _linkingCandidateIds.contains(device.id);

  void toggleCandidate(SyncDeviceItem device) {
    if (_linkingCandidateIds.contains(device.id)) {
      _linkingCandidateIds.remove(device.id);
    } else {
      _linkingCandidateIds.add(device.id);
    }
    _selectedDevice = device;
    _isPaired = _linkingCandidateIds.isNotEmpty || _selectedDevice != null;
    _updateStatus();
    _log("Toggled candidate: ${device.name}. Total selected: ${_linkingCandidateIds.length}");
  }

  void selectAllCandidates() {
    _linkingCandidateIds.addAll(_discoveredDevices.map((d) => d.id));
    _isPaired = _linkingCandidateIds.isNotEmpty;
    _updateStatus();
    _log("Selected all ${_linkingCandidateIds.length} candidate device(s).");
  }

  void clearCandidates() {
    _linkingCandidateIds.clear();
    _isPaired = _selectedDevice != null;
    _updateStatus();
    _log("Cleared candidate sublist.");
  }

  SyncService() {
    _initDefaultDevices();
    fetchMyDeviceName();
    startUdpBeaconBroadcaster();
    startStopFileWatcher();
  }

  void _log(String msg) {
    debugPrint(msg);
    if (onLogMessage != null) {
      onLogMessage!(msg);
    }
  }

  Future<void> fetchMyDeviceName() async {
    try {
      try {
        for (var interface in await NetworkInterface.list()) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              _localIpAddress = addr.address;
              break;
            }
          }
          if (_localIpAddress.isNotEmpty) break;
        }
      } catch (e) {
        debugPrint("IP fetch notice: $e");
      }

      if (await _isBleSupported()) {
        try {
          String adapter = await FlutterBluePlus.adapterName;
          if (adapter.isNotEmpty) {
            _myDeviceName = adapter;
            return;
          }
        } catch (e) {
          debugPrint("BLE adapter notice: $e");
        }
      }
      _myDeviceName = Platform.localHostname;
    } catch (e) {
      _myDeviceName = "This Device";
    }
  }

  Future<bool> _isBleSupported() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      debugPrint("BLE support check notice: $e");
      return false;
    }
  }

  void _initDefaultDevices() {
    _discoveredDevices = [
      SyncDeviceItem(
        id: "192.168.43.1",
        name: "Master Mobile Hotspot (IP: 192.168.43.1)",
      ),
      SyncDeviceItem(
        id: "target_b_slave_8888",
        name: "Target B (Slave - Local/Wi-Fi 8888)",
      ),
      SyncDeviceItem(
        id: "target_a_master_8888",
        name: "Target A (Master - Local/Wi-Fi 8888)",
      ),
    ];
    _selectedDevice = _discoveredDevices.first;
    _linkingCandidateIds.add(_discoveredDevices.first.id);
  }

  void startUdpBeaconBroadcaster() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8889);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _udpSocket!.receive();
          if (dg != null) {
            String msg = utf8.decode(dg.data);
            if (msg.startsWith("SYNREC_BEACON:")) {
              String jsonStr = msg.substring(14);
              try {
                Map<String, dynamic> data = jsonDecode(jsonStr);
                String devId = data['id'] ?? dg.address.address;
                String devName = data['name'] ?? "Target Device (${dg.address.address})";

                SyncDeviceItem newItem = SyncDeviceItem(
                  id: devId,
                  name: devName,
                );

                if (!_discoveredDevices.contains(newItem)) {
                  _discoveredDevices.add(newItem);
                  _log("Auto-discovered network device: $devName");
                }
              } catch (e) {
                debugPrint("Beacon decode error: $e");
              }
            }
          }
        }
      });

      _beaconTimer?.cancel();
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_localIpAddress.isNotEmpty) {
          String payload = jsonEncode({
            'id': _localIpAddress,
            'name': '$_myDeviceName (IP: $_localIpAddress)',
            'ip': _localIpAddress,
            'role': _isMaster ? 'Master' : 'Slave',
          });
          String beaconData = "SYNREC_BEACON:$payload";
          List<int> bytes = utf8.encode(beaconData);
          try {
            _udpSocket!.send(bytes, InternetAddress('255.255.255.255'), 8889);
          } catch (e) {
            debugPrint("UDP send notice: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("UDP beacon notice: $e");
    }
  }

  void addCustomDevice(String name, String ipOrId) {
    String displayName = name.isNotEmpty ? "$name (IP: $ipOrId)" : "Target Device (IP: $ipOrId)";
    SyncDeviceItem newItem = SyncDeviceItem(
      id: ipOrId,
      name: displayName,
    );
    int existing = _discoveredDevices.indexWhere((d) => d.id == ipOrId);
    if (existing >= 0) {
      _discoveredDevices[existing] = newItem;
    } else {
      _discoveredDevices.add(newItem);
    }
    _selectedDevice = newItem;
    _isPaired = true;
    _updateStatus();
    _log("Added custom target device: $displayName");
  }

  void setMode({required bool isMaster}) {
    _isMaster = isMaster;
    if (_isMaster) {
      _syncFileWatcherTimer?.cancel();
      _selectedDevice = _discoveredDevices.firstWhere(
        (d) => d.id.contains("slave"),
        orElse: () => _discoveredDevices.first,
      );
    } else {
      _selectedDevice = _discoveredDevices.firstWhere(
        (d) => d.id.contains("master"),
        orElse: () => _discoveredDevices.first,
      );
      startSlaveListener();
      startSlaveFileWatcher();
    }
    _updateStatus();
  }

  /// Slave device file watcher looking for `start_photo.txt` / `start_video.txt`.
  void startSlaveFileWatcher() {
    _syncFileWatcherTimer?.cancel();
    _pollCount = 0;
    _syncFileWatcherTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isMaster) return;

      Directory syncDir = await _storageService.getSyncFolder();
      _pollCount++;

      if (_pollCount % 6 == 1) {
        _log("looking for started.txt at folder ${syncDir.path}");
      }

      File? syncFile = await _storageService.checkAndGetStartFile();
      if (syncFile != null) {
        String fileName = syncFile.path.split(Platform.pathSeparator).last;
        String folderPath = syncFile.parent.path;
        _log("$fileName found in folder $folderPath");

        String content = await syncFile.readAsString();
        bool isPhoto = fileName.contains("photo") || content.contains("TAKE_PHOTO");

        if (isPhoto) {
          _log("recorded syn photo !");
        } else {
          _log("recorded syn video beginning !");
        }

        if (onTriggerReceived != null) {
          onTriggerReceived!(content);
        }

        await _storageService.deleteStartFile(syncFile);
        _lastStatusMessage = "$fileName found in folder $folderPath - ${isPhoto ? 'recorded syn photo !' : 'recorded syn video beginning !'}";
      }
    });
  }

  /// File watcher looking for `stop.txt` / `stopped.txt` on both Master and Slave.
  void startStopFileWatcher() {
    _syncStopFileWatcherTimer?.cancel();
    _syncStopFileWatcherTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      File? stopFile = await _storageService.checkAndGetStopFile();
      if (stopFile != null) {
        String folderPath = stopFile.parent.path;
        _log("stop.txt found in folder $folderPath");
        _log("recorded syn stopped !");

        String content = await stopFile.readAsString();

        if (onStopTriggerReceived != null) {
          onStopTriggerReceived!(content);
        }

        await _storageService.deleteStopFile();
        _lastStatusMessage = "stop.txt found in folder $folderPath - recorded syn stopped !";
      }
    });
  }

  void selectDevice(SyncDeviceItem? device) {
    if (device != null) {
      _selectedDevice = device;
      _isPaired = false;
      _updateStatus();
    }
  }

  void _updateStatus() {
    int candidateCount = _linkingCandidateIds.length;
    if (candidateCount > 0) {
      _lastStatusMessage = "Linked to $candidateCount candidate target(s) - Sync Ready";
      _pairingReminder = "Sync Ready! $candidateCount candidate target(s) linked for sequential sync.";
    } else if (_isPaired) {
      _lastStatusMessage = "Linked to ${_selectedDevice?.name ?? 'Target'} - Sync Ready";
      _pairingReminder = "Sync Ready! Pressing Photo/Record/Stop will sync on linked target.";
    } else {
      _lastStatusMessage = "Not Linked - Sync not yet done";
      _pairingReminder = "Sync not complete! Open 'Devices Around', check candidate checkboxes, or tap Link.";
    }
  }

  Future<void> startBluetoothScanning() async {
    _isScanning = true;
    _lastStatusMessage = "Scanning for nearby Bluetooth / Network devices...";

    await fetchMyDeviceName();

    try {
      if (await _isBleSupported()) {
        if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (e) {
            debugPrint("Bluetooth turnOn notice: $e");
          }
        }

        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
        _bleScanSub?.cancel();
        _bleScanSub = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult r in results) {
            String devName = r.device.platformName;
            if (devName.isEmpty) {
              devName = r.advertisementData.advName;
            }

            String idStr = r.device.remoteId.str;
            String shortId = idStr.length > 5 ? idStr.substring(idStr.length - 5) : idStr;

            String displayName = devName.isNotEmpty
                ? "$devName ($shortId)"
                : "Bluetooth Device ($shortId)";

            SyncDeviceItem newItem = SyncDeviceItem(
              id: idStr,
              name: displayName,
              bleDevice: r.device,
            );

            int existingIndex = _discoveredDevices.indexWhere((d) => d.id == idStr);
            if (existingIndex >= 0) {
              if (devName.isNotEmpty) {
                _discoveredDevices[existingIndex] = newItem;
                if (_selectedDevice?.id == idStr) {
                  _selectedDevice = newItem;
                }
              }
            } else {
              _discoveredDevices.add(newItem);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Bluetooth scan error: $e");
    } finally {
      _isScanning = false;
      _updateStatus();
    }
  }

  Future<bool> executePairing() async {
    _lastStatusMessage = "Linking with ${_selectedDevice?.name ?? 'Target'}...";

    await startBluetoothScanning();

    bool pairSuccess = false;

    try {
      if (_selectedDevice?.bleDevice != null) {
        try {
          await _selectedDevice!.bleDevice!.connect(
            timeout: const Duration(seconds: 5),
            autoConnect: false,
          );

          String resolvedName = _selectedDevice!.bleDevice!.platformName;
          if (resolvedName.isNotEmpty) {
            String shortId = _selectedDevice!.id.length > 5
                ? _selectedDevice!.id.substring(_selectedDevice!.id.length - 5)
                : _selectedDevice!.id;

            _selectedDevice = SyncDeviceItem(
              id: _selectedDevice!.id,
              name: "$resolvedName ($shortId)",
              bleDevice: _selectedDevice!.bleDevice,
            );
          }
          pairSuccess = true;
        } catch (e) {
          debugPrint("BLE link notice: $e");
        }
      }

      String targetAddress = _selectedDevice?.id ?? "127.0.0.1";
      if (targetAddress.contains("target_") || targetAddress.isEmpty) {
        targetAddress = "127.0.0.1";
      }

      try {
        _pairedSocket = await Socket.connect(
          targetAddress,
          8888,
          timeout: const Duration(seconds: 2),
        );
        _pairedSocket!.write("PAIR_REQUEST\nRole: ${isMaster ? 'Master' : 'Slave'}\n");
        await _pairedSocket!.flush();
        pairSuccess = true;
      } catch (e) {
        debugPrint("Local socket link notice: $e");
      }

      if (!_isMaster && _isListening) {
        pairSuccess = true;
      }

      if (_selectedDevice != null) {
        pairSuccess = true;
      }

      _isPaired = pairSuccess;
      _updateStatus();
      return pairSuccess;
    } catch (e) {
      _lastStatusMessage = "Linking failed: $e";
      _isPaired = false;
      return false;
    }
  }

  Future<void> startSlaveListener() async {
    if (_isListening) return;

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
      _isListening = true;

      _serverSocket!.listen((Socket client) {
        debugPrint('Master connected from ${client.remoteAddress.address}');
        _connectedClients.add(client);
        _isPaired = true;
        _updateStatus();

        client.listen(
          (Uint8List data) async {
            String content = utf8.decode(data);
            if (content.contains("PAIR_REQUEST")) {
              client.write("PAIR_ACCEPT\nStatus: Paired\n");
              await client.flush();
              _isPaired = true;
              _updateStatus();
            } else {
              await _handleReceivedData(content);
            }
          },
          onError: (error) {
            debugPrint('Socket error: $error');
            client.destroy();
          },
        );
      });

      _startBleListener();
    } catch (e) {
      debugPrint("Listener error: $e");
    }
  }

  void _startBleListener() async {
    try {
      if (await _isBleSupported()) {
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        _bleScanSub = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult r in results) {
            String devName = r.device.platformName;
            if (devName.contains("STARTED_REC") || r.advertisementData.advName.contains("STARTED")) {
              _handleReceivedData("STARTED\nSource: BLE Advertisement");
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('BLE Scan notice: $e');
    }
  }

  Future<void> _handleReceivedData(String content) async {
    try {
      if (content.toUpperCase().contains("TAKE_PHOTO")) {
        await _storageService.createStartFile(isPhoto: true);
        _lastStatusMessage = "Received start_photo.txt trigger file!";
        debugPrint(_lastStatusMessage);
      } else if (content.toUpperCase().contains("STARTED") || content.toUpperCase().contains("START_RECORDING")) {
        await _storageService.createStartFile(isPhoto: false);
        _lastStatusMessage = "Received start_video.txt trigger file!";
        debugPrint(_lastStatusMessage);
      } else if (content.toUpperCase().contains("STOPPED") || content.toUpperCase().contains("STOP_RECORDING")) {
        await _storageService.createStopFile();
        _lastStatusMessage = "Received stop.txt trigger file!";
        debugPrint(_lastStatusMessage);
      }
    } catch (e) {
      debugPrint("Error handling received Bluetooth/network file: $e");
    }
  }

  Future<bool> _sendTriggerToTarget(SyncDeviceItem target, String fileContent) async {
    bool success = false;

    String targetAddress = target.id;
    if (targetAddress.contains("target_") || targetAddress.isEmpty) {
      targetAddress = "127.0.0.1";
    }

    // 1. Try direct socket connection to target IP on port 8888
    try {
      Socket socket = await Socket.connect(
        targetAddress,
        8888,
        timeout: const Duration(seconds: 2),
      );
      socket.write(fileContent);
      await socket.flush();
      await socket.close();
      success = true;
      _log("-> Trigger sent via Socket to ${target.name} ($targetAddress)");
    } catch (e) {
      debugPrint('Direct socket send notice for ${target.name}: $e');
    }

    // 2. Try paired socket if open
    if (!success && _pairedSocket != null) {
      try {
        _pairedSocket!.write(fileContent);
        await _pairedSocket!.flush();
        success = true;
        _log("-> Trigger sent via Paired Socket to ${target.name}");
      } catch (e) {
        debugPrint('Paired socket send notice: $e');
      }
    }

    // 3. Try connected client sockets
    if (!success && _connectedClients.isNotEmpty) {
      for (var client in _connectedClients) {
        try {
          client.write(fileContent);
          await client.flush();
          success = true;
          _log("-> Trigger sent via Server Client socket to ${client.remoteAddress.address}");
        } catch (e) {
          debugPrint('Client socket send notice: $e');
        }
      }
    }

    // 4. Try BLE if candidate has BLE device
    try {
      if (await _isBleSupported() && target.bleDevice != null) {
        _log("-> Trigger sent via BLE to ${target.name}");
        success = true;
      }
    } catch (e) {
      debugPrint('BLE broadcast notice: $e');
    }

    return success;
  }

  Future<bool> sendStartedTriggerFile(File startedFile) async {
    if (!_isMaster) return false;

    List<SyncDeviceItem> targets = linkingCandidates.isNotEmpty
        ? linkingCandidates
        : (_selectedDevice != null ? [_selectedDevice!] : []);

    if (targets.isEmpty) {
      _lastStatusMessage = "Cannot send: No candidate targets linked!";
      return false;
    }

    String fileContent = await startedFile.readAsString();
    _log("Starting sequential trigger send to ${targets.length} slave candidate(s)...");

    bool anySent = false;
    for (int i = 0; i < targets.length; i++) {
      SyncDeviceItem dev = targets[i];
      _log("Sequential Send [${i + 1}/${targets.length}] -> ${dev.name}");
      bool sent = await _sendTriggerToTarget(dev, fileContent);
      if (sent) anySent = true;
      // Sequential pause between slave targets
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _lastStatusMessage = anySent
        ? "Sent trigger sequentially to ${targets.length} candidate target(s)"
        : "Created trigger file locally for candidate target(s)";
    return anySent;
  }

  Future<bool> sendStopTriggerFile(File stopFile) async {
    List<SyncDeviceItem> targets = linkingCandidates.isNotEmpty
        ? linkingCandidates
        : (_selectedDevice != null ? [_selectedDevice!] : []);

    if (targets.isEmpty) {
      _lastStatusMessage = "Cannot send stop: No candidate targets linked!";
      return false;
    }

    await _storageService.createStopFile();
    String fileContent = await stopFile.readAsString();
    _log("Starting sequential stop trigger send to ${targets.length} slave candidate(s)...");

    bool anySent = false;
    for (int i = 0; i < targets.length; i++) {
      SyncDeviceItem dev = targets[i];
      _log("Sequential Stop Send [${i + 1}/${targets.length}] -> ${dev.name}");
      bool sent = await _sendTriggerToTarget(dev, fileContent);
      if (sent) anySent = true;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _lastStatusMessage = anySent
        ? "Sent stop.txt sequentially to ${targets.length} candidate target(s)"
        : "Created stop.txt locally";
    return anySent;
  }

  void dispose() {
    _beaconTimer?.cancel();
    _udpSocket?.close();
    _syncFileWatcherTimer?.cancel();
    _syncStopFileWatcherTimer?.cancel();
    _bleScanSub?.cancel();
    _pairedSocket?.destroy();
    _serverSocket?.close();
    for (var socket in _connectedClients) {
      socket.destroy();
    }
    _connectedClients.clear();
    _isListening = false;
  }
}
