import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class StatusSquaresOverlay extends StatelessWidget {
  final List<SyncDeviceItem> activeCandidates;
  final bool Function(String deviceId) isRecording;

  const StatusSquaresOverlay({
    super.key,
    required this.activeCandidates,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    if (activeCandidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Targets: ",
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Wrap(
            spacing: 6,
            children: List.generate(activeCandidates.length, (index) {
              final dev = activeCandidates[index];
              final bool recording = isRecording(dev.id);

              return Tooltip(
                message: "Target ${index + 1}: ${dev.name}\nStatus: ${recording ? 'RECORDING' : 'READY'}",
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: recording ? Colors.greenAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: recording ? Colors.greenAccent : Colors.white70,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        color: recording ? Colors.black : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
