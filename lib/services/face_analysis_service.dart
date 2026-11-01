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

  // ============================================================
  // EYE / BLINK DETECTION
  // ============================================================

  bool _wasClosed = false;
  bool _stableEyesClosed = false;
  DateTime? _closedStartedAt;

  final List<DateTime> _blinkTimes = <DateTime>[];
  final List<_EyeSample> _eyeSamples = <_EyeSample>[];

  // ============================================================
  // YAWN DETECTION
  // ============================================================

  DateTime? _yawnStartedAt;

  // ============================================================
  // HEAD CALIBRATION
  // ============================================================

  final List<double> _calibrationYaws = <double>[];
  final List<double> _calibrationPitches = <double>[];

  double? _baselineYaw;
  double? _baselinePitch;

  // ============================================================
  // NEW: REPEATED NODDING DETECTION
  // ============================================================

  /// True after the driver's head enters the Down position.
  bool _headWasDown = false;

  /// Time when the current downward head movement started.
  DateTime? _nodDownStartedAt;

  /// Stores completed nod timestamps.
  ///
  /// Example:
  /// Stable -> Down -> Stable = one completed nod.
  final List<DateTime> _nodTimes = <DateTime>[];

  // ============================================================
  // THRESHOLDS
  // ============================================================

  // Starting thresholds for the ESP32 camera angle.
  static const double _closedEarThreshold = 0.19;

  // Hysteresis prevents one noisy frame from rapidly changing
  // between eye open and eye closed.
  static const double _closeEyeProbabilityThreshold = 0.25;
  static const double _reopenEyeProbabilityThreshold = 0.45;

  // Mouth Aspect Ratio threshold for yawning.
  static const double _yawnMarThreshold = 0.65;

  // Long eye closure.
  static const Duration _longClosureDuration =
      Duration(milliseconds: 900);

  // Yawn must continue this long before being considered fatigue.
  static const Duration _yawnDuration =
      Duration(milliseconds: 1800);

  // PERCLOS settings.
  static const Duration _perclosWindow =
      Duration(seconds: 30);

  static const int _minimumPerclosSamples = 20;

  static const double _perclosAlertThreshold = 0.40;

  // Head calibration.
  static const int _headCalibrationSamples = 6;

  static const double _relativeYawThreshold = 20;

  static const double _relativePitchThreshold = 18;

  // ============================================================
  // NEW: NODDING SETTINGS
  // ============================================================

  /// Number of complete nods required to trigger fatigue.
  static const int _nodAlertCount = 3;

  /// All required nods must happen inside this time window.
  static const Duration _nodWindow =
      Duration(seconds: 6);

  /// Very fast Down -> Stable movements may just be ML Kit noise.
  static const Duration _minimumNodDuration =
      Duration(milliseconds: 250);

  /// If the head stays down longer than this, it is not counted
  /// as one normal nod cycle.
  static const Duration _maximumNodDuration =
      Duration(seconds: 2);

  Stream<FaceMetrics> get metrics => _metricsController.stream;

  // ============================================================
  // START ANALYSIS
  // ============================================================

  Future<void> start() async {
    stop();

    _resetSessionState();

    final Directory tempDirectory =
        await getTemporaryDirectory();

    _frameFile = File(
      '${tempDirectory.path}/fatigueguard_face_frame.jpg',
    );

    // Analyse immediately.
    unawaited(_analyseLatestFrame());

    // Then analyse every 500 ms.
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_analyseLatestFrame()),
    );
  }

  // ============================================================
  // MAIN FACE ANALYSIS
  // ============================================================

  Future<void> _analyseLatestFrame() async {
    if (_processing || _frameFile == null) {
      return;
    }

    _processing = true;

    try {
      // ----------------------------------------------------------
      // 1. GET JPEG FROM ESP32
      // ----------------------------------------------------------

      final http.Response response = await _client
          .get(
            Uri.parse(
              '$baseUrl/capture?t='
              '${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .timeout(
            const Duration(seconds: 2),
          );

      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty) {
        return;
      }

      await _frameFile!.writeAsBytes(
        response.bodyBytes,
        flush: true,
      );

      // ----------------------------------------------------------
      // 2. ML KIT FACE DETECTION
      // ----------------------------------------------------------

      final InputImage image =
          InputImage.fromFilePath(
        _frameFile!.path,
      );

      final List<Face> faces =
          await _detector.processImage(image);

      // ----------------------------------------------------------
      // NO FACE
      // ----------------------------------------------------------

      if (faces.isEmpty) {
        _metricsController.add(
          const FaceMetrics.noFace(),
        );

        _resetClosedState();

        return;
      }

      // ----------------------------------------------------------
      // 3. SELECT LARGEST FACE
      // ----------------------------------------------------------

      // If another passenger appears in the camera,
      // use the largest face.
      faces.sort(
        (Face first, Face second) {
          final double firstArea =
              first.boundingBox.width *
              first.boundingBox.height;

          final double secondArea =
              second.boundingBox.width *
              second.boundingBox.height;

          return secondArea.compareTo(firstArea);
        },
      );

      final Face face = faces.first;

      // ----------------------------------------------------------
      // 4. EYE ASPECT RATIO
      // ----------------------------------------------------------

      final double leftEar =
          _contourAspectRatio(
        face.contours[
                FaceContourType.leftEye]
            ?.points,
      );

      final double rightEar =
          _contourAspectRatio(
        face.contours[
                FaceContourType.rightEye]
            ?.points,
      );

      final double ear =
          _averageAvailable(
        leftEar,
        rightEar,
      );

      // ----------------------------------------------------------
      // 5. MOUTH ASPECT RATIO
      // ----------------------------------------------------------

      final double mar =
          _mouthAspectRatio(face);

      // ----------------------------------------------------------
      // 6. EYE OPEN PROBABILITY
      // ----------------------------------------------------------

      final double? eyeOpenProbability =
          _averageEyeOpenProbability(face);

      // ----------------------------------------------------------
      // 7. HEAD POSE
      // ----------------------------------------------------------

      final DateTime now =
          DateTime.now();

      final double yaw =
          face.headEulerAngleY ?? 0;

      final double pitch =
          face.headEulerAngleX ?? 0;

      final String headPosition =
          _calibratedHeadPosition(
        yaw: yaw,
        pitch: pitch,
      );

      // ----------------------------------------------------------
      // 8. NEW: REPEATED NODDING
      // ----------------------------------------------------------

      final bool repeatedNodding =
          _updateNodDetection(
        now: now,
        headPosition: headPosition,
      );

      // ----------------------------------------------------------
      // 9. EYE ANALYSIS
      // ----------------------------------------------------------

      // Eye probabilities become unreliable when
      // the face is not frontal.
      //
      // Therefore only analyse eye closure/PERCLOS
      // while the head is Stable.
      final bool headAllowsEyeAnalysis =
          headPosition == 'Stable';

      final bool eyesClosed =
          headAllowsEyeAnalysis &&
                  mar < _yawnMarThreshold
              ? _eyesAreClosed(
                  ear: ear,
                  eyeOpenProbability:
                      eyeOpenProbability,
                )
              : false;

      if (headAllowsEyeAnalysis) {
        _updateBlinkCounter(
          now: now,
          eyesClosed: eyesClosed,
        );

        _updateEyeSamples(
          now: now,
          eyesClosed: eyesClosed,
        );
      } else {
        _pauseEyeClosureState();
      }

      // ----------------------------------------------------------
      // 10. YAWN ANALYSIS
      // ----------------------------------------------------------

      _updateYawnState(
        now: now,
        mar: mar,
      );

      // ----------------------------------------------------------
      // 11. PERCLOS
      // ----------------------------------------------------------

      final double perclos =
          _calculatePerclos();

      // ----------------------------------------------------------
      // 12. HOW LONG EYES HAVE BEEN CLOSED
      // ----------------------------------------------------------

      final Duration eyeClosedFor =
          eyesClosed &&
                  _closedStartedAt != null
              ? now.difference(
                  _closedStartedAt!,
                )
              : Duration.zero;

      // ----------------------------------------------------------
      // 13. HOW LONG USER HAS BEEN YAWNING
      // ----------------------------------------------------------

      final Duration yawningFor =
          _yawnStartedAt == null
              ? Duration.zero
              : now.difference(
                  _yawnStartedAt!,
                );

      // ----------------------------------------------------------
      // 14. FATIGUE CONDITIONS
      // ----------------------------------------------------------

      final bool longEyeClosure =
          headAllowsEyeAnalysis &&
          eyeClosedFor >=
              _longClosureDuration;

      final bool sustainedYawn =
          yawningFor >=
              _yawnDuration;

      final bool highPerclos =
          headAllowsEyeAnalysis &&
          _eyeSamples.length >=
              _minimumPerclosSamples &&
          perclos >=
              _perclosAlertThreshold;

      // ----------------------------------------------------------
      // FATIGUE RESULT
      // ----------------------------------------------------------
      //
      // Fatigue can now be triggered by:
      //
      // 1. Long eye closure
      // 2. Prolonged yawning
      // 3. High PERCLOS
      // 4. NEW: Repeated head nodding
      //
      // ----------------------------------------------------------

      final bool fatigueDetected =
          longEyeClosure ||
          sustainedYawn ||
          highPerclos ||
          repeatedNodding;

      // ----------------------------------------------------------
      // 15. FATIGUE REASON
      // ----------------------------------------------------------

      String fatigueReason =
          'Normal';

      // Repeated nodding gets high priority because
      // it is a strong sign of drowsiness.
      if (repeatedNodding) {
        fatigueReason =
            'Repeated nodding detected';
      } else if (sustainedYawn) {
        fatigueReason =
            'Prolonged yawn detected';
      } else if (longEyeClosure) {
        fatigueReason =
            'Eyes closed too long';
      } else if (highPerclos) {
        fatigueReason =
            'Frequent eye closure';
      }

      // ----------------------------------------------------------
      // 16. FATIGUE RISK
      // ----------------------------------------------------------

      final double eyeRisk =
          eyesClosed
              ? (
                  eyeClosedFor
                          .inMilliseconds /
                      _longClosureDuration
                          .inMilliseconds
                ).clamp(
                  0.0,
                  1.0,
                )
              : 0.0;

      final double yawnRisk =
          mar >= _yawnMarThreshold
              ? (
                  yawningFor
                          .inMilliseconds /
                      _yawnDuration
                          .inMilliseconds
                ).clamp(
                  0.0,
                  1.0,
                )
              : 0.0;

      final double perclosRisk =
          headAllowsEyeAnalysis &&
                  _eyeSamples.length >=
                      _minimumPerclosSamples
              ? (
                  perclos /
                  _perclosAlertThreshold
                ).clamp(
                  0.0,
                  1.0,
                )
              : 0.0;

      // Repeated nodding immediately represents
      // maximum fatigue risk.
      final double nodRisk =
          repeatedNodding
              ? 1.0
              : 0.0;

      final double fatigueRisk =
          math.max(
        nodRisk,
        math.max(
          eyeRisk,
          math.max(
            yawnRisk,
            perclosRisk,
          ),
        ),
      );

      // ----------------------------------------------------------
      // 17. SEND METRICS TO DRIVING PAGE
      // ----------------------------------------------------------

      _metricsController.add(
        FaceMetrics(
          faceDetected: true,
          ear: ear,
          mar: mar,
          eyeOpenProbability:
              eyeOpenProbability ?? -1,
          blinkRate:
              _blinkTimes.length,
          perclos:
              perclos,
          fatigueDetected:
              fatigueDetected,
          fatigueReason:
              fatigueReason,
          alertness:
              (1.0 - fatigueRisk)
                  .clamp(
                    0.0,
                    1.0,
                  ),
          headPosition:
              headPosition,
          yaw:
              yaw,
          pitch:
              pitch,
        ),
      );
    } catch (_) {
      // A missed ESP32 frame should not stop
      // the next scheduled analysis.
    } finally {
      _processing = false;
    }
  }

  // ============================================================
  // EYE CONTOUR ASPECT RATIO
  // ============================================================

  double _contourAspectRatio(
    List<math.Point<int>>? points,
  ) {
    if (points == null ||
        points.length < 4) {
      return 0;
    }

    int minX = points.first.x;
    int maxX = points.first.x;

    int minY = points.first.y;
    int maxY = points.first.y;

    for (final math.Point<int> point
        in points.skip(1)) {
      minX =
          math.min(
        minX,
        point.x,
      );

      maxX =
          math.max(
        maxX,
        point.x,
      );

      minY =
          math.min(
        minY,
        point.y,
      );

      maxY =
          math.max(
        maxY,
        point.y,
      );
    }

    final double width =
        (maxX - minX).toDouble();

    if (width <= 0) {
      return 0;
    }

    return (maxY - minY) / width;
  }

  // ============================================================
  // MOUTH ASPECT RATIO
  // ============================================================

  double _mouthAspectRatio(
    Face face,
  ) {
    final List<math.Point<int>>
        points =
        <math.Point<int>>[];

    for (final FaceContourType type
        in <FaceContourType>[
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
    ]) {
      final List<math.Point<int>>?
          contour =
          face.contours[type]
              ?.points;

      if (contour != null) {
        points.addAll(contour);
      }
    }

    return _contourAspectRatio(
      points,
    );
  }

  // ============================================================
  // AVERAGE AVAILABLE VALUE
  // ============================================================

  double _averageAvailable(
    double first,
    double second,
  ) {
    if (first > 0 &&
        second > 0) {
      return (first + second) / 2;
    }

    return math.max(
      first,
      second,
    );
  }

  // ============================================================
  // EYE OPEN PROBABILITY
  // ============================================================

  double? _averageEyeOpenProbability(
    Face face,
  ) {
    final List<double>
        probabilities =
        <double>[
      if (face.leftEyeOpenProbability !=
          null)
        face.leftEyeOpenProbability!,
      if (face.rightEyeOpenProbability !=
          null)
        face.rightEyeOpenProbability!,
    ];

    if (probabilities.isEmpty) {
      return null;
    }

    return probabilities.reduce(
          (
            double a,
            double b,
          ) =>
              a + b,
        ) /
        probabilities.length;
  }

  // ============================================================
  // BLINK COUNTER
  // ============================================================

  void _updateBlinkCounter({
    required DateTime now,
    required bool eyesClosed,
  }) {
    // Only keep blinks from the latest minute.
    _blinkTimes.removeWhere(
      (DateTime blink) =>
          now.difference(blink) >
          const Duration(
            minutes: 1,
          ),
    );

    // Eyes just became closed.
    if (eyesClosed &&
        !_wasClosed) {
      _closedStartedAt =
          now;
    }

    // Eyes reopened.
    else if (!eyesClosed &&
        _wasClosed &&
        _closedStartedAt != null) {
      final Duration closedFor =
          now.difference(
        _closedStartedAt!,
      );

      // Normal blink duration.
      if (closedFor >=
              const Duration(
                milliseconds: 80,
              ) &&
          closedFor <=
              const Duration(
                milliseconds: 900,
              )) {
        _blinkTimes.add(
          now,
        );
      }

      _closedStartedAt =
          null;
    }

    _wasClosed =
        eyesClosed;
  }

  // ============================================================
  // EYE CLOSED DETECTION
  // ============================================================

  bool _eyesAreClosed({
    required double ear,
    required double?
        eyeOpenProbability,
  }) {
    // ML Kit eye-open probability is more stable
    // than contour EAR at the low dashboard camera angle.
    if (eyeOpenProbability != null) {
      if (_stableEyesClosed) {
        // Previously closed -> reopen only when
        // probability becomes clearly high.
        if (eyeOpenProbability >
            _reopenEyeProbabilityThreshold) {
          _stableEyesClosed =
              false;
        }
      } else if (eyeOpenProbability <
          _closeEyeProbabilityThreshold) {
        _stableEyesClosed =
            true;
      }

      return _stableEyesClosed;
    }

    // Fallback to EAR.
    _stableEyesClosed =
        ear > 0 &&
        ear <
            _closedEarThreshold;

    return _stableEyesClosed;
  }

  // ============================================================
  // PERCLOS SAMPLE UPDATE
  // ============================================================

  void _updateEyeSamples({
    required DateTime now,
    required bool eyesClosed,
  }) {
    _eyeSamples.add(
      _EyeSample(
        time: now,
        eyesClosed:
            eyesClosed,
      ),
    );

    _eyeSamples.removeWhere(
      (_EyeSample sample) =>
          now.difference(
            sample.time,
          ) >
          _perclosWindow,
    );
  }

  // ============================================================
  // PAUSE EYE ANALYSIS
  // ============================================================

  void _pauseEyeClosureState() {
    _wasClosed = false;
    _stableEyesClosed =
        false;
    _closedStartedAt =
        null;
  }

  // ============================================================
  // CALCULATE PERCLOS
  // ============================================================

  double _calculatePerclos() {
    if (_eyeSamples.isEmpty) {
      return 0;
    }

    final int closedSamples =
        _eyeSamples
            .where(
              (_EyeSample sample) =>
                  sample.eyesClosed,
            )
            .length;

    return closedSamples /
        _eyeSamples.length;
  }

  // ============================================================
  // YAWN STATE
  // ============================================================

  void _updateYawnState({
    required DateTime now,
    required double mar,
  }) {
    if (mar >=
        _yawnMarThreshold) {
      _yawnStartedAt ??=
          now;
    } else {
      _yawnStartedAt =
          null;
    }
  }

  // ============================================================
  // NEW: REPEATED NODDING DETECTION
  // ============================================================

  bool _updateNodDetection({
    required DateTime now,
    required String headPosition,
  }) {
    // ----------------------------------------------------------
    // Remove nods older than the 6-second detection window.
    // ----------------------------------------------------------

    _nodTimes.removeWhere(
      (DateTime nodTime) =>
          now.difference(
            nodTime,
          ) >
          _nodWindow,
    );

    // ----------------------------------------------------------
    // Ignore nod detection during head calibration.
    // ----------------------------------------------------------

    if (headPosition ==
        'Calibrating') {
      _headWasDown =
          false;

      _nodDownStartedAt =
          null;

      return false;
    }

    // ----------------------------------------------------------
    // STEP 1:
    //
    // Stable -> Down
    //
    // Start recording a possible nod.
    // ----------------------------------------------------------

    if (headPosition == 'Down' &&
        !_headWasDown) {
      _headWasDown =
          true;

      _nodDownStartedAt =
          now;
    }

    // ----------------------------------------------------------
    // STEP 2:
    //
    // Down -> Stable
    //
    // The driver has returned their head to the normal position.
    // This completes ONE nod.
    // ----------------------------------------------------------

    else if (headPosition ==
            'Stable' &&
        _headWasDown &&
        _nodDownStartedAt !=
            null) {
      final Duration nodDuration =
          now.difference(
        _nodDownStartedAt!,
      );

      // Only count realistic nod movements.
      //
      // Too fast:
      // probably ML Kit noise.
      //
      // Too slow:
      // probably the driver simply looked down.
      if (nodDuration >=
              _minimumNodDuration &&
          nodDuration <=
              _maximumNodDuration) {
        _nodTimes.add(
          now,
        );
      }

      // Reset current nod state.
      _headWasDown =
          false;

      _nodDownStartedAt =
          null;
    }

    // ----------------------------------------------------------
    // CANCEL INVALID NOD
    //
    // Example:
    //
    // Down -> Left
    // Down -> Right
    // Down -> Up
    //
    // This should NOT count as a complete nod.
    // ----------------------------------------------------------

    else if (_headWasDown &&
        headPosition !=
            'Down' &&
        headPosition !=
            'Stable') {
      _headWasDown =
          false;

      _nodDownStartedAt =
          null;
    }

    // ----------------------------------------------------------
    // FATIGUE CONDITION
    //
    // 3 complete nods within 6 seconds.
    // ----------------------------------------------------------

    return _nodTimes.length >=
        _nodAlertCount;
  }

  // ============================================================
  // HEAD POSITION / CALIBRATION
  // ============================================================

  String _calibratedHeadPosition({
    required double yaw,
    required double pitch,
  }) {
    // ----------------------------------------------------------
    // INITIAL CALIBRATION
    // ----------------------------------------------------------

    if (_baselineYaw == null ||
        _baselinePitch == null) {
      _calibrationYaws.add(
        yaw,
      );

      _calibrationPitches.add(
        pitch,
      );

      if (_calibrationYaws.length <
          _headCalibrationSamples) {
        return 'Calibrating';
      }

      // Average normal yaw.
      _baselineYaw =
          _calibrationYaws.reduce(
                (
                  double a,
                  double b,
                ) =>
                    a + b,
              ) /
              _calibrationYaws.length;

      // Average normal pitch.
      _baselinePitch =
          _calibrationPitches.reduce(
                (
                  double a,
                  double b,
                ) =>
                    a + b,
              ) /
              _calibrationPitches.length;

      return 'Stable';
    }

    // ----------------------------------------------------------
    // RELATIVE HEAD MOVEMENT
    // ----------------------------------------------------------

    final double relativeYaw =
        yaw -
        _baselineYaw!;

    final double relativePitch =
        pitch -
        _baselinePitch!;

    // ----------------------------------------------------------
    // LEFT / RIGHT
    // ----------------------------------------------------------

    if (relativeYaw <=
        -_relativeYawThreshold) {
      return 'Left';
    }

    if (relativeYaw >=
        _relativeYawThreshold) {
      return 'Right';
    }

    // ----------------------------------------------------------
    // DOWN / UP
    // ----------------------------------------------------------

    if (relativePitch <=
        -_relativePitchThreshold) {
      return 'Down';
    }

    if (relativePitch >=
        _relativePitchThreshold) {
      return 'Up';
    }

    return 'Stable';
  }

  // ============================================================
  // RESET SESSION
  // ============================================================

  void _resetSessionState() {
    _resetClosedState();

    _blinkTimes.clear();

    _calibrationYaws.clear();

    _calibrationPitches.clear();

    _baselineYaw =
        null;

    _baselinePitch =
        null;

    // Reset nodding detection.
    _headWasDown =
        false;

    _nodDownStartedAt =
        null;

    _nodTimes.clear();
  }

  // ============================================================
  // RESET EYE / YAWN STATE
  // ============================================================

  void _resetClosedState() {
    _wasClosed =
        false;

    _stableEyesClosed =
        false;

    _closedStartedAt =
        null;

    _yawnStartedAt =
        null;

    _eyeSamples.clear();
  }

  // ============================================================
  // STOP
  // ============================================================

  void stop() {
    _timer?.cancel();
    _timer =
        null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    stop();

    _client.close();

    await _detector.close();

    await _metricsController.close();
  }
}

// ============================================================
// EYE SAMPLE MODEL
// ============================================================

class _EyeSample {
  const _EyeSample({
    required this.time,
    required this.eyesClosed,
  });

  final DateTime time;

  final bool eyesClosed;
}