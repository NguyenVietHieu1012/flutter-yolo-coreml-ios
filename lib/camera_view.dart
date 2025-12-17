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

  // ================= SCENE STABILITY =================
  List<YOLOResult>? _lastResults;
  DateTime? _sceneStableSince;
  final Duration _sceneStableDuration = const Duration(seconds: 5);
  final double _movementThreshold = 5.0; // pixel threshold

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

  // ================= SCENE STABILITY CHECK =================
  bool _isSceneStable(
      List<YOLOResult> current,
      List<YOLOResult> previous,
      ) {
    if (current.length != previous.length) return false;

    for (int i = 0; i < current.length; i++) {
      final c = current[i].boundingBox;
      final p = previous[i].boundingBox;

      if ((c.left - p.left).abs() > _movementThreshold ||
          (c.top - p.top).abs() > _movementThreshold ||
          (c.right - p.right).abs() > _movementThreshold ||
          (c.bottom - p.bottom).abs() > _movementThreshold) {
        return false;
      }
    }
    return true;
  }

  // ================= CAPTURE LOGIC =================
  Future<void> _capture(YOLOResult r) async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      await _controller.setShowOverlays(false);
      await Future.delayed(const Duration(milliseconds: 120));

      final Uint8List? bytes = await _controller.captureFrame();
      if (bytes != null) {
        await _saveToGallery(bytes);
      }

      await _controller.setShowOverlays(true);
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

    // Lọc confidence
    final filtered = results.where((r) => r.confidence >= 0.90).toList();

    // ===== PHASE 1: SCENE STABILITY (5s) =====
    if (_lastResults != null &&
        _isSceneStable(filtered, _lastResults!)) {
      _sceneStableSince ??= now;
    } else {
      _sceneStableSince = null;
    }

    _lastResults = filtered;

    // Nếu scene chưa đứng yên đủ 5s → reset detect timer
    if (_sceneStableSince == null ||
        now.difference(_sceneStableSince!) < _sceneStableDuration) {
      _firstSeen.clear();
      return;
    }

    // ===== PHASE 2: OBJECT STABLE DETECTION (3s) =====
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

        await _appendLogToFile(log);

        _firstSeen[cls] = now;
        _sceneStableSince = null; // reset scene stability
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
