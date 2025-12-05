import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  // ================= YOLO CONTROL =================
  final YOLOViewController _controller = YOLOViewController();
  bool _showYolo = true;
  bool _isCapturing = false;

  // ================= STABLE DETECTION TIMER =================
  final Map<String, DateTime> _firstSeen = {};
  final Duration _requiredDuration = const Duration(seconds: 3);

  // ================= FORMATTING =================
  String _formatTime(DateTime t) {
    return "${t.hour.toString().padLeft(2, '0')}:"
        "${t.minute.toString().padLeft(2, '0')}:"
        "${t.second.toString().padLeft(2, '0')} - "
        "${t.day.toString().padLeft(2, '0')}/"
        "${t.month.toString().padLeft(2, '0')}/"
        "${t.year}";
  }

  // ================= LOGGING =================
  Future<void> _appendLogToFile(String text) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/logs.txt';
    final file = File(path);

    await file.writeAsString('$text\n', mode: FileMode.append);
    debugPrint("LOG => $text");
    debugPrint("LOG PATH: $path");
  }

  // ================= SAVE IMAGE =================
  Future<void> _saveToGallery(Uint8List bytes) async {
    await ImageGallerySaver.saveImage(bytes);
    debugPrint("[SAVE] Saved to gallery");
  }

  // ================= RESTART CAMERA VIEW =================
  Future<void> _restartCamera() async {
    setState(() => _showYolo = false);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _showYolo = true);
  }

  // ================= CAPTURE LOGIC =================
  Future<void> _capture(YOLOResult r) async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      debugPrint("[CAPTURE] Prepare: hiding bounding boxes");
      await _controller.setShowOverlays(false);

      // Cho camera update lại khung nhìn
      await Future.delayed(const Duration(milliseconds: 120));

      debugPrint("[CAPTURE] Taking frame...");
      final Uint8List? bytes = await _controller.captureFrame();

      if (bytes != null) {
        await _saveToGallery(bytes);
        debugPrint("[CAPTURE] Frame saved");
      } else {
        debugPrint("[CAPTURE] ERROR: captureFrame() returned NULL");
      }

      // Bật overlay lại
      debugPrint("[CAPTURE] Restoring bounding boxes");
      await _controller.setShowOverlays(true);

      // Tuỳ theo logic của bạn có thể giữ hoặc bỏ bước này
      await _restartCamera();

    } catch (e) {
      debugPrint("[CAPTURE] ERROR => $e");
    } finally {
      _isCapturing = false;
    }
  }


  // ================= ON RESULT CALLBACK =================
  Future<void> _onResult(List<YOLOResult> results) async {
    final now = DateTime.now();

    final filtered = results.where((r) => r.confidence >= 0.90).toList();
    final visibleClasses = filtered.map((e) => e.className).toSet();

    _firstSeen.removeWhere((cls, _) => !visibleClasses.contains(cls));

    for (final r in filtered) {
      final cls = r.className;

      _firstSeen.putIfAbsent(cls, () => now);
      final duration = now.difference(_firstSeen[cls]!);

      if (duration >= _requiredDuration) {
        final box = r.boundingBox;

        final log =
            "[DETECTED] ${_formatTime(now)} | $cls "
            "conf=${(r.confidence * 100).toStringAsFixed(1)}% "
            "[L=${box.left.toStringAsFixed(2)}, "
            "T=${box.top.toStringAsFixed(2)}, "
            "R=${box.right.toStringAsFixed(2)}, "
            "B=${box.bottom.toStringAsFixed(2)}]";

        debugPrint(log);
        await _appendLogToFile(log);

        _firstSeen[cls] = now;

        await _capture(r);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YOLO Demo")),
      body: _showYolo
          ? YOLOView(
        modelPath: 'yolo11s_test4',
        task: YOLOTask.detect,
        controller: _controller,
        confidenceThreshold: 0.5,
        onResult: _onResult,
        showOverlays: true,
        useGpu: true,
      )
          : const SizedBox(),
    );
  }
}
