import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../services/camera_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/video_stream_service.dart';

enum AppFragment { synrec, synviewrec }

class AppController extends ChangeNotifier {
  final CameraService cameraService = CameraService();
  final StorageService storageService = StorageService();
  final SyncService syncService = SyncService();
  final VideoStreamService videoStreamService = VideoStreamService();

  AppFragment _activeFragment = AppFragment.synrec;

  bool _isMaster = true;
  bool _isRecording = false;
  XFile? _tempRecordedFile;
  String? _savedVideoPath;
  String _statusMessage = "Initializing...";
  final List<String> _logs = [];

  AppFragment get activeFragment => _activeFragment;
  bool get isMaster => _isMaster;
  bool get isRecording => _isRecording;
  bool get isCameraInitialized => cameraService.isInitialized;
  bool get isVirtualMode => cameraService.isVirtualMode;
  CameraController? get cameraController => cameraService.controller;
  Map<String, String> get cameraSettings => cameraService.getCameraSettings();
  XFile? get tempRecordedFile => _tempRecordedFile;
  String? get savedVideoPath => _savedVideoPath;
  String get statusMessage => _statusMessage;
  List<String> get logs => List.unmodifiable(_logs);

  // Bluetooth & Network Getters
  bool get isPaired => syncService.isPaired;
  bool get isScanning => syncService.isScanning;
  String get myDeviceName => syncService.myDeviceName;
  String get localIpAddress => syncService.localIpAddress;
  List<SyncDeviceItem> get discoveredDevices => syncService.discoveredDevices;
  List<SyncDeviceItem> get favoriteDevices => syncService.favoriteDevices;
  List<SyncDeviceItem> get linkingCandidates => syncService.linkingCandidates;
  List<SyncDeviceItem> get activeCandidateList => syncService.activeCandidates;
  SyncDeviceItem? get selectedDevice => syncService.selectedDevice;
  String get pairingReminder => syncService.pairingReminder;

  // Requirement 2: Per-device recording state check
  bool isDeviceRecording(String deviceId) => syncService.isDeviceRecording(deviceId);

  // Folder Manager Getters & Setters
  String? get customPhotosFolder => storageService.customPhotosPath;
  String? get customVideosFolder => storageService.customVideosPath;

  Future<void> saveCustomFolders(String? photosPath, String? videosPath) async {
    await storageService.saveCustomFolderSettings(photosPath, videosPath);
    _addLog("Updated custom save folders in Folder Manager.");
    notifyListeners();
  }

  // Video Streaming Getters
  Uint8List? get slaveFrameBytes => videoStreamService.latestFrameBytes;
  bool get isReceivingSlaveStream => videoStreamService.isReceivingStream;

  String get activeStreamTargetIp {
    if (videoStreamService.currentStreamSourceIp != null) {
      return videoStreamService.currentStreamSourceIp!;
    }
    if (selectedDevice != null && _isValidRemoteSlaveIp(selectedDevice!.id)) {
      return selectedDevice!.id;
    }
    for (var candidate in activeCandidateList) {
      if (_isValidRemoteSlaveIp(candidate.id)) {
        return candidate.id;
      }
    }
    for (var dev in discoveredDevices) {
      if (_isValidRemoteSlaveIp(dev.id)) {
        return dev.id;
      }
    }
    return "Searching for Slave Target IP...";
  }

  bool isCandidateSelected(SyncDeviceItem device) => syncService.isCandidateSelected(device);
  bool isFavoriteSelected(SyncDeviceItem device) => syncService.isFavoriteSelected(device);

  AppController() {
    _init();
  }

  Future<void> _init() async {
    _addLog("Initializing camera and services...");
    bool camSuccess = await cameraService.initialize();
    if (camSuccess) {
      _addLog("Camera initialized successfully.");
      _statusMessage = "Camera Ready";
    } else {
      _statusMessage = cameraService.errorMessage ?? "Camera initialization failed.";
      _addLog(_statusMessage);
    }

    syncService.onTriggerReceived = _onBluetoothTriggerReceived;
    syncService.onStopTriggerReceived = _onStopTriggerReceived;
    syncService.onLogMessage = _addLog;
    syncService.setMode(isMaster: _isMaster);

    videoStreamService.onLogMessage = _addLog;
    videoStreamService.addListener(notifyListeners);

    // If Slave target, start streaming server so Master can view Slave's feed
    _setupVideoStreamServerIfNeeded();

    notifyListeners();
  }

  Timer? _slaveCameraStreamTimer;
  Timer? _masterStreamRetryTimer;
  bool _isCapturingSlaveFrame = false;

