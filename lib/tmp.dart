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

  // ===================== CAPTURE + CROP + SAVE =====================
  Future<void> _handleCaptureAndSave(YOLOResult target) async {
    try {
      final boundary = _cameraPreviewKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);

      if (bytes == null) return;

      final Uint8List fullImage = bytes.buffer.asUint8List();

      final bb = target.boundingBox;
      final double w = boundary.size.width;
      final double h = boundary.size.height;

      final Rect cropRect = Rect.fromLTRB(
        bb.left.clamp(0, w),
        bb.top.clamp(0, h),
        bb.right.clamp(0, w),
        bb.bottom.clamp(0, h),
      );

      final Uint8List cropped = await _cropImage(fullImage, cropRect);

      await ImageGallerySaver.saveImage(
        cropped,
        quality: 95,
        name: "yolo_crop_${DateTime.now().millisecondsSinceEpoch}",
      );

      print("Saved crop.");
    } catch (e) {
      print("Error saving crop: $e");
    }
  }

  // ===================== CROP FUNCTION =====================
  Future<Uint8List> _cropImage(Uint8List bytes, Rect region) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image original = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      original,
      region,
      Rect.fromLTWH(0, 0, region.width, region.height),
      Paint(),
    );

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
