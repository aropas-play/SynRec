import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos_arguments.dart';
import 'package:camera_macos/camera_macos_controller.dart';
import 'package:camera_macos/camera_macos_device.dart';
import 'package:camera_macos/camera_macos_file.dart';
import 'package:camera_macos/camera_macos_platform_interface.dart';
import 'package:camera_macos/camera_macos_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  CameraMacOSController? _macOSController;
  String? _macOSDeviceId;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isVirtualMode = false;
  bool _isRecording = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isVirtualMode => _isVirtualMode;
  bool get isRecording => _isRecording;
  String? get errorMessage => _errorMessage;

  Map<String, String> getCameraSettings() {
    if (_isVirtualMode) {
      return {
        "Camera Feed": "Virtual Camera Mode",
        "Status": _isRecording ? "Recording Video" : "Camera Ready",
        "Resolution Preset": "High (1080p Virtual)",
        "Audio Stream": "Disabled (Sync Optimized)",
        "Available Cameras": "${_cameras.length} found",
        "Virtual Feed Info": "Feed active for dual-instance testing",
      };
    }

    if (!kIsWeb && Platform.isMacOS) {
      return {
        "Camera Mode": "macOS Physical Camera (AVFoundation)",
        "Status": _isRecording ? "Recording Video" : "Camera Ready",
        "Device ID": _macOSDeviceId ?? "FaceTime HD Camera",
        "Audio Stream": "Disabled (Sync Optimized)",
      };
    }

    if (_controller != null && _controller!.value.isInitialized) {
      final val = _controller!.value;
      final desc = _controller!.description;
      String lens = desc.lensDirection.toString().split('.').last.toUpperCase();
      String previewSizeStr = val.previewSize != null
          ? "${val.previewSize!.width.toInt()} x ${val.previewSize!.height.toInt()}"
          : "High Resolution";

      return {
        "Camera Mode": "Physical Hardware Camera",
        "Status": val.isRecordingVideo ? "Recording Video" : "Camera Ready",
        "Camera Name": desc.name,
        "Lens Direction": lens,
        "Preview Resolution": previewSizeStr,
        "Aspect Ratio": val.aspectRatio.toStringAsFixed(2),
        "Sensor Orientation": "${desc.sensorOrientation}°",
        "Audio Stream": "Disabled (Sync Optimized)",
      };
    }

    return {
      "Camera Status": "Not Initialized",
      "Message": _errorMessage ?? "Initializing camera controller...",
    };
  }

  Future<bool> initialize() async {
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        await [
          Permission.camera,
          Permission.microphone,
        ].request();
      }

      if (!kIsWeb && Platform.isMacOS) {
        try {
          final macosDevices = await CameraMacOSPlatform.instance.listDevices(
            deviceType: CameraMacOSDeviceType.video,
          );
          if (macosDevices.isNotEmpty) {
            final builtInCamera = macosDevices.where((device) {
              final name = device.localizedName?.toLowerCase() ?? '';
              return name.contains('facetime') || name.contains('built-in');
            });
            _macOSDeviceId = builtInCamera.isNotEmpty
                ? builtInCamera.first.deviceId
                : macosDevices.first.deviceId;
            _isInitialized = true;
            _isVirtualMode = false;
            _errorMessage = null;
            debugPrint('macOS Camera initialized with deviceId: $_macOSDeviceId');
            return true;
          }
        } catch (e) {
          debugPrint('macOS Camera listDevices error: $e');
        }
      }

      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Sort cameras: prioritize physical front camera (e.g. FaceTime HD) over virtual cameras
        List<CameraDescription> sortedCameras = List.from(_cameras);
        sortedCameras.sort((a, b) {
          bool aIsVirtual = a.name.toLowerCase().contains('virtual');
          bool bIsVirtual = b.name.toLowerCase().contains('virtual');
          if (aIsVirtual != bIsVirtual) return aIsVirtual ? 1 : -1;

          bool aIsFront = a.lensDirection == CameraLensDirection.front ||
              a.name.toLowerCase().contains('facetime') ||
              a.name.toLowerCase().contains('front');
          bool bIsFront = b.lensDirection == CameraLensDirection.front ||
              b.name.toLowerCase().contains('facetime') ||
              b.name.toLowerCase().contains('front');
          if (aIsFront != bIsFront) return aIsFront ? -1 : 1;

          return 0;
        });

        for (var camera in sortedCameras) {
          try {
            _controller = CameraController(
              camera,
              ResolutionPreset.high,
              enableAudio: false,
            );
            await _controller!.initialize();
            _isInitialized = true;
            _isVirtualMode = false;
            _errorMessage = null;
            debugPrint('Initialized physical camera: ${camera.name} (${camera.lensDirection})');
            return true;
          } catch (e) {
            debugPrint('Camera ${camera.name} in use or unavailable: $e');
            _controller?.dispose();
            _controller = null;
          }
        }
      }

      _isVirtualMode = true;
      _isInitialized = true;
      _errorMessage = "Webcam in use by Instance 1 (Virtual Camera Mode Active)";
      return true;
    } catch (e) {
      _isVirtualMode = true;
      _isInitialized = true;
      _errorMessage = "Webcam locked. Virtual Camera Mode active.";
      return true;
    }
  }

  Widget buildPreviewWidget({VoidCallback? onInitialized}) {
    if (!kIsWeb && Platform.isMacOS && !_isVirtualMode) {
      final deviceId = _macOSDeviceId;
      if (deviceId == null) {
        return const ColoredBox(color: Colors.black87);
      }
      return CameraMacOSView(
        key: ValueKey(deviceId),
        deviceId: deviceId,
        cameraMode: CameraMacOSMode.photo,
        enableAudio: false,
        fit: BoxFit.cover,
        resolution: PictureResolution.high,
        pictureFormat: PictureFormat.jpeg,
        onCameraInizialized: (controller) {
          _macOSController = controller;
          if (onInitialized != null) onInitialized();
        },
        onCameraLoading: (_) => const ColoredBox(color: Colors.black87),
      );
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return ClipRRect(child: CameraPreview(_controller!));
    }

    return const ColoredBox(color: Colors.black87);
  }

  Future<XFile?> takePicture() async {
    if (_isVirtualMode) {
      return await _generateVirtualJpgFile();
    }

    if (!kIsWeb && Platform.isMacOS) {
      if (_macOSController == null || _macOSController!.isDestroyed) {
        _errorMessage = "macOS Camera is not initialized.";
        return null;
      }
      try {
        final imageData = await _macOSController!.takePicture();
        final bytes = imageData?.bytes;
        if (bytes == null) return null;
        Directory tempDir = await getTemporaryDirectory();
        String filePath = p.join(
          tempDir.path,
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        File file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return XFile(filePath);
      } catch (e) {
        _errorMessage = "Failed to take photo: $e";
        return null;
      }
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = "Camera is not initialized.";
      return null;
    }

    try {
      XFile photo = await _controller!.takePicture();
      return photo;
    } catch (e) {
      _errorMessage = "Failed to take photo: $e";
      return null;
    }
  }

  Future<bool> startVideoRecording() async {
    if (_isVirtualMode) {
      _isRecording = true;
      _errorMessage = null;
      return true;
    }

    if (!kIsWeb && Platform.isMacOS) {
      if (_macOSController == null || _macOSController!.isDestroyed) {
        _errorMessage = "macOS Camera is not initialized.";
        return false;
      }
      try {
        bool success = await _macOSController!.recordVideo() ?? false;
        _isRecording = success;
        _errorMessage = success ? null : "Failed to start macOS video recording.";
        return _isRecording;
      } catch (e) {
        _errorMessage = "Failed to start recording: $e";
        return false;
      }
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = "Camera is not initialized.";
      return false;
    }

    if (_isRecording) {
      return true;
    }

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = "Failed to start recording: $e";
      return false;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (_isVirtualMode) {
      _isRecording = false;
      return await _generateVirtualMp4File();
    }

    if (!kIsWeb && Platform.isMacOS) {
      if (_macOSController == null || !_isRecording) {
        return null;
      }
      try {
        CameraMacOSFile? fileData = await _macOSController!.stopRecording();
        _isRecording = false;
        if (fileData?.url == null) return null;
        return XFile(fileData!.url!);
      } catch (e) {
        _errorMessage = "Failed to stop recording: $e";
        _isRecording = false;
        return null;
      }
    }

    if (_controller == null || !_isRecording) {
      return null;
    }

    try {
      XFile file = await _controller!.stopVideoRecording();
      _isRecording = false;
      return file;
    } catch (e) {
      _errorMessage = "Failed to stop recording: $e";
      _isRecording = false;
      return null;
    }
  }

  Future<XFile> _generateVirtualMp4File() async {
    Directory tempDir = await getTemporaryDirectory();
    String filePath = p.join(
      tempDir.path,
      'virtual_rec_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    File virtualFile = File(filePath);
    List<int> dummyMp4Header = [
      0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
      0x6D, 0x70, 0x34, 0x32, 0x00, 0x00, 0x00, 0x00,
      0x6D, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6F, 0x6D,
    ];
    await virtualFile.writeAsBytes(dummyMp4Header);
    return XFile(filePath);
  }

  Future<XFile> _generateVirtualJpgFile() async {
    Directory tempDir = await getTemporaryDirectory();
    String filePath = p.join(
      tempDir.path,
      'virtual_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    File virtualFile = File(filePath);
    List<int> dummyJpg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0xFF, 0xD9];
    await virtualFile.writeAsBytes(dummyJpg);
    return XFile(filePath);
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    if (_macOSController != null && !_macOSController!.isDestroyed) {
      _macOSController!.destroy();
      _macOSController = null;
    }
    _macOSDeviceId = null;
    _isInitialized = false;
    _isVirtualMode = false;
    _isRecording = false;
  }
}
