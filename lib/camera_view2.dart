import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
// import 'package:ultralytics_yolo/yolo_view.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {

  bool _single = false;
  List<YOLOResult> _results = [];

  Map<String, int> _stableCount = {};     // đếm số frame liên tiếp
  List<YOLOResult> _stableResults = [];   // kết quả đã đủ 8 frames
  final int _threshold = 8;

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
            child: Stack(
              children: [
                YOLOView(
                  modelPath: 'yolo11s_test',
                  task: YOLOTask.detect,
                  showOverlays: false,
                  onResult: (res) {
                    if (res.isEmpty) {
                      print('DEBUG: result empty');
                    } else {
                      final r = res.first;
                      print('===== DEBUG YOLO RESULT START =====');
                      print('runtimeType: ${r.runtimeType}');
                      print('toString(): $r');

                      // danh sách thuộc tính thử đọc
                      final keys = [
                        'bbox',
                        'boundingBox',
                        'rect',
                        'x',
                        'y',
                        'w',
                        'h',
                        'x1',
                        'y1',
                        'x2',
                        'y2',
                        'left',
                        'top',
                        'right',
                        'bottom',
                        'className',
                        'label',
                        'confidence',
                        'score'
                      ];

                      for (final key in keys) {
                        try {
                          final val = (r as dynamic).__getProperty(key);
                          // __getProperty là giả định; sẽ ném. Thay bằng truy cập trực tiếp theo key bên dưới.
                        } catch (_) {
                          // fallback: thử truy cập trực tiếp (dùng dynamic). Nếu không tồn tại, sẽ ném và bị catch.
                        }

                        // Thử đọc trực tiếp bằng dynamic access cho từng key
                        try {
                          final dynamic val = (r as dynamic).bbox; // mặc định thử bbox
                          print('bbox (direct): $val');
                        } catch (_) {}
                        try {
                          final dynamic val = (r as dynamic).boundingBox;
                          print('boundingBox (direct): $val');
                        } catch (_) {}
                        try {
                          final dynamic val = (r as dynamic).rect;
                          print('rect (direct): $val');
                        } catch (_) {}

                        // các trường số/label
                        try { print('className: ${(r as dynamic).className}'); } catch (_) {}
                        try { print('label: ${(r as dynamic).label}'); } catch (_) {}
                        try { print('confidence: ${(r as dynamic).confidence}'); } catch (_) {}
                        try { print('score: ${(r as dynamic).score}'); } catch (_) {}

                        // các toạ độ x/y/w/h / x1/y1/x2/y2 / left/top/right/bottom
                        // try { print('x: ${(r as dynamic).x}'); } catch (_) {}
                        // try { print('y: ${(r as dynamic).y}'); } catch (_) {}
                        // try { print('w: ${(r as dynamic).w}'); } catch (_) {}
                        // try { print('h: ${(r as dynamic).h}'); } catch (_) {}
                        //
                        // try { print('x1: ${(r as dynamic).x1}'); } catch (_) {}
                        // try { print('y1: ${(r as dynamic).y1}'); } catch (_) {}
                        // try { print('x2: ${(r as dynamic).x2}'); } catch (_) {}
                        // try { print('y2: ${(r as dynamic).y2}'); } catch (_) {}
                        //
                        // try { print('left: ${(r as dynamic).left}'); } catch (_) {}
                        // try { print('top: ${(r as dynamic).top}'); } catch (_) {}
                        // try { print('right: ${(r as dynamic).right}'); } catch (_) {}
                        // try { print('bottom: ${(r as dynamic).bottom}'); } catch (_) {}
                        //
                        // // Nếu có một list/array bbox như [x,y,w,h] hoặc [x1,y1,x2,y2]
                        // try {
                        //   final dynamic b = (r as dynamic).bbox;
                        //   if (b is List) print('bbox list: $b');
                        // } catch (_) {}
                        // try {
                        //   final dynamic bb = (r as dynamic).boundingBox;
                        //   if (bb is List) print('boundingBox list: $bb');
                        // } catch (_) {}

                        // Nếu có nested Rect-like object (flutter Rect), in ra các trường nếu có
                        try {
                          final dynamic bb = (r as dynamic).boundingBox;
                          try { print('bb.left: ${bb.left}'); } catch (_) {}
                          try { print('bb.top: ${bb.top}'); } catch (_) {}
                          try { print('bb.width: ${bb.width}'); } catch (_) {}
                          try { print('bb.height: ${bb.height}'); } catch (_) {}
                        } catch (_) {}
                      }

                      print('===== DEBUG YOLO RESULT END =====');
                    }

                    // ==== SINGLE MODE WITH 8-FRAMES-STABILITY ====
                    if (_single && res.isNotEmpty) {
                      // chọn object có confidence cao nhất
                      final sorted = List.of(res)
                        ..sort((a, b) => b.confidence.compareTo(a.confidence));
                      final target = sorted.first;

                      final key = target.className; // hoặc dùng target.className + tọa độ

                      // tăng bộ đếm
                      _stableCount[key] = (_stableCount[key] ?? 0) + 1;

                      // reset các key khác
                      for (final k in _stableCount.keys.toList()) {
                        if (k != key) _stableCount[k] = 0;
                      }

                      // nếu >=8 frames liên tục → giữ lại kết quả để Painter vẽ
                      if (_stableCount[key]! >= _threshold) {
                        _stableResults = [target];
                      } else {
                        _stableResults = [];
                      }

                      setState(() => _results = _stableResults);
                      return;
                    }

                    // ==== MULTI MODE bình thường ====
                    setState(() => _results = res);

                  },
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
        ],
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<YOLOResult> results;

  _DetectionPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    // boundingBox pixel tuyệt đối
    final bb = results.first.boundingBox;

    // Suy ra size của frame gốc YOLO
    final frameWidth = bb.right;   // giá trị pixel max
    final frameHeight = bb.bottom; // giá trị pixel max

    final scaleX = size.width / frameWidth;
    final scaleY = size.height / frameHeight;

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
          text: label, style: const TextStyle(color: Colors.red, fontSize: 14));
      tp.layout();

      tp.paint(canvas, Offset(rect.left, rect.top - 18));
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

