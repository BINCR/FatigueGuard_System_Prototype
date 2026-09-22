import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FaceMetrics {
  const FaceMetrics({
    required this.faceDetected,
    required this.ear,
    required this.mar,
    required this.blinkRate,
    required this.headPosition,
    required this.yaw,
    required this.pitch,
  });

  const FaceMetrics.noFace()
    : faceDetected = false,
      ear = 0,
      mar = 0,
      blinkRate = 0,
      headPosition = 'No face',
      yaw = 0,
      pitch = 0;

  final bool faceDetected;
  final double ear;
  final double mar;
  final int blinkRate;
  final String headPosition;
  final double yaw;
  final double pitch;
}

/// Downloads the latest ESP32 JPEG and performs face analysis on the phone.
/// ML Kit runs locally; frames are not uploaded to a cloud service.
class FaceAnalysisService {
  FaceAnalysisService({this.baseUrl = 'http://192.168.4.1'});

  final String baseUrl;
  final http.Client _client = http.Client();
  final StreamController<FaceMetrics> _metricsController =
      StreamController<FaceMetrics>.broadcast();

  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  Timer? _timer;
  File? _frameFile;
  bool _processing = false;
  bool _wasClosed = false;
  DateTime? _closedStartedAt;
  final List<DateTime> _blinkTimes = <DateTime>[];

  Stream<FaceMetrics> get metrics => _metricsController.stream;

  Future<void> start() async {
    stop();
    final Directory tempDirectory = await getTemporaryDirectory();
    _frameFile = File('${tempDirectory.path}/fatigueguard_face_frame.jpg');

    unawaited(_analyseLatestFrame());
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_analyseLatestFrame()),
    );
  }

  Future<void> _analyseLatestFrame() async {
    if (_processing || _frameFile == null) return;
    _processing = true;

    try {
      final http.Response response = await _client
          .get(
            Uri.parse(
              '$baseUrl/capture?t=${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;

      await _frameFile!.writeAsBytes(response.bodyBytes, flush: true);
      final InputImage image = InputImage.fromFilePath(_frameFile!.path);
      final List<Face> faces = await _detector.processImage(image);

      if (faces.isEmpty) {
        _metricsController.add(const FaceMetrics.noFace());
        _resetClosedState();
        return;
      }

      // Use the largest face when another passenger appears in the frame.
      faces.sort((Face first, Face second) {
        final double firstArea =
            first.boundingBox.width * first.boundingBox.height;
        final double secondArea =
            second.boundingBox.width * second.boundingBox.height;
        return secondArea.compareTo(firstArea);
      });

      final Face face = faces.first;
      final double leftEar = _contourAspectRatio(
        face.contours[FaceContourType.leftEye]?.points,
      );
      final double rightEar = _contourAspectRatio(
        face.contours[FaceContourType.rightEye]?.points,
      );
      final double ear = _averageAvailable(leftEar, rightEar);
      final double mar = _mouthAspectRatio(face);

      _updateBlinkCounter(face: face, ear: ear);

      final double yaw = face.headEulerAngleY ?? 0;
      final double pitch = face.headEulerAngleX ?? 0;

      _metricsController.add(
        FaceMetrics(
          faceDetected: true,
          ear: ear,
          mar: mar,
          blinkRate: _blinkTimes.length,
          headPosition: _headPosition(yaw: yaw, pitch: pitch),
          yaw: yaw,
          pitch: pitch,
        ),
      );
    } catch (_) {
      // A missed frame should not stop the next scheduled analysis.
    } finally {
      _processing = false;
    }
  }

  double _contourAspectRatio(List<math.Point<int>>? points) {
    if (points == null || points.length < 4) return 0;

    int minX = points.first.x;
    int maxX = points.first.x;
    int minY = points.first.y;
    int maxY = points.first.y;

    for (final math.Point<int> point in points.skip(1)) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }

    final double width = (maxX - minX).toDouble();
    if (width <= 0) return 0;
    return (maxY - minY) / width;
  }

  double _mouthAspectRatio(Face face) {
    final List<math.Point<int>> points = <math.Point<int>>[];

    for (final FaceContourType type in <FaceContourType>[
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
    ]) {
      final List<math.Point<int>>? contour = face.contours[type]?.points;
      if (contour != null) points.addAll(contour);
    }

    return _contourAspectRatio(points);
  }

  double _averageAvailable(double first, double second) {
    if (first > 0 && second > 0) return (first + second) / 2;
    return math.max(first, second);
  }

  void _updateBlinkCounter({required Face face, required double ear}) {
    final DateTime now = DateTime.now();
    _blinkTimes.removeWhere(
      (DateTime blink) => now.difference(blink) > const Duration(minutes: 1),
    );

    final List<double> probabilities = <double>[
      if (face.leftEyeOpenProbability != null) face.leftEyeOpenProbability!,
      if (face.rightEyeOpenProbability != null) face.rightEyeOpenProbability!,
    ];
    final double openProbability = probabilities.isEmpty
        ? 1
        : probabilities.reduce((double a, double b) => a + b) /
              probabilities.length;

    // These are starting values. They will be calibrated using the live values.
    final bool isClosed = openProbability < 0.35 || (ear > 0 && ear < 0.18);

    if (isClosed && !_wasClosed) {
      _closedStartedAt = now;
    } else if (!isClosed && _wasClosed && _closedStartedAt != null) {
      final Duration closedFor = now.difference(_closedStartedAt!);
      if (closedFor >= const Duration(milliseconds: 80) &&
          closedFor <= const Duration(milliseconds: 900)) {
        _blinkTimes.add(now);
      }
      _closedStartedAt = null;
    }

    _wasClosed = isClosed;
  }

  String _headPosition({required double yaw, required double pitch}) {
    if (yaw <= -20) return 'Left';
    if (yaw >= 20) return 'Right';
    if (pitch <= -18) return 'Down';
    if (pitch >= 18) return 'Up';
    return 'Stable';
  }

  void _resetClosedState() {
    _wasClosed = false;
    _closedStartedAt = null;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    _client.close();
    await _detector.close();
    await _metricsController.close();
  }
}
