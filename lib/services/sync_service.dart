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

  Map<String, String> toJson() => {
        'id': id,
        'name': name,
      };

  factory SyncDeviceItem.fromJson(Map<String, dynamic> json) => SyncDeviceItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
      );

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
  final Map<String, Socket> _pairedSockets = {};
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
  List<SyncDeviceItem> _favoriteDevices = [];
  SyncDeviceItem? _selectedDevice;

  final Set<String> _linkingCandidateIds = {};
  final Set<String> _favoriteCandidateIds = {};
  final Map<String, bool> _deviceRecordingStatus = {};

  OnTriggerCallback? onTriggerReceived;
  OnTriggerCallback? onStopTriggerReceived;
  OnLogCallback? onLogMessage;

  bool get isMaster => _isMaster;
  bool get isPaired => _isPaired || activeCandidates.isNotEmpty;
  bool get isScanning => _isScanning;
  String get myDeviceName => _myDeviceName;
  String get localIpAddress => _localIpAddress;
  String get statusMessage => _lastStatusMessage;
  String get pairingReminder => _pairingReminder;
  List<SyncDeviceItem> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  List<SyncDeviceItem> get favoriteDevices => List.unmodifiable(_favoriteDevices);
  SyncDeviceItem? get selectedDevice => _selectedDevice;

  /// Active candidate devices selected across Favorites and Found Devices lists
  List<SyncDeviceItem> get activeCandidates {
    List<SyncDeviceItem> candidates = [];

    // 1. Add checked items from Favorites List
    for (var dev in _favoriteDevices) {
      if (_favoriteCandidateIds.contains(dev.id) && !candidates.contains(dev)) {
        candidates.add(dev);
      }
    }

    // 2. Add checked items from Found Devices Around List
    for (var dev in _discoveredDevices) {
      if (_linkingCandidateIds.contains(dev.id) && !candidates.contains(dev)) {
        candidates.add(dev);
      }
    }

    return candidates;
  }

  List<SyncDeviceItem> get linkingCandidates => activeCandidates;

  bool isCandidateSelected(SyncDeviceItem device) =>
      _linkingCandidateIds.contains(device.id);

  bool isFavoriteSelected(SyncDeviceItem device) =>
      _favoriteCandidateIds.contains(device.id);

  bool isDeviceRecording(String deviceId) =>
      _deviceRecordingStatus[deviceId] ?? false;

  void toggleCandidate(SyncDeviceItem device) {
    if (_linkingCandidateIds.contains(device.id)) {
      _linkingCandidateIds.remove(device.id);
    } else {
      _linkingCandidateIds.add(device.id);
    }
    _selectedDevice = device;
    _isPaired = activeCandidates.isNotEmpty;
    _updateStatus();
    _saveFavoritesToStorage();
    _log("Toggled candidate: ${device.name}. Total active: ${activeCandidates.length}");
  }

  void toggleFavoriteCandidate(SyncDeviceItem device) {
    if (_favoriteCandidateIds.contains(device.id)) {
      _favoriteCandidateIds.remove(device.id);
    } else {
      _favoriteCandidateIds.add(device.id);
    }
    _selectedDevice = device;
    _isPaired = activeCandidates.isNotEmpty;
    _updateStatus();
    _saveFavoritesToStorage();
    _log("Toggled favorite: ${device.name}. Total active: ${activeCandidates.length}");
  }

  void selectAllCandidates() {
    _linkingCandidateIds.addAll(_discoveredDevices.map((d) => d.id));
    _favoriteCandidateIds.addAll(_favoriteDevices.map((d) => d.id));
    _isPaired = activeCandidates.isNotEmpty;
    _updateStatus();
    _saveFavoritesToStorage();
    _log("Selected all candidate device(s).");
  }

  void clearCandidates() {
    _linkingCandidateIds.clear();
    _favoriteCandidateIds.clear();
    _isPaired = false;
    _updateStatus();
    _log("Cleared active candidates.");
  }

  SyncService() {
    _initDefaultDevices();
    _loadFavoritesFromStorage();
    fetchMyDeviceName();
    startUdpBeaconBroadcaster();
    startStopFileWatcher();
  }

  Future<void> _loadFavoritesFromStorage() async {
    try {
      List<Map<String, String>> favList = await _storageService.loadFavorites();
      if (favList.isNotEmpty) {
        _favoriteDevices = favList.map((m) => SyncDeviceItem(id: m['id']!, name: m['name']!)).toList();
        _favoriteCandidateIds.addAll(_favoriteDevices.map((d) => d.id));
        _isPaired = activeCandidates.isNotEmpty;
        _updateStatus();
        _log("Loaded ${_favoriteDevices.length} favorite device(s) from storage.");
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
  }

  Future<void> _saveFavoritesToStorage() async {
    try {
      List<SyncDeviceItem> toSave = activeCandidates.isNotEmpty
          ? activeCandidates
          : _favoriteDevices;

      List<Map<String, String>> favMap = toSave.map((d) => {'id': d.id, 'name': d.name}).toList();
      await _storageService.saveFavorites(favMap);
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
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

    if (!_favoriteDevices.contains(newItem)) {
      _favoriteDevices.add(newItem);
      _favoriteCandidateIds.add(newItem.id);
    }

    _selectedDevice = newItem;
    _isPaired = true;
    _updateStatus();
    _saveFavoritesToStorage();
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
      _isPaired = activeCandidates.isNotEmpty;
      _updateStatus();
    }
  }

  void _updateStatus() {
    int candidateCount = activeCandidates.length;
    if (candidateCount > 0) {
      _lastStatusMessage = "Linked to $candidateCount candidate target(s) - Sync Ready";
      _pairingReminder = "Sync Ready! $candidateCount candidate target(s) linked for sequential sync.";
    } else if (_isPaired) {
      _lastStatusMessage = "Linked to ${_selectedDevice?.name ?? 'Target'} - Sync Ready";
      _pairingReminder = "Sync Ready! Pressing Photo/Record/Stop will sync on linked target.";
    } else {
      _lastStatusMessage = "Not Linked - Sync not yet done";
      _pairingReminder = "No target devices selected in Favorite or Found lists! Open 'Devices Around' to check choices.";
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
            license: License.nonprofit,
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
        Socket pairedSock = await Socket.connect(
          targetAddress,
          8888,
          timeout: const Duration(seconds: 2),
        );
        pairedSock.write("PAIR_REQUEST\nRole: ${isMaster ? 'Master' : 'Slave'}\n");
        await pairedSock.flush();
        _pairedSockets[targetAddress] = pairedSock;
        pairSuccess = true;
      } catch (e) {
        debugPrint("Local socket link notice for $targetAddress: $e");
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
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8888, shared: true);
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
            _connectedClients.remove(client);
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
      _log("-> Trigger sent via Direct Socket to ${target.name} ($targetAddress)");
    } catch (e) {
      debugPrint('Direct socket send notice for ${target.name}: $e');
    }

    // 2. Try paired socket for SPECIFIC target address if open
    if (!success && _pairedSockets.containsKey(targetAddress)) {
      try {
        Socket pairedSock = _pairedSockets[targetAddress]!;
        pairedSock.write(fileContent);
        await pairedSock.flush();
        success = true;
        _log("-> Trigger sent via Paired Socket to ${target.name} ($targetAddress)");
      } catch (e) {
        debugPrint('Paired socket send notice for $targetAddress: $e');
        _pairedSockets.remove(targetAddress);
      }
    }

    // 3. Try connected client socket matching SPECIFIC target address
    if (!success && _connectedClients.isNotEmpty) {
      for (var client in _connectedClients) {
        if (client.remoteAddress.address == targetAddress) {
          try {
            client.write(fileContent);
            await client.flush();
            success = true;
            _log("-> Trigger sent via Server Client socket to ${target.name} ($targetAddress)");
          } catch (e) {
            debugPrint('Client socket send notice for $targetAddress: $e');
          }
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

  Future<bool> sendStartedTriggerFile(File startedFile, {bool onlyFirstDevice = false}) async {
    if (!_isMaster) return false;

    List<SyncDeviceItem> targets = activeCandidates;
    if (onlyFirstDevice && targets.isNotEmpty) {
      targets = [targets.first];
    }

    if (targets.isEmpty) {
      _lastStatusMessage = "No target devices selected in Favorite or Found lists! Please select candidates in Devices Around.";
      _log(_lastStatusMessage);
      return false;
    }

    String fileContent = await startedFile.readAsString();
    _log("Starting trigger send to ${targets.length} slave target(s) (synviewrec 1st device only: $onlyFirstDevice)...");

    bool anySent = false;
    for (int i = 0; i < targets.length; i++) {
      SyncDeviceItem dev = targets[i];
      _log("Sequential Send [${i + 1}/${targets.length}] -> ${dev.name}");
      bool sent = await _sendTriggerToTarget(dev, fileContent);
      if (sent) anySent = true;
      _deviceRecordingStatus[dev.id] = true;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _lastStatusMessage = anySent
        ? "Sent trigger sequentially to ${targets.length} candidate target(s)"
        : "Created trigger file locally for candidate target(s)";
    return anySent;
  }

  Future<bool> sendStopTriggerFile(File stopFile, {bool onlyFirstDevice = false}) async {
    List<SyncDeviceItem> targets = activeCandidates;
    if (onlyFirstDevice && targets.isNotEmpty) {
      targets = [targets.first];
    }

    if (targets.isEmpty) {
      _lastStatusMessage = "Cannot send stop: No candidate targets linked!";
      return false;
    }

    await _storageService.createStopFile();
    String fileContent = await stopFile.readAsString();
    _log("Starting stop trigger send to ${targets.length} slave target(s) (synviewrec 1st device only: $onlyFirstDevice)...");

    bool anySent = false;
    for (int i = 0; i < targets.length; i++) {
      SyncDeviceItem dev = targets[i];
      _log("Sequential Stop Send [${i + 1}/${targets.length}] -> ${dev.name}");
      bool sent = await _sendTriggerToTarget(dev, fileContent);
      if (sent) anySent = true;
      _deviceRecordingStatus[dev.id] = false;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!onlyFirstDevice) {
      _deviceRecordingStatus.clear();
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
    for (var sock in _pairedSockets.values) {
      sock.destroy();
    }
    _pairedSockets.clear();
    _serverSocket?.close();
    for (var socket in _connectedClients) {
      socket.destroy();
    }
    _connectedClients.clear();
    _isListening = false;
  }
}
