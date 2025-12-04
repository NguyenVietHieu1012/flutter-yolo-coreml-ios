import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _single = false;
  List<YOLOResult> _results = [];

  int _cropCount = 0;
  final int _cropLimit = 3;

  final Map<String, int> _stableCount = {};
  List<YOLOResult> _stableResults = [];
  final int _threshold = 8;

  final GlobalKey _cameraPreviewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Demo')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Single'),
              Switch(
                value: _single,
                onChanged: (v) => setState(() => _single = v),
              ),
              const Text('Multi'),
            ],
          ),
          Expanded(
            child: RepaintBoundary(
              key: _cameraPreviewKey,
              child: Stack(
                children: [
                  YOLOView(
                    modelPath: 'yolo11s_test4',
                    task: YOLOTask.detect,
                    showOverlays: false,
                    onResult: _onYoloResult,
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DetectionPainter(_results),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== YOLO RESULT HANDLER =====================
  Future<void> _onYoloResult(List<YOLOResult> res) async {
    if (_single && res.isNotEmpty) {
      final sorted = List.of(res)
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final target = sorted.first;

      final key = target.className;
      _stableCount[key] = (_stableCount[key] ?? 0) + 1;

      for (final k in _stableCount.keys.toList()) {
        if (k != key) _stableCount[k] = 0;
      }

      if (_stableCount[key]! >= _threshold) {
        _stableResults = [target];

        await _handleCaptureAndSave(target);

      } else {
        _stableResults = [];
      }

      setState(() => _results = _stableResults);
      return;
    }

    setState(() => _results = res);
  }

  bool _isProcessing = false;

  // ===================== CAPTURE + CROP + SAVE =====================
  Future<void> _handleCaptureAndSave(YOLOResult target) async {

    if (_cropCount >= _cropLimit) {
      print("Reached crop limit ($_cropLimit). Skip crop.");
      return;
    }

    if (_isProcessing) return;    // CHẶN GỌI SONG SONG
    _isProcessing = true;

    try {
      final boundary = _cameraPreviewKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary == null) {
        _isProcessing = false;
        return;
      }

      // pixelRatio = 1.0 để boundaryImage == UI thực tế (tránh scale sai)
      final ui.Image boundaryImage =
      await boundary.toImage(pixelRatio: 1.0);

      final ByteData? boundaryBytes =
      await boundaryImage.toByteData(format: ui.ImageByteFormat.png);

      if (boundaryBytes == null) {
        _isProcessing = false;
        return;
      }

      final Uint8List fullImage =
      boundaryBytes.buffer.asUint8List();

      // YOLO input = 320x320
      const double origW = 320;
      const double origH = 320;

      final double viewW = boundary.size.width;
      final double viewH = boundary.size.height;

      // SCALE YOLO → UI
      final scaleX = viewW / origW;
      final scaleY = viewH / origH;

      final bb = target.boundingBox;

      final Rect cropRectUI = Rect.fromLTRB(
        bb.left * scaleX,
        bb.top * scaleY,
        bb.right * scaleX,
        bb.bottom * scaleY,
      );

      // SCALE UI → ẢNH THẬT
      final scaleToImgX = boundaryImage.width / viewW;
      final scaleToImgY = boundaryImage.height / viewH;

      Rect cropRect = Rect.fromLTRB(
        cropRectUI.left * scaleToImgX,
        cropRectUI.top * scaleToImgY,
        cropRectUI.right * scaleToImgX,
        cropRectUI.bottom * scaleToImgY,
      );

      // ==== CLAMP ĐỂ TRÁNH VƯỢT BIÊN → ẢNH TRẮNG ====
      cropRect = Rect.fromLTRB(
        cropRect.left.clamp(0, boundaryImage.width.toDouble()),
        cropRect.top.clamp(0, boundaryImage.height.toDouble()),
        cropRect.right.clamp(0, boundaryImage.width.toDouble()),
        cropRect.bottom.clamp(0, boundaryImage.height.toDouble()),
      );

      print("IMG: ${boundaryImage.width}x${boundaryImage.height}");
      print("cropRect REAL: $cropRect");

      // Crop
      final Uint8List cropped = await _cropImage(boundaryImage, cropRect);

      await ImageGallerySaver.saveImage(
        cropped,
        quality: 95,
        name: "yolo_crop_${DateTime.now().millisecondsSinceEpoch}",
      );

      _cropCount++;
      print("Crop saved: $_cropCount/$_cropLimit");

    } catch (e) {
      print("Error saving crop: $e");
    }

    _isProcessing = false;
  }

  // ===================== CROP FUNCTION =====================
  Future<Uint8List> _cropImage(ui.Image sourceImage, Rect region) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final src = Rect.fromLTWH(
      region.left,
      region.top,
      region.width,
      region.height,
    );

    final dst = Rect.fromLTWH(0, 0, region.width, region.height);

    canvas.drawImageRect(sourceImage, src, dst, Paint());

    final ui.Image cropped = await recorder
        .endRecording()
        .toImage(region.width.toInt(), region.height.toInt());

    final ByteData? png =
    await cropped.toByteData(format: ui.ImageByteFormat.png);

    return png!.buffer.asUint8List();
  }
}

// ===================== PAINTER =====================
class _DetectionPainter extends CustomPainter {
  final List<YOLOResult> results;

  _DetectionPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    final firstBB = results.first.boundingBox;
    final frameW = firstBB.right;
    final frameH = firstBB.bottom;

    final scaleX = size.width / frameW;
    final scaleY = size.height / frameH;

    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 0, 0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (final r in results) {
      final bb = r.boundingBox;

      final rect = Rect.fromLTRB(
        bb.left * scaleX,
        bb.top * scaleY,
        bb.right * scaleX,
        bb.bottom * scaleY,
      );

      canvas.drawRect(rect, paint);

      final label =
          '${r.className} ${(r.confidence * 100).toStringAsFixed(1)}%';

      tp.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.red, fontSize: 14),
      );
      tp.layout();
      tp.paint(canvas, Offset(rect.left, rect.top - 18));
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
