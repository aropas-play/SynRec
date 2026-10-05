import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class AppController extends ChangeNotifier {
  final CameraService cameraService = CameraService();
  final StorageService storageService = StorageService();
  final SyncService syncService = SyncService();

  bool _isMaster = true;
  bool _isRecording = false;
  XFile? _tempRecordedFile;
  String? _savedVideoPath;
  String _statusMessage = "Initializing...";
  final List<String> _logs = [];

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
  List<SyncDeviceItem> get linkingCandidates => syncService.linkingCandidates;
  SyncDeviceItem? get selectedDevice => syncService.selectedDevice;
  String get pairingReminder => syncService.pairingReminder;

  bool isCandidateSelected(SyncDeviceItem device) => syncService.isCandidateSelected(device);

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

    notifyListeners();
  }

  void setMasterMode(bool isMaster) {
    _isMaster = isMaster;
    syncService.setMode(isMaster: isMaster);
    _addLog("Target mode set to: ${isMaster ? 'Master' : 'Slave'}");
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  void selectDevice(SyncDeviceItem? device) {
    syncService.selectDevice(device);
    _addLog("Selected target device: ${device?.name}");
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  void addCustomDevice(String name, String ipOrId) {
    syncService.addCustomDevice(name, ipOrId);
    _addLog("Added custom target device: $name (IP: $ipOrId)");
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  void toggleCandidate(SyncDeviceItem device) {
    syncService.toggleCandidate(device);
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  void selectAllCandidates() {
    syncService.selectAllCandidates();
    _statusMessage = syncService.statusMessage;
    notifyListeners();
  }

  void clearCandidates() {
    syncService.clearCandidates();
    _statusMessage = syncService.statusMessage;
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
            bool sent = await syncService.sendStartedTriggerFile(startFile);
            _addLog(sent ? "Sent 'TAKE_PHOTO' trigger via Bluetooth." : "Created photo trigger start.txt.");
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
          bool sent = await syncService.sendStartedTriggerFile(startedFile);
          _addLog(sent ? "Sent 'start.txt' file via Bluetooth." : "Attempted sending Bluetooth start.txt file.");
        } catch (e) {
          _addLog("Error sending Bluetooth file: $e");
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
        bool sent = await syncService.sendStopTriggerFile(stopFile);
        _addLog(sent ? "Sent 'stop.txt' file to sync stop on both targets." : "Created stop.txt locally.");
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
    cameraService.dispose();
    syncService.dispose();
    super.dispose();
  }
}
