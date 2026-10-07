import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_controller.dart';
import '../widgets/floating_control_strap.dart';

class SynViewRecFragment extends StatelessWidget {
  const SynViewRecFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, child) {
        return Stack(
          children: [
            // Video Feed: Show 1st Slave device screen/camera feed if Master & Linked, else local feed
            Positioned.fill(
              child: _buildVideoFeed(controller),
            ),

            // Pairing Reminder Banner
            if (!controller.isPaired)
              Positioned(
                top: 70,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade900.withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "This Device: ${controller.myDeviceName}${controller.localIpAddress.isNotEmpty ? ' (IP: ${controller.localIpAddress})' : ''}",
                                style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                controller.pairingReminder,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Saved File Banner Notification
            if (controller.savedVideoPath != null)
              Positioned(
                top: 120,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withAlpha(230),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Saved: ${controller.savedVideoPath}",
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating Control Strap (Same sync record/photo methods as synrec)
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: Center(
                child: FloatingControlStrap(
                  isPaired: controller.isPaired,
                  isScanning: controller.isScanning,
                  isRecording: controller.isRecording,
                  hasRecordedFile: controller.tempRecordedFile != null,
                  discoveredDevices: controller.discoveredDevices,
                  selectedDevice: controller.selectedDevice,
                  onDeviceSelected: (device) => controller.selectDevice(device),
                  onAddCustomDevice: (name, ip) => controller.addCustomDevice(name, ip),
                  onPairPressed: () => controller.executePairing(),
                  onPhotoPressed: () => controller.takePhoto(),
                  onRecordPressed: () => controller.startRecording(),
                  onStopPressed: () => controller.stopRecording(),
                  onSavePressed: () => controller.saveVideo(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoFeed(AppController controller) {
    // REQUIREMENT 4: On synviewrec, if twos linked, in master screen show screen of 1st slave device
    if (controller.isMaster && controller.isPaired) {
      if (controller.slaveFrameBytes != null) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.memory(
                controller.slaveFrameBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              top: 70,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "LIVE 1ST SLAVE SCREEN FEED",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      } else {
        return Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.deepOrangeAccent),
                const SizedBox(height: 16),
                Text(
                  "Connecting to 1st Slave Screen Stream...\nTarget IP: ${controller.activeStreamTargetIp}",
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Lowest latency socket stream active (Port 8890)",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Fallback: Local camera feed if not linked or on Slave target
    return _buildLocalCameraFeed(controller);
  }

  Widget _buildLocalCameraFeed(AppController controller) {
    if (controller.isVirtualMode) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade900, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.connected_tv,
                size: 80,
                color: controller.isRecording ? Colors.redAccent : Colors.cyanAccent,
              ),
              const SizedBox(height: 16),
              Text(
                controller.isMaster ? "SYNVIEWREC - MASTER (NOT LINKED)" : "SYNVIEWREC - SLAVE FEED STREAMER",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.isMaster
                    ? "Link to Slave target to view 1st Slave device screen."
                    : "Streaming camera/screen feed to Master target on Port 8890.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.isCameraInitialized && controller.cameraController != null) {
      return ClipRRect(
        child: CameraPreview(controller.cameraController!),
      );
    }

    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.deepOrangeAccent),
            const SizedBox(height: 16),
            Text(
              controller.statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
