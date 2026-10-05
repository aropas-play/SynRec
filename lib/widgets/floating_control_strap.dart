import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class FloatingControlStrap extends StatelessWidget {
  final bool isPaired;
  final bool isScanning;
  final bool isRecording;
  final bool hasRecordedFile;
  final List<SyncDeviceItem> discoveredDevices;
  final SyncDeviceItem? selectedDevice;
  final ValueChanged<SyncDeviceItem?> onDeviceSelected;
  final Function(String name, String ip)? onAddCustomDevice;
  final VoidCallback onPairPressed;
  final VoidCallback onPhotoPressed;
  final VoidCallback onRecordPressed;
  final VoidCallback onStopPressed;
  final VoidCallback onSavePressed;

  const FloatingControlStrap({
    super.key,
    required this.isPaired,
    required this.isScanning,
    required this.isRecording,
    required this.hasRecordedFile,
    required this.discoveredDevices,
    required this.selectedDevice,
    required this.onDeviceSelected,
    this.onAddCustomDevice,
    required this.onPairPressed,
    required this.onPhotoPressed,
    required this.onRecordPressed,
    required this.onStopPressed,
    required this.onSavePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // LINE 1: Bluetooth & Wi-Fi Linking Controls (Device Combobox, Add IP, Link Button)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Device Combobox (Dropdown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SyncDeviceItem>(
                      value: discoveredDevices.contains(selectedDevice)
                          ? selectedDevice
                          : (discoveredDevices.isNotEmpty ? discoveredDevices.first : null),
                      dropdownColor: Colors.grey.shade900,
                      isDense: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                      items: discoveredDevices.map((SyncDeviceItem item) {
                        return DropdownMenuItem<SyncDeviceItem>(
                          value: item,
                          child: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: onDeviceSelected,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Add Custom Target IP / Device Button
                IconButton(
                  onPressed: () => _showAddDeviceDialog(context),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 22),
                  tooltip: "Enter Target Device Name / IP",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),

                // 3. Link Button
                ElevatedButton.icon(
                  onPressed: isScanning ? null : onPairPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaired ? Colors.teal.shade800 : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link, size: 16),
                  label: Text(
                    isScanning ? "Scanning..." : (isPaired ? "Re-Link" : "Link"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // LINE 2: Photo, Record, Stop Rec, Save Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo Button
                ElevatedButton.icon(
                  onPressed: onPhotoPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  label: const Text(
                    "Photo",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),

                // Record Button
                ElevatedButton.icon(
                  onPressed: isRecording ? null : onRecordPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.grey : Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: Icon(
                    isRecording ? Icons.fiber_manual_record : Icons.videocam,
                    color: isRecording ? Colors.red : Colors.white,
                  ),
                  label: Text(
                    isRecording ? "REC..." : "Record",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // Stop Rec Button
                ElevatedButton.icon(
                  onPressed: isRecording ? onStopPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.orangeAccent : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop Rec", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),

                // Save Button
                ElevatedButton.icon(
                  onPressed: hasRecordedFile ? onSavePressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasRecordedFile ? Colors.green : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.save_alt),
                  label: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    TextEditingController nameCtrl = TextEditingController(text: "Target B (Galaxy S23)");
    TextEditingController ipCtrl = TextEditingController(text: "192.168.1.102");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text("Add Target Device IP / Name", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter the Target Device Name and IP Address shown on the target device's banner.",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Target Device Name",
                labelStyle: TextStyle(color: Colors.cyanAccent),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Target IP Address (e.g. 192.168.1.102)",
                labelStyle: TextStyle(color: Colors.cyanAccent),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
            onPressed: () {
              if (onAddCustomDevice != null) {
                onAddCustomDevice!(nameCtrl.text.trim(), ipCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text("Add & Link", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
