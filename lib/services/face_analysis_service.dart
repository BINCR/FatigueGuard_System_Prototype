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
    required this.eyeOpenProbability,
    required this.blinkRate,
    required this.perclos,
    required this.fatigueDetected,
    required this.fatigueReason,
    required this.alertness,
    required this.headPosition,
    required this.yaw,
    required this.pitch,
  });

  const FaceMetrics.noFace()
    : faceDetected = false,
      ear = 0,
      mar = 0,
      eyeOpenProbability = -1,
      blinkRate = 0,
      perclos = 0,
      fatigueDetected = false,
      fatigueReason = 'No face detected',
      alertness = 0,
      headPosition = 'No face',
      yaw = 0,
      pitch = 0;

  final bool faceDetected;
  final double ear;
  final double mar;
  final double eyeOpenProbability;
  final int blinkRate;
  final double perclos;
  final bool fatigueDetected;
  final String fatigueReason;
  final double alertness;
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
  bool _stableEyesClosed = false;
  DateTime? _closedStartedAt;
  final List<DateTime> _blinkTimes = <DateTime>[];
  final List<_EyeSample> _eyeSamples = <_EyeSample>[];
  DateTime? _yawnStartedAt;
  final List<double> _calibrationYaws = <double>[];
  final List<double> _calibrationPitches = <double>[];
  double? _baselineYaw;
  double? _baselinePitch;

  // Starting thresholds for the ESP32 camera angle. They can be calibrated
  // later using several normal, closed-eye and yawning recordings.
  static const double _closedEarThreshold = 0.19;
  // Hysteresis prevents one noisy frame from rapidly changing open/closed.
  static const double _closeEyeProbabilityThreshold = 0.25;
  static const double _reopenEyeProbabilityThreshold = 0.45;
  static const double _yawnMarThreshold = 0.65;
  // ML Kit usually confirms closed eyes after several camera frames. Using
  // 900 ms here produces an observed warning after roughly 1.5-2 seconds.
  static const Duration _longClosureDuration = Duration(milliseconds: 900);
  static const Duration _yawnDuration = Duration(milliseconds: 1800);
  static const Duration _perclosWindow = Duration(seconds: 30);
  static const int _minimumPerclosSamples = 20;
  static const double _perclosAlertThreshold = 0.40;
  static const int _headCalibrationSamples = 6;
  static const double _relativeYawThreshold = 20;
  static const double _relativePitchThreshold = 18;

  Stream<FaceMetrics> get metrics => _metricsController.stream;

  Future<void> start() async {
    stop();
    _resetSessionState();
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
      final double? eyeOpenProbability = _averageEyeOpenProbability(face);

      final DateTime now = DateTime.now();
      final double yaw = face.headEulerAngleY ?? 0;
      final double pitch = face.headEulerAngleX ?? 0;
      final String headPosition = _calibratedHeadPosition(
        yaw: yaw,
        pitch: pitch,
      );

      // Eye probabilities become unreliable when the face is not frontal.
      // Only analyse eye closure/PERCLOS in a stable forward pose. Head-pose
      // reporting and yawn detection remain active in every detected pose.
      final bool headAllowsEyeAnalysis = headPosition == 'Stable';
      final bool eyesClosed = headAllowsEyeAnalysis && mar < _yawnMarThreshold
          ? _eyesAreClosed(ear: ear, eyeOpenProbability: eyeOpenProbability)
          : false;
      if (headAllowsEyeAnalysis) {
        _updateBlinkCounter(now: now, eyesClosed: eyesClosed);
        _updateEyeSamples(now: now, eyesClosed: eyesClosed);
      } else {
        _pauseEyeClosureState();
      }
      _updateYawnState(now: now, mar: mar);

      final double perclos = _calculatePerclos();
      final Duration eyeClosedFor = eyesClosed && _closedStartedAt != null
          ? now.difference(_closedStartedAt!)
          : Duration.zero;
      final Duration yawningFor = _yawnStartedAt == null
          ? Duration.zero
          : now.difference(_yawnStartedAt!);

      final bool longEyeClosure =
          headAllowsEyeAnalysis && eyeClosedFor >= _longClosureDuration;
      final bool sustainedYawn = yawningFor >= _yawnDuration;
      final bool highPerclos =
          headAllowsEyeAnalysis &&
          _eyeSamples.length >= _minimumPerclosSamples &&
          perclos >= _perclosAlertThreshold;
      final bool fatigueDetected =
          longEyeClosure || sustainedYawn || highPerclos;

      String fatigueReason = 'Normal';
      // A visible yawn should not be presented as an eye-closure event.
      if (sustainedYawn) {
        fatigueReason = 'Prolonged yawn detected';
      } else if (longEyeClosure) {
        fatigueReason = 'Eyes closed too long';
      } else if (highPerclos) {
        fatigueReason = 'Frequent eye closure';
      }

      final double eyeRisk = eyesClosed
          ? (eyeClosedFor.inMilliseconds / _longClosureDuration.inMilliseconds)
                .clamp(0.0, 1.0)
          : 0.0;
      final double yawnRisk = mar >= _yawnMarThreshold
          ? (yawningFor.inMilliseconds / _yawnDuration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
          : 0.0;
      final double perclosRisk =
          headAllowsEyeAnalysis && _eyeSamples.length >= _minimumPerclosSamples
          ? (perclos / _perclosAlertThreshold).clamp(0.0, 1.0)
          : 0.0;
      final double fatigueRisk = math.max(
        eyeRisk,
        math.max(yawnRisk, perclosRisk),
      );

      _metricsController.add(
        FaceMetrics(
          faceDetected: true,
          ear: ear,
          mar: mar,
          eyeOpenProbability: eyeOpenProbability ?? -1,
          blinkRate: _blinkTimes.length,
          perclos: perclos,
          fatigueDetected: fatigueDetected,
          fatigueReason: fatigueReason,
          alertness: (1.0 - fatigueRisk).clamp(0.0, 1.0),
          headPosition: headPosition,
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

  double? _averageEyeOpenProbability(Face face) {
    final List<double> probabilities = <double>[
      if (face.leftEyeOpenProbability != null) face.leftEyeOpenProbability!,
      if (face.rightEyeOpenProbability != null) face.rightEyeOpenProbability!,
    ];
    if (probabilities.isEmpty) return null;
    return probabilities.reduce((double a, double b) => a + b) /
        probabilities.length;
  }

  void _updateBlinkCounter({required DateTime now, required bool eyesClosed}) {
    _blinkTimes.removeWhere(
      (DateTime blink) => now.difference(blink) > const Duration(minutes: 1),
    );

    if (eyesClosed && !_wasClosed) {
      _closedStartedAt = now;
    } else if (!eyesClosed && _wasClosed && _closedStartedAt != null) {
      final Duration closedFor = now.difference(_closedStartedAt!);
      if (closedFor >= const Duration(milliseconds: 80) &&
          closedFor <= const Duration(milliseconds: 900)) {
        _blinkTimes.add(now);
      }
      _closedStartedAt = null;
    }

    _wasClosed = eyesClosed;
  }

  bool _eyesAreClosed({
    required double ear,
    required double? eyeOpenProbability,
  }) {
    // ML Kit's eye-open probability is more stable than contour EAR at the
    // low dashboard camera angle. EAR is only a fallback when classification
    // is unavailable.
    if (eyeOpenProbability != null) {
      if (_stableEyesClosed) {
        if (eyeOpenProbability > _reopenEyeProbabilityThreshold) {
          _stableEyesClosed = false;
        }
      } else if (eyeOpenProbability < _closeEyeProbabilityThreshold) {
        _stableEyesClosed = true;
      }
      return _stableEyesClosed;
    }

    _stableEyesClosed = ear > 0 && ear < _closedEarThreshold;
    return _stableEyesClosed;
  }

  void _updateEyeSamples({required DateTime now, required bool eyesClosed}) {
    _eyeSamples.add(_EyeSample(time: now, eyesClosed: eyesClosed));
    _eyeSamples.removeWhere(
      (_EyeSample sample) => now.difference(sample.time) > _perclosWindow,
    );
  }

  void _pauseEyeClosureState() {
    _wasClosed = false;
    _stableEyesClosed = false;
    _closedStartedAt = null;
  }

  double _calculatePerclos() {
    if (_eyeSamples.isEmpty) return 0;
    final int closedSamples = _eyeSamples
        .where((_EyeSample sample) => sample.eyesClosed)
        .length;
    return closedSamples / _eyeSamples.length;
  }

  void _updateYawnState({required DateTime now, required double mar}) {
    if (mar >= _yawnMarThreshold) {
      _yawnStartedAt ??= now;
    } else {
      _yawnStartedAt = null;
    }
  }

  String _calibratedHeadPosition({required double yaw, required double pitch}) {
    if (_baselineYaw == null || _baselinePitch == null) {
      _calibrationYaws.add(yaw);
      _calibrationPitches.add(pitch);

      if (_calibrationYaws.length < _headCalibrationSamples) {
        return 'Calibrating';
      }

      _baselineYaw =
          _calibrationYaws.reduce((a, b) => a + b) / _calibrationYaws.length;
      _baselinePitch =
          _calibrationPitches.reduce((a, b) => a + b) /
          _calibrationPitches.length;
      return 'Stable';
    }

    final double relativeYaw = yaw - _baselineYaw!;
    final double relativePitch = pitch - _baselinePitch!;

    if (relativeYaw <= -_relativeYawThreshold) return 'Left';
    if (relativeYaw >= _relativeYawThreshold) return 'Right';
    if (relativePitch <= -_relativePitchThreshold) return 'Down';
    if (relativePitch >= _relativePitchThreshold) return 'Up';
    return 'Stable';
  }

  void _resetSessionState() {
    _resetClosedState();
    _blinkTimes.clear();
    _calibrationYaws.clear();
    _calibrationPitches.clear();
    _baselineYaw = null;
    _baselinePitch = null;
  }

  void _resetClosedState() {
    _wasClosed = false;
    _stableEyesClosed = false;
    _closedStartedAt = null;
    _yawnStartedAt = null;
    _eyeSamples.clear();
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

class _EyeSample {
  const _EyeSample({required this.time, required this.eyesClosed});

  final DateTime time;
  final bool eyesClosed;
}
