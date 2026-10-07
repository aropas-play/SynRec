import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_controller.dart';
import '../widgets/floating_control_strap.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              "SynRec - Target ${controller.isMaster ? 'A (Master)' : 'B (Slave)'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: controller.isMaster ? Colors.deepOrange.shade900 : Colors.indigo.shade900,
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: "Settings",
                color: Colors.grey.shade900,
                onSelected: (value) {
                  switch (value) {
                    case 'info':
                      _showLogDialog(context, controller);
                      break;
                    case 'camera_settings':
                      _showCameraSettingsDialog(context, controller);
                      break;
                    case 'devices_around':
                      _showDevicesAroundDialog(context, controller);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Info', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'camera_settings',
                    child: Row(
                      children: [
                        Icon(Icons.camera_enhance_outlined, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Camera Current Setting', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'devices_around',
                    child: Row(
                      children: [
                        Icon(Icons.wifi_tethering, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Devices Around', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              // Requirement 1 & 2: Camera preview feed
              Positioned.fill(
                child: _buildCameraFeed(controller),
              ),

              // Top Bar: Master/Slave toggle on Top Left (SAME LINE with Camera Ready info box)
              Positioned(
                top: 16,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TOP LEFT: Master / Slave Toggle + Camera Ready Info Box
                    Row(
                      children: [
                        // Master / Slave Toggle Box (Moved to Top Left)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: controller.isMaster
                                ? Colors.deepOrange.shade900.withAlpha(230)
                                : Colors.indigo.shade900.withAlpha(230),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: controller.isMaster ? Colors.deepOrangeAccent : Colors.indigoAccent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: controller.isMaster,
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.setMasterMode(val);
                                  }
                                },
                                activeColor: Colors.deepOrangeAccent,
                                checkColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                              ),
                              Text(
                                controller.isMaster ? "Master" : "Slave",
                                style: TextStyle(
                                  color: controller.isMaster ? Colors.deepOrangeAccent : Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Camera Ready / Status Info Box (On same line)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                controller.isRecording ? Icons.fiber_manual_record : Icons.camera_alt,
                                size: 14,
                                color: controller.isRecording ? Colors.redAccent : Colors.greenAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                controller.statusMessage,
                                style: TextStyle(
                                  color: controller.isRecording ? Colors.redAccent : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // TOP RIGHT: Link Connection Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: controller.isPaired ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      child: Text(
                        controller.isPaired ? "Linked" : "Not Linked",
                        style: TextStyle(
                          color: controller.isPaired ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pairing Reminder Banner (when sync/pairing is not yet done)
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

              // Floating Control Strap (Pairing Controls Line + Action Buttons Line with PHOTO Button)
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
          ),
        );
      },
    );
  }

  Widget _buildCameraFeed(AppController controller) {
    if (controller.isVirtualMode) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_outlined,
                size: 80,
                color: controller.isRecording ? Colors.redAccent : Colors.tealAccent,
              ),
              const SizedBox(height: 16),
              Text(
                controller.isMaster ? "VIRTUAL CAMERA - TARGET A (MASTER)" : "VIRTUAL CAMERA - TARGET B (SLAVE)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Physical webcam locked by Instance 1.\nVirtual feed active for dual-instance testing.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.isCameraInitialized) {
      return ClipRRect(
        child: controller.cameraService.buildPreviewWidget(),
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

  void _showLogDialog(BuildContext context, AppController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text("App Info & Sync Logs", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Device: ${controller.myDeviceName}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                        "IP: ${controller.localIpAddress.isNotEmpty ? controller.localIpAddress : 'Searching...'}",
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                        "Role: ${controller.isMaster ? 'Target A (Master)' : 'Target B (Slave)'}",
                        style: TextStyle(
                            color: controller.isMaster ? Colors.deepOrangeAccent : Colors.indigoAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                        "Link Status: ${controller.isPaired ? 'Linked' : 'Not Linked'}",
                        style: TextStyle(
                            color: controller.isPaired ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text("Logs History:",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                padding: const EdgeInsets.all(8),
                child: controller.logs.isEmpty
                    ? const Center(
                        child: Text("No logs recorded yet.",
                            style: TextStyle(color: Colors.white38, fontSize: 12)))
                    : ListView.builder(
                        itemCount: controller.logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              controller.logs[index],
                              style: const TextStyle(
                                  color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close", style: TextStyle(color: Colors.deepOrangeAccent)),
          ),
        ],
      ),
    );
  }

  void _showCameraSettingsDialog(BuildContext context, AppController controller) {
    final settings = controller.cameraSettings;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.camera_enhance_outlined, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text("Camera Current Setting", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: settings.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close", style: TextStyle(color: Colors.deepOrangeAccent)),
          ),
        ],
      ),
    );
  }

  void _showDevicesAroundDialog(BuildContext context, AppController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi_tethering, color: Colors.cyanAccent),
                SizedBox(width: 8),
                Text("Devices Around", style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),

            // Requirement 1: Top Right "Search" Button
            Consumer<AppController>(
              builder: (context, ctrl, child) {
                return ElevatedButton.icon(
                  onPressed: ctrl.isScanning ? null : () => ctrl.startScanning(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: ctrl.isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search, size: 16),
                  label: Text(
                    ctrl.isScanning ? "Scanning..." : "Search",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
        content: Consumer<AppController>(
          builder: (context, ctrl, child) {
            final devices = ctrl.discoveredDevices;
            final candidates = ctrl.linkingCandidates;

            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Local Device Info Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade900.withAlpha(180),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigoAccent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Local Device IP & Name:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          "${ctrl.myDeviceName} (IP: ${ctrl.localIpAddress.isNotEmpty ? ctrl.localIpAddress : '127.0.0.1'})",
                          style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Requirement 2: Sublist Header & Quick Select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Linking Candidates: ${candidates.length} selected",
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => ctrl.selectAllCandidates(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text("Select All", style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const Text(" | ", style: TextStyle(color: Colors.white38, fontSize: 11)),
                          InkWell(
                            onTap: () => ctrl.clearCandidates(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text("Clear", style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Requirement 2: Devices List with Checkboxes
                  SizedBox(
                    height: 210,
                    child: devices.isEmpty
                        ? const Center(
                            child: Text("No nearby devices found yet. Tap 'Search' to scan.",
                                style: TextStyle(color: Colors.white38, fontSize: 12)),
                          )
                        : ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final dev = devices[index];
                              final bool isChecked = ctrl.isCandidateSelected(dev);

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isChecked ? Colors.teal.shade900.withAlpha(200) : Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isChecked ? Colors.tealAccent : Colors.white12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox for Candidate Sublist
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: Colors.tealAccent,
                                      checkColor: Colors.black,
                                      side: const BorderSide(color: Colors.white60),
                                      onChanged: (val) {
                                        ctrl.toggleCandidate(dev);
                                      },
                                    ),
                                    Icon(
                                      dev.bleDevice != null ? Icons.bluetooth : Icons.dns,
                                      color: isChecked ? Colors.tealAccent : Colors.cyanAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dev.name,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "IP / Address: ${dev.id}",
                                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isChecked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.teal,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text("Candidate", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Done", style: TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
