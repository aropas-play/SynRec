import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_controller.dart';
import '../widgets/status_squares_overlay.dart';
import 'synrec_fragment.dart';
import 'synviewrec_fragment.dart';

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
              "${controller.activeFragment == AppFragment.synrec ? 'synrec' : 'synviewrec'} - Target ${controller.isMaster ? 'A (Master)' : 'B (Slave)'}",
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
                    case 'folder_manager':
                      _showFolderManagerDialog(context, controller);
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
                  const PopupMenuItem<String>(
                    value: 'folder_manager',
                    child: Row(
                      children: [
                        Icon(Icons.folder_special, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Folder Manager', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              // Active Fragment View (synrec or synviewrec)
              Positioned.fill(
                child: controller.activeFragment == AppFragment.synrec
                    ? const SynRecFragment()
                    : const SynViewRecFragment(),
              ),

              // Top Strap with Master/Slave toggle + Fragment Navigation Arrows
              Positioned(
                top: 16,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Horizontal ScrollView to prevent overflow on narrow portrait screens
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // TOP LEFT: Red Strap (Master/Slave Toggle + Navigation Arrow)
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Master / Slave Checkbox
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
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  height: 16,
                                  width: 1,
                                  color: Colors.white30,
                                ),
                                const SizedBox(width: 6),

                                // Navigation Strap Arrows & Text
                                if (controller.activeFragment == AppFragment.synrec) ...[
                                  const Text(
                                    "synrec",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  InkWell(
                                    onTap: () => controller.navigateNextFragment(),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_forward_ios, color: Colors.yellowAccent, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  InkWell(
                                    onTap: () => controller.navigatePreviousFragment(),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_back_ios, color: Colors.yellowAccent, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    "synviewrec",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Camera Ready / Status Info Box
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
                          const SizedBox(width: 8),

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

                    // Status Indicator Squares Overlay on Master Mode (Under Master Strap)
                    if (controller.isMaster) ...[
                      const SizedBox(height: 6),
                      StatusSquaresOverlay(
                        activeCandidates: controller.activeCandidateList,
                        isRecording: (id) => controller.isDeviceRecording(id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFolderManagerDialog(BuildContext context, AppController controller) async {
    String currentPhotos = controller.customPhotosFolder ?? await controller.storageService.getPhotosFolder();
    String currentVideos = controller.customVideosFolder ?? await controller.storageService.getVideosFolder();

    TextEditingController photosCtrl = TextEditingController(text: currentPhotos);
    TextEditingController videosCtrl = TextEditingController(text: currentVideos);


    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text("Folder Manager", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "View or customize the destination folders where captured photos and recorded videos are saved.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: photosCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "Photos Save Folder Path",
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: videosCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "Videos Save Folder Path",
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.saveCustomFolders(null, null);
              Navigator.of(ctx).pop();
            },
            child: const Text("Reset Default", style: TextStyle(color: Colors.orangeAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade800),
            onPressed: () {
              controller.saveCustomFolders(photosCtrl.text.trim(), videosCtrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text("Save Folders", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
          child: SingleChildScrollView(
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
                  height: 180,
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
          child: SingleChildScrollView(
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
            final favorites = ctrl.favoriteDevices;
            final devices = ctrl.discoveredDevices;
            final activeList = ctrl.activeCandidateList;

            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
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

                    // Sublist Actions Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Active Candidates: ${activeList.length} selected",
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
                    const SizedBox(height: 8),

                    // ⭐ FAVORITE CANDIDATES LIST
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "FAVORITES LIST (Persistent Sublist)",
                          style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    favorites.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Text(
                              "No saved favorites yet. Favorites are saved automatically after selection.",
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          )
                        : Column(
                            children: favorites.map((dev) {
                              final bool isChecked = ctrl.isFavoriteSelected(dev);
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isChecked ? Colors.amber.shade900.withAlpha(180) : Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isChecked ? Colors.amberAccent : Colors.white12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: Colors.amberAccent,
                                      checkColor: Colors.black,
                                      side: const BorderSide(color: Colors.white60),
                                      onChanged: (val) {
                                        ctrl.toggleFavoriteCandidate(dev);
                                      },
                                    ),
                                    const Icon(Icons.star, color: Colors.amberAccent, size: 16),
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
                                            "Saved IP: ${dev.id}",
                                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                    const SizedBox(height: 12),

                    // 📡 DISCOVERED DEVICES AROUND LIST
                    const Row(
                      children: [
                        Icon(Icons.wifi_find, color: Colors.cyanAccent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "FOUND DEVICES AROUND (Discovered)",
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 160,
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
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isChecked ? Colors.teal.shade900.withAlpha(200) : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isChecked ? Colors.tealAccent : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
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
                                        size: 16,
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
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
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
