import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _single = false;
  List<YOLOResult> _results = [];

  Map<String, int> _stableCount = {};
  List<YOLOResult> _stableResults = [];
  final int _threshold = 8;

  // DEBUG: lưu kích thước view camera
  Size? _previewSize;
  Size? _widgetSize;

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

          ///
          /// LAYOUT BUILDER - debug kích thước widget camera
          ///
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              _widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                children: [
                  YOLOView(
                    modelPath: 'yolo11s_test',
                    task: YOLOTask.detect,
                    showOverlays: false,
                    onResult: (res) {
                      ///
                      /// DEBUG: Hiện số lượng object detect mỗi frame
                      ///
                      print('DEBUG: detected count = ${res.length}');

                      if (_widgetSize != null) {
                        print('DEBUG widgetSize: $_widgetSize');
                      }

                      if (res.isNotEmpty) {
                        final r = res.first;

                        print('===== DEBUG YOLO RAW RESULT START =====');
                        print('class: ${r.className}');
                        print('confidence: ${r.confidence}');
                        print('boundingBox raw: ${r.boundingBox}');
                        print('left=${r.boundingBox.left}, top=${r.boundingBox.top},'
                            ' right=${r.boundingBox.right}, bottom=${r.boundingBox.bottom}');
                        print('===== DEBUG YOLO RAW RESULT END =====');
                      }

                      ///
                      /// Lỗi Invalid image dimensions (nếu boundingBox = 0)
                      ///
                      if (res.isNotEmpty) {
                        final bb = res.first.boundingBox;
                        if (bb.width <= 0 || bb.height <= 0) {
                          print('ERROR: Invalid bounding box dimensions: '
                              'w=${bb.width}, h=${bb.height}');
                        }
                      }

                      ///
                      /// SINGLE MODE: giữ lại object ổn định 8 frames
                      ///
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
                        } else {
                          _stableResults = [];
                        }

                        setState(() => _results = _stableResults);
                        return;
                      }

                      ///
                      /// MULTI MODE
                      ///
                      setState(() => _results = res);
                    },
                  ),

                  ///
                  /// Custom Painter
                  ///
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DetectionPainter(
                        _results,
                        widgetSize: _widgetSize,
                        onDebug: (msg) => print(msg), // callback debug
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<YOLOResult> results;

  final Size? widgetSize;

  final void Function(String msg)? onDebug;

  _DetectionPainter(
      this.results, {
        required this.widgetSize,
        this.onDebug,
      });

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;
    if (widgetSize == null) return;

    final bb = results.first.boundingBox;

    final frameWidth = bb.right;
    final frameHeight = bb.bottom;

    if (onDebug != null) {
      onDebug!(
        'DEBUG: frameWidth=$frameWidth, frameHeight=$frameHeight, '
            'widgetWidth=${widgetSize!.width}, widgetHeight=${widgetSize!.height}',
      );
    }

    final scaleX = widgetSize!.width / frameWidth;
    final scaleY = widgetSize!.height / frameHeight;

    if (onDebug != null) {
      onDebug!(
          'DEBUG scale: scaleX=$scaleX, scaleY=$scaleY -> applied to all rects');
    }

    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 0, 0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final tp = TextPainter(textDirection: TextDirection.ltr);

    ///
    /// Vẽ bounding boxes
    ///
    for (final r in results) {
      final bb = r.boundingBox;

      final rect = Rect.fromLTRB(
        bb.left * scaleX,
        bb.top * scaleY,
        bb.right * scaleX,
        bb.bottom * scaleY,
      );

      canvas.drawRect(rect, paint);

      tp.text = TextSpan(
        text: '${r.className} ${(r.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(color: Colors.red, fontSize: 14),
      );
      tp.layout();
      tp.paint(canvas, Offset(rect.left, rect.top - 18));

      if (onDebug != null) {
        onDebug!(
            'DRAW RECT: raw=($bb), scaled=($rect), class=${r.className}, conf=${r.confidence}');
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
