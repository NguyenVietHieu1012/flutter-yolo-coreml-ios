import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  // ================= YOLO CONTROL =================
  final YOLOViewController _controller = YOLOViewController();
  bool _isCapturing = false;
  bool _pauseDetection = false;

  // ================= API RESULT OVERLAY =================
  bool _showResultOverlay = false;
  String? _apiResult;
  double? _apiConfidence;

  // ================= SCENE STABILITY =================
  List<YOLOResult>? _lastResults;
  DateTime? _sceneStableSince;
  final Duration _sceneStableDuration = const Duration(seconds: 5);
  final double _movementThreshold = 5.0;
  double _stabilityProgress = 0.0;

  // ================= STABLE DETECTION TIMER =================
  final Map<String, DateTime> _firstSeen = {};
  final Duration _requiredDuration = const Duration(seconds: 3);

  // ================= RANDOM IMAGE_ID =================
  String generateImageId({int length = 7}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ================= SAVE IMAGE =================
  Future<void> _saveToGallery(Uint8List bytes) async {
    await ImageGallerySaver.saveImage(bytes);
  }

  // ================= UPLOAD TO API =================
  Future<Map<String, dynamic>> uploadToApi({
    required Uint8List imageBytes,
    required List<List<double>> boundingBoxes,
  }) async {
    final uri = Uri.parse(
      "http://10.0.64.77:60475/api/v1/sterilization/analyze",
    );

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'capture.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    request.fields['imageId'] = generateImageId();
    request.fields['timestamp'] = DateTime.now().toIso8601String();
    request.fields['user'] = 'test_user';
    request.fields['boundingBoxes'] = jsonEncode(boundingBoxes);
    request.headers['accept'] = 'application/json';

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('API ERROR ${response.statusCode}: $body');
    }

    debugPrint("UPLOAD SUCCESS => $body");
    return jsonDecode(body);
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

  // ================= CAPTURE =================
  Future<void> _capture(YOLOResult r) async {
    if (_isCapturing) return;

    _isCapturing = true;
    _pauseDetection = true;

    try {
      await _controller.setShowOverlays(false);
      await Future.delayed(const Duration(milliseconds: 80));

      final Uint8List? bytes = await _controller.captureFrame();
      if (bytes == null) return;

      final box = r.boundingBox;

      final response = await uploadToApi(
        imageBytes: bytes,
        boundingBoxes: [
          [box.left, box.top, box.right, box.bottom],
        ],
      );

      final resultObj = response['results']?[0];

      setState(() {
        _apiResult = resultObj?['result'] ?? 'Undefined';
        _apiConfidence =
            (resultObj?['confidence'] as num?)?.toDouble();
        _showResultOverlay = true;
      });
    } catch (e) {
      debugPrint("[CAPTURE ERROR] $e");
      _pauseDetection = false;
    } finally {
      await _controller.setShowOverlays(true); // ⭐
      _isCapturing = false;
    }
  }

  // ================= YOLO CALLBACK =================
  Future<void> _onResult(List<YOLOResult> results) async {
    if (_pauseDetection || _isCapturing) return;

    final now = DateTime.now();
    final filtered = results.where((r) => r.confidence >= 0.9).toList();
    final bestResult = _getHighestConfidence(filtered);

    if (bestResult == null) {
      _lastResults = null;
      _sceneStableSince = null;
      _stabilityProgress = 0.0;
      setState(() {});
      return;
    }

    final singleResult = [bestResult];

    if (_lastResults != null && _isSceneStable(singleResult, _lastResults!)) {
      _sceneStableSince ??= now;
    } else {
      _sceneStableSince = null;
      _stabilityProgress = 0.0;
    }

    _lastResults = singleResult;

    if (_sceneStableSince != null) {
      final elapsed = now.difference(_sceneStableSince!);
      _stabilityProgress =
          (elapsed.inMilliseconds / _sceneStableDuration.inMilliseconds)
              .clamp(0.0, 1.0);
    }

    if (_sceneStableSince == null ||
        now.difference(_sceneStableSince!) < _sceneStableDuration) {
      _firstSeen.clear();
      setState(() {});
      return;
    }

    final r = bestResult;
    _firstSeen.putIfAbsent(r.className, () => now);

    if (now.difference(_firstSeen[r.className]!) >= _requiredDuration) {
      _firstSeen.clear();
      _sceneStableSince = null;
      _stabilityProgress = 0.0;
      await _capture(r);
    }
  }

  // ======================================
  YOLOResult? _getHighestConfidence(List<YOLOResult> results) {
    if (results.isEmpty) return null;

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.first;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DUSKIN APP DEMO")),
      body: Stack(
        children: [
          YOLOView(
            modelPath: 'yolov8s_trained_duskin_dataset_81_epochs_640_imgsz',
            task: YOLOTask.detect,
            controller: _controller,
            confidenceThreshold: 0.5,
            onResult: _onResult,
            showOverlays: true,
            useGpu: true,
          ),

          // ===== STABILITY PROGRESS =====
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SCENE STABILITY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _stabilityProgress,
                    minHeight: 10,
                  ),
                ],
              ),
            ),
          ),

          // ===== RESULT OVERLAY =====
          if (_showResultOverlay)
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  setState(() {
                    _showResultOverlay = false;
                    _apiResult = null;
                    _apiConfidence = null;
                    _pauseDetection = false;
                  });

                  // ⭐ FIX QUAN TRỌNG
                  await Future.delayed(const Duration(milliseconds: 50));
                  await _controller.setShowOverlays(true);
                },
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _apiResult == 'Sterilized'
                            ? Icons.check_circle
                            : _apiResult == 'Unsterilized'
                            ? Icons.cancel
                            : Icons.help_outline,
                        color: _apiResult == 'Sterilized'
                            ? Colors.green
                            : _apiResult == 'Unsterilized'
                            ? Colors.red
                            : Colors.orange,
                        size: 72,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _apiResult ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_apiConfidence != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Confidence: ${(_apiConfidence! * 100).toStringAsFixed(1)}%",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        "Tap to continue",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