  void _setupVideoStreamServerIfNeeded() async {
    if (!_isMaster) {
      bool started = await videoStreamService.startStreamServer(port: 8890);
      if (started) {
        _startSlaveCameraFrameBroadcaster();
      }
    } else {
      _slaveCameraStreamTimer?.cancel();
    }
  }

  void _startSlaveCameraFrameBroadcaster() {
    _slaveCameraStreamTimer?.cancel();
    _slaveCameraStreamTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      if (_isMaster) {
        timer.cancel();
        return;
      }

      if (_isCapturingSlaveFrame) return; // Prevent concurrent takePicture calls on native camera thread

      _isCapturingSlaveFrame = true;
      try {
        if (cameraService.isInitialized && !cameraService.isVirtualMode) {
          XFile? frameFile = await cameraService.takePicture();
          if (frameFile != null) {
            Uint8List bytes = await frameFile.readAsBytes();
            videoStreamService.broadcastJpegFrame(bytes);
          } else {
            videoStreamService.broadcastJpegFrame(VideoStreamService.validTestJpeg);
          }
        } else {
          videoStreamService.broadcastJpegFrame(VideoStreamService.validTestJpeg);
        }
      } catch (e) {
        videoStreamService.broadcastJpegFrame(VideoStreamService.validTestJpeg);
      } finally {
        _isCapturingSlaveFrame = false;
      }
    });
  }

  void setFragment(AppFragment fragment) {
    if (_activeFragment == fragment) return;
    _activeFragment = fragment;
    _addLog("Switched fragment to: ${fragment.name}");

    if (_activeFragment == AppFragment.synviewrec && _isMaster && isPaired) {
      _connectToFirstSlaveStream();
    } else if (_activeFragment == AppFragment.synrec) {
      _masterStreamRetryTimer?.cancel();
      videoStreamService.stopStreamReceiver();
    }

    notifyListeners();
  }

  void navigateNextFragment() {
    if (_activeFragment == AppFragment.synrec) {
      setFragment(AppFragment.synviewrec);
    }
  }

  void navigatePreviousFragment() {
    if (_activeFragment == AppFragment.synviewrec) {
      setFragment(AppFragment.synrec);
    }
  }

  void _connectToFirstSlaveStream() {
    _masterStreamRetryTimer?.cancel();

    _attemptSlaveStreamConnection();

    // Periodically retry every 2 seconds if not yet connected
    _masterStreamRetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_activeFragment != AppFragment.synviewrec || !_isMaster || !isPaired) {
        timer.cancel();
        return;
      }
      if (!videoStreamService.isReceivingStream) {
        _attemptSlaveStreamConnection();
      }
    });
  }

  void _attemptSlaveStreamConnection() {
    List<String> candidateIps = [];

    // 1. Prioritize dynamically discovered real network slave devices (e.g. HUAWEI P30 lite1)
    for (var dev in discoveredDevices) {
      if (_isValidRemoteSlaveIp(dev.id) && !candidateIps.contains(dev.id)) {
        candidateIps.add(dev.id);
      }
    }

    // 2. Check user explicitly selected device if valid remote IP
    if (selectedDevice != null && _isValidRemoteSlaveIp(selectedDevice!.id) && !candidateIps.contains(selectedDevice!.id)) {
      candidateIps.add(selectedDevice!.id);
    }

    // 3. Add candidates from linkingCandidates
    for (var candidate in activeCandidateList) {
      if (_isValidRemoteSlaveIp(candidate.id) && !candidateIps.contains(candidate.id)) {
        candidateIps.add(candidate.id);
      }
    }

    if (candidateIps.isNotEmpty) {
      _tryConnectNextSlaveIp(candidateIps, 0);
    } else {
      _addLog("No valid remote slave IP found to stream video. Please select or add slave target IP.");
    }
  }

  bool _isValidRemoteSlaveIp(String ip) {
    if (ip.isEmpty || ip.contains("target_")) return false;
    // Exclude 192.168.43.1 if it's the static Hotspot default IP and not an auto-discovered slave device
    if (ip == "192.168.43.1" && !_isRealDiscoveredSlaveIp(ip)) return false;
    // Don't connect to local loopback or local device IP
    if (ip == "127.0.0.1" || (localIpAddress.isNotEmpty && ip == localIpAddress)) return false;
    // Must match IPv4 format
    return RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip);
  }

  bool _isRealDiscoveredSlaveIp(String ip) {
    for (var dev in discoveredDevices) {
      if (dev.id == ip && !dev.name.contains("Master Mobile Hotspot")) {
        return true;
      }
    }
    return false;
  }

  void _tryConnectNextSlaveIp(List<String> candidateIps, int index) async {
    if (index >= candidateIps.length) {
      _addLog("Tried all candidate slave IPs, none reachable for video stream.");
      return;
    }

    String slaveIp = candidateIps[index];
    _addLog("Connecting Master to Slave video stream ($slaveIp) [Candidate ${index + 1}/${candidateIps.length}]...");

    bool success = await videoStreamService.connectToSlaveStream(slaveIp, port: 8890);
    if (!success && index + 1 < candidateIps.length) {
      _addLog("Slave $slaveIp unreachable. Trying next slave candidate (${candidateIps[index + 1]})...");
      _tryConnectNextSlaveIp(candidateIps, index + 1);
    }
  }

  void setMasterMode(bool isMaster) {
    _isMaster = isMaster;
    syncService.setMode(isMaster: isMaster);
    _addLog("Target mode set to: ${isMaster ? 'Master' : 'Slave'}");
    _statusMessage = syncService.statusMessage;

    if (!_isMaster) {
      _setupVideoStreamServerIfNeeded();
    } else {
      videoStreamService.stopStreamServer();
      if (_activeFragment == AppFragment.synviewrec && isPaired) {
        _connectToFirstSlaveStream();
      }
    }

    notifyListeners();
  }

  void selectDevice(SyncDeviceItem? device) {
    syncService.selectDevice(device);
    _addLog("Selected target device: ${device?.name}");
    _statusMessage = syncService.statusMessage;

    if (_activeFragment == AppFragment.synviewrec && _isMaster) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  void addCustomDevice(String name, String ipOrId) {
    syncService.addCustomDevice(name, ipOrId);
    _addLog("Added custom target device: $name (IP: $ipOrId)");
    _statusMessage = syncService.statusMessage;

    if (_activeFragment == AppFragment.synviewrec && _isMaster) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  void toggleCandidate(SyncDeviceItem device) {
    syncService.toggleCandidate(device);
    _statusMessage = syncService.statusMessage;

    if (_activeFragment == AppFragment.synviewrec && _isMaster && isPaired) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  void toggleFavoriteCandidate(SyncDeviceItem device) {
    syncService.toggleFavoriteCandidate(device);
    _statusMessage = syncService.statusMessage;

    if (_activeFragment == AppFragment.synviewrec && _isMaster && isPaired) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  void selectAllCandidates() {
    syncService.selectAllCandidates();
    _statusMessage = syncService.statusMessage;

    if (_activeFragment == AppFragment.synviewrec && _isMaster && isPaired) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  void clearCandidates() {
    syncService.clearCandidates();
    _statusMessage = syncService.statusMessage;
    videoStreamService.stopStreamReceiver();
    notifyListeners();
  }

  Future<void> startScanning() async {
    _addLog("Scanning for devices around...");
    _statusMessage = "Scanning for nearby devices...";
    notifyListeners();

    await syncService.startBluetoothScanning();
    _addLog("Scan complete. Found ${discoveredDevices.length} device(s) around.");
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  Future<void> executePairing() async {
    _addLog("Starting Bluetooth pairing sequence...");
    _statusMessage = "Pairing in progress...";
    notifyListeners();

    bool paired = await syncService.executePairing();
    _addLog(paired ? "Pairing successful! Connected to ${selectedDevice?.name}" : "Pairing failed.");
    _statusMessage = syncService.statusMessage;

    if (paired && _activeFragment == AppFragment.synviewrec && _isMaster) {
      _connectToFirstSlaveStream();
    }

    notifyListeners();
  }

  Future<void> takePhoto() async {
    if (!cameraService.isInitialized) {
      _statusMessage = "Cannot take photo: Camera not initialized.";
      notifyListeners();
      return;
    }

    if (_isMaster && !isPaired) {
      _statusMessage = "Pairing incomplete! Please pair with Slave target first.";
      _addLog("Photo blocked: Bluetooth pairing not completed.");
      notifyListeners();
      return;
    }

    _statusMessage = "Taking photo...";
    notifyListeners();

    XFile? photoFile = await cameraService.takePicture();
    if (photoFile != null) {
      String? savedPath = await storageService.savePhoto(photoFile);
      if (savedPath != null) {
        _savedVideoPath = savedPath;
        _statusMessage = "Photo saved to: ${savedPath.split(Platform.pathSeparator).last}";
        _addLog("Photo captured & saved as: ${savedPath.split(Platform.pathSeparator).last}");

        if (_isMaster) {
          try {
            File startFile = await storageService.createStartFile(isPhoto: true);
            bool onlyFirstDevice = (_activeFragment == AppFragment.synviewrec);
            bool sent = await syncService.sendStartedTriggerFile(startFile, onlyFirstDevice: onlyFirstDevice);
            _addLog(sent ? "Sent 'TAKE_PHOTO' trigger via Bluetooth/Socket." : "Created photo trigger start.txt.");
          } catch (e) {
            _addLog("Error sending photo trigger file: $e");
          }
        }
      } else {
        _statusMessage = "Failed to save photo.";
        _addLog(_statusMessage);
      }
    } else {
      _statusMessage = "Failed to capture photo.";
      _addLog(_statusMessage);
    }

    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    if (!cameraService.isInitialized) {
      _statusMessage = "Cannot record: Camera not initialized.";
      notifyListeners();
      return;
    }

    if (_isMaster && !isPaired) {
      _statusMessage = "Pairing incomplete! Please pair with Slave target first.";
      _addLog("Recording blocked: Bluetooth pairing not completed.");
      notifyListeners();
      return;
    }

    bool success = await cameraService.startVideoRecording();
    if (success) {
      _isRecording = true;
      _tempRecordedFile = null;
      _savedVideoPath = null;
      _statusMessage = _isMaster ? "Recording (Master)..." : "Recording (Slave triggered)...";
      _addLog(_statusMessage);

      if (_isMaster) {
        try {
          File startedFile = await storageService.createStartFile(isPhoto: false);
          bool onlyFirstDevice = (_activeFragment == AppFragment.synviewrec);
          bool sent = await syncService.sendStartedTriggerFile(startedFile, onlyFirstDevice: onlyFirstDevice);
          _addLog(sent ? "Sent 'start.txt' file via Bluetooth/Socket." : "Attempted sending start.txt file.");
        } catch (e) {
          _addLog("Error sending Bluetooth/Socket file: $e");
        }
      }

      notifyListeners();
    } else {
      _statusMessage = cameraService.errorMessage ?? "Failed to start recording.";
      _addLog(_statusMessage);
      notifyListeners();
    }
  }

  void _onBluetoothTriggerReceived(String startedInfo) {
    _addLog("Bluetooth trigger received: $startedInfo");
    if (startedInfo.toUpperCase().contains("TAKE_PHOTO")) {
      _addLog("Executing synced photo capture on Slave...");
      takePhoto();
    } else if (!_isRecording) {
      startRecording();
    }
  }

  void _onStopTriggerReceived(String stopInfo) {
    _addLog("Bluetooth 'stop.txt' trigger received!");
    if (_isRecording) {
      stopRecording(isTriggered: true);
    }
  }

  Future<void> stopRecording({bool isTriggered = false}) async {
    if (!_isRecording) return;

    XFile? file = await cameraService.stopVideoRecording();
    _isRecording = false;

    if (file != null) {
      _tempRecordedFile = file;
      _statusMessage = "Recording stopped. Ready to save.";
      _addLog("Video recording stopped. Temp file at: ${file.path}");
    } else {
      _statusMessage = "Error stopping recording.";
      _addLog(_statusMessage);
    }

    if (!isTriggered) {
      try {
        File stopFile = await storageService.createStopFile();
        bool onlyFirstDevice = (_activeFragment == AppFragment.synviewrec);
        bool sent = await syncService.sendStopTriggerFile(stopFile, onlyFirstDevice: onlyFirstDevice);
        _addLog(sent ? "Sent 'stop.txt' file to sync stop on target(s)." : "Created stop.txt locally.");
      } catch (e) {
        _addLog("Error creating stop file: $e");
      }
    }

    notifyListeners();
  }

  Future<void> saveVideo() async {
    if (_tempRecordedFile == null) {
      _statusMessage = "No recorded video available to save.";
      notifyListeners();
      return;
    }

    _statusMessage = "Saving video as recxxxx.mp4...";
    notifyListeners();

    String? savedPath = await storageService.saveRecordedVideo(_tempRecordedFile!);
    if (savedPath != null) {
      _savedVideoPath = savedPath;
      _statusMessage = "Saved video to: $savedPath";
      _addLog("Saved video as: ${savedPath.split(Platform.pathSeparator).last}");
    } else {
      _statusMessage = "Failed to save video.";
      _addLog(_statusMessage);
    }

    notifyListeners();
  }

  void _addLog(String msg) {
    _logs.add("[${DateTime.now().toString().substring(11, 19)}] $msg");
    if (_logs.length > 50) {
      _logs.removeAt(0);
    }
  }

  @override
  void dispose() {
    _slaveCameraStreamTimer?.cancel();
    _masterStreamRetryTimer?.cancel();
    videoStreamService.removeListener(notifyListeners);
    videoStreamService.dispose();
    cameraService.dispose();
    syncService.dispose();
    super.dispose();
  }
}
