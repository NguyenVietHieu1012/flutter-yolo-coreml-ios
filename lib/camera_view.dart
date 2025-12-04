import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  final Map<String, DateTime> _firstSeen = {};
  final Duration _requiredDuration = const Duration(seconds: 3);

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    final y = t.year.toString();
    return '$h:$m:$s - $d/$mo/$y';
  }

  // ====== GHI LOG VÀO FILE ======
  Future<void> _appendLogToFile(String text) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/logs.txt';
    final file = File(filePath);

    // Ghi file
    await file.writeAsString('$text\n', mode: FileMode.append);

    // In ra đường dẫn
    debugPrint('LOG FILE PATH: $filePath');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Demo')),
      body: YOLOView(
        modelPath: 'yolo11s_test4',
        task: YOLOTask.detect,
        onResult: (results) async {
          final now = DateTime.now();

          final filtered =
          results.where((r) => r.confidence >= 0.90).toList();

          final currentClasses = <String>{};
          for (final r in filtered) {
            currentClasses.add(r.className);
          }

          _firstSeen.removeWhere((cls, _) => !currentClasses.contains(cls));

          for (final r in filtered) {
            final cls = r.className;
            final box = r.boundingBox;

            _firstSeen.putIfAbsent(cls, () => now);

            final duration = now.difference(_firstSeen[cls]!);

            if (duration >= _requiredDuration) {
              final ts = _formatTime(now);

              final log =
                  '[DETECTED] $ts | $cls '
                  'conf=${(r.confidence * 100).toStringAsFixed(1)}% '
                  'box: L=${box.left.toStringAsFixed(2)}, '
                  'T=${box.top.toStringAsFixed(2)}, '
                  'R=${box.right.toStringAsFixed(2)}, '
                  'B=${box.bottom.toStringAsFixed(2)}';

              debugPrint(log);

              await _appendLogToFile(log);

              // Optional: reset tránh in liên tục
              _firstSeen[cls] = now;
            }
          }
        },
      ),
    );
  }
}
