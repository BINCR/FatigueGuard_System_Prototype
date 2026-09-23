import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'collision_detect.dart';
import 'distraction_alert.dart';
import 'driver_analytics.dart';
import 'driver_home.dart';
import 'driver_profile.dart';
import 'fatigue_level1.dart';
import 'fatigue_level2.dart';
import 'fatigue_level3.dart';
import 'models/voice_intent.dart';
import 'profile_data.dart';
import 'services/esp32_service.dart';
import 'services/face_analysis_service.dart';
import 'services/storage_service.dart';
import 'services/voice_command_service.dart';

class DrivingIngPage extends StatefulWidget {
  const DrivingIngPage({super.key});

  @override
  State<DrivingIngPage> createState() => _DrivingIngPageState();
}

class _DrivingIngPageState extends State<DrivingIngPage>
    with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _timer;
  bool _isPaused = false;

  final Esp32Service _esp32Service = Esp32Service();
  final FaceAnalysisService _faceAnalysisService = FaceAnalysisService();
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  final FlutterTts _voiceFeedback = FlutterTts();

  StreamSubscription<DetectionResult>? _detectionSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<FaceMetrics>? _faceMetricsSubscription;
  StreamSubscription<VoiceCommand>? _voiceCommandSubscription;
  StreamSubscription<bool>? _voiceListeningSubscription;

  bool _voiceListening = false;
  bool _voiceFeedbackEnabled = true;

  String _currentLabel = 'waiting';
  double _currentConfidence = 0.0;
  bool _esp32Connected = false;
  bool _faceDetected = false;
  double _ear = 0;
  double _mar = 0;
  double _eyeOpenProbability = -1;
  double _perclos = 0;
  double _faceAlertness = 0;
  bool _faceFatigueDetected = false;
  String _fatigueReason = 'Waiting for face data';
  String _headPosition = 'Waiting';

  bool _alertPageOpen = false;
  int _fatigueAlertLevel = 0;
  DateTime? _lastAlertClosedAt;
  Timer? _testNotificationTimer;
  String? _testNotification;
  Color _testNotificationColor = Colors.orange;
  int _testEventCount = 0;
  bool _fatigueEpisodeActive = false;
  bool _distractedEpisodeActive = false;

  // Testing build: detections stay on this page and never open warning pages.
  static const bool _testingMode = true;

  // Real ESP32 is the default. The user can switch to Demo from the app bar.
  bool _useMockData = false;

  int _consecutiveDistractedDetections = 0;

  // Distracted detection was much more stable, so keep its stricter rule.
  static const double _distractedAlertConfidence = 0.80;
  static const int _requiredConsecutiveDistractedDetections = 3;
  static const Duration _alertCooldown = Duration(seconds: 8);

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color onPrimaryContainer = Color(0xFFDAD7FF);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color secondaryColor = Color(0xFF515F74);
  static const Color surfaceColor = Color(0xFFF9F9FF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);
  static const Color outlineVariant = Color(0xFFC7C4D8);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  void initState() {
    super.initState();

    profileData.addListener(_onProfileChanged);
    unawaited(StorageService.instance.startDrivingSession());
    _startTimer();

    _detectionSubscription = _esp32Service.results.listen((result) {
      if (!mounted) return;

      setState(() {
        _currentLabel = result.label;
        _currentConfidence = result.confidence;
      });

      unawaited(_handleDetectionResult(result));
    });

    _connectionSubscription = _esp32Service.connectionStatus.listen((
      connected,
    ) {
      if (!mounted) return;

      setState(() {
        _esp32Connected = connected;
      });
    });

    _faceMetricsSubscription = _faceAnalysisService.metrics.listen((metrics) {
      if (!mounted) return;

      setState(() {
        _faceDetected = metrics.faceDetected;
        _ear = metrics.ear;
        _mar = metrics.mar;
        _eyeOpenProbability = metrics.eyeOpenProbability;
        _perclos = metrics.perclos;
        _faceAlertness = metrics.alertness;
        _faceFatigueDetected = metrics.fatigueDetected;
        _fatigueReason = metrics.fatigueReason;
        _headPosition = metrics.headPosition;
      });

      unawaited(_handleFaceMetrics(metrics));
    });

    _esp32Service.start(mockMode: _useMockData);
    unawaited(_faceAnalysisService.start());

    _voiceCommandSubscription = _voiceCommandService.commands.listen((
      VoiceCommand command,
    ) {
      unawaited(_handleVoiceCommand(command));
    });

    _voiceListeningSubscription = _voiceCommandService.listeningStatus.listen((
      bool listening,
    ) {
      if (!mounted) return;

      setState(() {
        _voiceListening = listening;
      });
    });

    unawaited(_startVoiceControl());
  }

  Future<void> _startVoiceControl() async {
    await _voiceFeedback.setLanguage('en-US');
    await _voiceFeedback.setSpeechRate(0.5);
    await _voiceFeedback.setPitch(1.0);
    await _voiceFeedback.awaitSpeakCompletion(true);

    final bool started = await _voiceCommandService.start();

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice control unavailable. Please allow microphone permission.',
          ),
        ),
      );
    }
  }

  Future<void> _handleVoiceCommand(VoiceCommand command) async {
    switch (command.intent) {
      case VoiceIntent.startMonitoring:
        if (_isPaused && mounted) {
          setState(() {
            _isPaused = false;
          });
        }
        await _speakVoiceResponse('Monitoring started.');
        break;
      case VoiceIntent.stopMonitoring:
        if (!_isPaused && mounted) {
          setState(() {
            _isPaused = true;
          });
        }
        await _speakVoiceResponse('Monitoring paused.');
        break;
      case VoiceIntent.dismissWarning:
        await _dismissWarningByVoice();
        break;
      case VoiceIntent.checkStatus:
        await _speakCurrentStatus();
        break;
      case VoiceIntent.openMonitoring:
        await _speakVoiceResponse('Monitoring page is already open.');
        break;
      case VoiceIntent.openAnalytics:
        await _speakVoiceResponse('Opening analytics.');
        if (!mounted) return;
        await _endSessionAndOpen(const DriverAnalyticsPage());
        break;
      case VoiceIntent.openProfile:
        await _speakVoiceResponse('Opening profile.');
        if (!mounted) return;
        await _endSessionAndOpen(const DriverProfilePage());
        break;
      case VoiceIntent.mute:
        _voiceFeedbackEnabled = false;
        await _voiceFeedback.stop();
        break;
      case VoiceIntent.enableSound:
        _voiceFeedbackEnabled = true;
        await _speakVoiceResponse('Voice feedback enabled.');
        break;
      case VoiceIntent.unknown:
        await _speakVoiceResponse('Command not recognised.');
        break;
      case VoiceIntent.none:
        break;
    }
  }

  Future<void> _dismissWarningByVoice() async {
    bool warningDismissed = false;

    if (_testNotification != null && mounted) {
      _testNotificationTimer?.cancel();
      setState(() {
        _testNotification = null;
      });
      warningDismissed = true;
    }

    if (_alertPageOpen && mounted) {
      await Navigator.of(context).maybePop();
      warningDismissed = true;
    }

    await _speakVoiceResponse(
      warningDismissed ? 'Warning dismissed.' : 'There is no active warning.',
    );
  }

  Future<void> _speakCurrentStatus() async {
    if (!_esp32Connected) {
      await _speakVoiceResponse('ESP32 camera is not connected.');
      return;
    }

    if (!_faceDetected) {
      await _speakVoiceResponse('No face is currently detected.');
      return;
    }

    final int alertness = (_alertnessScore * 100).round();

    if (_faceFatigueDetected) {
      await _speakVoiceResponse(
        'Fatigue detected. $_fatigueReason. '
        'Alertness is $alertness percent.',
      );
      return;
    }

    await _speakVoiceResponse(
      'Driver status is normal. Alertness is $alertness percent.',
    );
  }

  Future<void> _speakVoiceResponse(String message) async {
    if (!_voiceFeedbackEnabled) return;

    await _voiceCommandService.stop();
    await _voiceFeedback.stop();
    await _voiceFeedback.speak(message);

    if (mounted) {
      await _voiceCommandService.start();
    }
  }

  @override
  void dispose() {
    profileData.removeListener(_onProfileChanged);
    _timer?.cancel();
    _testNotificationTimer?.cancel();
    _detectionSubscription?.cancel();
    _connectionSubscription?.cancel();
    _faceMetricsSubscription?.cancel();
    _voiceCommandSubscription?.cancel();
    _voiceListeningSubscription?.cancel();
    _esp32Service.dispose();
    unawaited(_faceAnalysisService.dispose());
    unawaited(_voiceCommandService.dispose());
    unawaited(_voiceFeedback.stop());
    unawaited(StorageService.instance.endDrivingSession());

    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPaused ? 'Session paused' : 'Session resumed'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _setDetectionMode(bool useMockData) {
    if (_useMockData == useMockData) return;

    setState(() {
      _useMockData = useMockData;
      _esp32Connected = false;
      _currentLabel = 'waiting';
      _currentConfidence = 0.0;
      _consecutiveDistractedDetections = 0;
    });

    _esp32Service.start(mockMode: _useMockData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useMockData
              ? 'Demo mode enabled'
              : 'Real ESP32 mode enabled. Connect to FatigueGuard-ESP32 Wi-Fi.',
        ),
      ),
    );
  }

  double get _alertnessScore {
    if (_faceDetected) {
      return _faceAlertness;
    }

    switch (_currentLabel) {
      case 'normal':
        return _currentConfidence.clamp(0.0, 1.0).toDouble();
      case 'drowsy':
      case 'distracted':
        return (1.0 - _currentConfidence).clamp(0.0, 1.0).toDouble();
      default:
        return 0.0;
    }
  }

  Future<void> _handleFaceMetrics(FaceMetrics metrics) async {
    if (!metrics.fatigueDetected) {
      _fatigueEpisodeActive = false;
      return;
    }

    if (!mounted || _isPaused || _alertPageOpen || _fatigueEpisodeActive) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastAlertClosedAt != null &&
        now.difference(_lastAlertClosedAt!) < _alertCooldown) {
      return;
    }

    _fatigueEpisodeActive = true;
    _fatigueAlertLevel = (_fatigueAlertLevel % 3) + 1;

    if (_testingMode) {
      _lastAlertClosedAt = now;
      await StorageService.instance.saveDetectionEvent(
        label: 'drowsy',
        confidence: (1.0 - metrics.alertness).clamp(0.0, 1.0),
        alertLevel: _fatigueAlertLevel,
      );

      if (mounted) {
        final bool isYawn = metrics.fatigueReason.toLowerCase().contains(
          'yawn',
        );
        _showTestNotification(
          isYawn
              ? 'YAWNING DETECTED: ${metrics.fatigueReason}'
              : 'FATIGUE DETECTED: ${metrics.fatigueReason}',
          errorColor,
        );
      }
      return;
    }

    final Widget alertPage = switch (_fatigueAlertLevel) {
      1 => const FatigueLevel1Page(),
      2 => const FatigueLevel2Page(),
      _ => const FatigueLevel3Page(),
    };

    _alertPageOpen = true;
    await StorageService.instance.saveDetectionEvent(
      label: 'drowsy',
      confidence: (1.0 - metrics.alertness).clamp(0.0, 1.0),
      alertLevel: _fatigueAlertLevel,
    );

    if (!mounted) return;

    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => alertPage));
    } finally {
      if (mounted) {
        _alertPageOpen = false;
        _lastAlertClosedAt = DateTime.now();
      }
    }
  }

  Future<void> _handleDetectionResult(DetectionResult result) async {
    if (result.label != 'distracted') {
      _distractedEpisodeActive = false;
    }

    if (!mounted || _isPaused || _alertPageOpen) {
      return;
    }

    final DateTime now = DateTime.now();

    if (_lastAlertClosedAt != null &&
        now.difference(_lastAlertClosedAt!) < _alertCooldown) {
      return;
    }

    if (result.label == 'distracted' &&
        result.confidence >= _distractedAlertConfidence) {
      _consecutiveDistractedDetections++;
    } else {
      _consecutiveDistractedDetections = 0;
    }

    final bool shouldAlertDistracted =
        _consecutiveDistractedDetections >=
        _requiredConsecutiveDistractedDetections;

    if (!shouldAlertDistracted) {
      return;
    }

    if (_distractedEpisodeActive) {
      return;
    }

    _distractedEpisodeActive = true;

    const String alertLabel = 'distracted';

    _consecutiveDistractedDetections = 0;

    if (_testingMode) {
      _lastAlertClosedAt = now;
      await StorageService.instance.saveDetectionEvent(
        label: alertLabel,
        confidence: result.confidence,
        alertLevel: 1,
      );

      if (mounted) {
        _showTestNotification(
          'DISTRACTION DETECTED: ${(result.confidence * 100).round()}%',
          Colors.deepOrange,
        );
      }
      return;
    }

    Widget? alertPage;

    switch (alertLabel) {
      case 'drowsy':
        _fatigueAlertLevel = (_fatigueAlertLevel % 3) + 1;

        switch (_fatigueAlertLevel) {
          case 1:
            alertPage = const FatigueLevel1Page();
            break;

          case 2:
            alertPage = const FatigueLevel2Page();
            break;

          case 3:
            alertPage = const FatigueLevel3Page();
            break;

          default:
            return;
        }

        break;

      case 'distracted':
        alertPage = const DistractionAlertPage();
        break;

      case 'normal':
      case 'uncertain':
      default:
        return;
    }

    _alertPageOpen = true;

    await StorageService.instance.saveDetectionEvent(
      label: alertLabel,
      confidence: result.confidence,
      alertLevel: alertLabel == 'distracted' ? 1 : _fatigueAlertLevel,
    );

    if (!mounted) {
      return;
    }

    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => alertPage!));
    } finally {
      if (mounted) {
        _alertPageOpen = false;
        _lastAlertClosedAt = DateTime.now();
      }
    }
  }

  void _showTestNotification(String message, Color color) {
    _testNotificationTimer?.cancel();

    setState(() {
      _testEventCount++;
      _testNotification = message;
      _testNotificationColor = color;
    });

    _testNotificationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _testNotification = null;
      });
    });
  }

  Future<void> _endSessionAndOpen(Widget page) async {
    await StorageService.instance.endDrivingSession();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _showDrivingDemoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Driving Alert Demo Mode'),
          content: const Text(
            'Select an alert level to showcase to your lecturer:',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FatigueLevel1Page(),
                  ),
                );
              },
              child: const Text(
                '1. Level 1 (Mild Fatigue)',
                style: TextStyle(color: Colors.amber),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FatigueLevel2Page(),
                  ),
                );
              },
              child: const Text(
                '2. Level 2 (Critical Warning)',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FatigueLevel3Page(),
                  ),
                );
              },
              child: const Text(
                '3. Level 3 (R&R Navigation)',
                style: TextStyle(color: Colors.indigo),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CollisionDetectPage(),
                  ),
                );
              },
              child: const Text(
                '4. Collision Detected (SOS)',
                style: TextStyle(
                  color: errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DistractionAlertPage(),
                  ),
                );
              },
              child: const Text(
                '5. Distraction Alert (Phone/Head)',
                style: TextStyle(
                  color: Color(0xFFD96B43),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          'FatigueGuard',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
        actions: [
          Icon(
            _voiceListening ? Icons.mic : Icons.mic_off,
            color: _voiceListening ? Colors.green : onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 6),
          PopupMenuButton<bool>(
            tooltip: 'Detection mode',
            icon: Icon(
              _useMockData ? Icons.science_outlined : Icons.wifi_tethering,
              color: _useMockData ? Colors.amber : primaryColor,
            ),
            onSelected: _setDetectionMode,
            itemBuilder: (context) => const [
              PopupMenuItem<bool>(
                value: false,
                child: ListTile(
                  leading: Icon(Icons.wifi_tethering),
                  title: Text('Real ESP32'),
                  subtitle: Text('192.168.4.1'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<bool>(
                value: true,
                child: ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('Demo mode'),
                  subtitle: Text('Simulated results'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.amber, size: 26),
            tooltip: 'Demo Alert Triggers',
            onPressed: () => _showDrivingDemoDialog(context),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surfaceContainerHigh,
                border: Border.all(
                  color: outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ClipOval(
                child: profileData.avatarFile != null
                    ? Image.file(
                        File(profileData.avatarFile!.path),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                      )
                    : const Icon(Icons.person, color: secondaryColor, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.science, color: primaryColor),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'TESTING MODE · Warning pages disabled',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Text(
                        'Events $_testEventCount',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _testNotification == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey<String>(_testNotification!),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _testNotificationColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _testNotificationColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: _testNotificationColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _testNotification!,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.bold,
                                    color: _testNotificationColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (_testNotification != null) const SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: !_esp32Connected
                                    ? Colors.grey
                                    : (_isPaused ? Colors.amber : Colors.green),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPaused
                                  ? 'SESSION PAUSED'
                                  : _esp32Connected
                                  ? '${_useMockData ? 'DEMO' : 'ESP32'}: '
                                        '${_currentLabel.toUpperCase()} '
                                        '${(_currentConfidence * 100).toStringAsFixed(0)}%'
                                  : 'ESP32 DISCONNECTED',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(_seconds),
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(220, 220),
                          painter: _AlertnessRingPainter(
                            progress: _alertnessScore,
                          ),
                        ),
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            color: surfaceContainerLowest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: outlineVariant.withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.visibility,
                                  color: onPrimaryContainer,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(_alertnessScore * 100).round()}%',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'ALERTNESS',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: secondaryColor,
                                  size: 20,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'PERCLOS (30 SEC)',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                text: _faceDetected
                                    ? '${(_perclos * 100).round()}'
                                    : '--',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                                children: const [
                                  TextSpan(
                                    text: '%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                      color: onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(
                                  Icons.height,
                                  color: secondaryColor,
                                  size: 20,
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'HEAD POS',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _headPosition,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LIVE FACE METRICS',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                text: _faceDetected
                                    ? 'EAR ${_ear.toStringAsFixed(3)}'
                                    : 'No face detected',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: _faceDetected
                                        ? '   MAR ${_mar.toStringAsFixed(3)}'
                                        : '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                      color: onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_faceDetected) ...[
                              const SizedBox(height: 3),
                              Text(
                                _eyeOpenProbability >= 0
                                    ? 'EYE OPEN ${_eyeOpenProbability.toStringAsFixed(3)}'
                                    : 'EYE OPEN unavailable',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 8,
                        decoration: BoxDecoration(
                          color: outlineVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: _faceDetected ? 80 : 0,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !_faceDetected
                        ? const Color(0xFFFFF8E1)
                        : _faceFatigueDetected
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !_faceDetected
                          ? const Color(0xFFFFD54F)
                          : _faceFatigueDetected
                          ? const Color(0xFFEF9A9A)
                          : const Color(0xFFA5D6A7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !_faceDetected
                            ? Icons.face_retouching_off
                            : _faceFatigueDetected
                            ? Icons.warning_rounded
                            : Icons.check_circle,
                        color: !_faceDetected
                            ? const Color(0xFFF9A825)
                            : _faceFatigueDetected
                            ? errorColor
                            : const Color(0xFF4CAF50),
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !_faceDetected
                                  ? 'No face detected.'
                                  : _faceFatigueDetected
                                  ? _fatigueReason.toLowerCase().contains(
                                          'yawn',
                                        )
                                        ? 'Yawning detected!'
                                        : 'Fatigue warning!'
                                  : 'No fatigue detected.',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _faceFatigueDetected
                                    ? errorColor
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !_faceDetected
                                  ? 'Please keep your face visible to the camera.'
                                  : _faceFatigueDetected
                                  ? _fatigueReason
                                  : 'EAR/MAR monitoring is active.',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13,
                                color: _faceFatigueDetected
                                    ? errorColor
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _togglePause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceContainerHigh,
                    foregroundColor: onSurfaceVariant,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPaused ? Icons.play_circle : Icons.pause_circle,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPaused ? 'RESUME SESSION' : 'PAUSE SESSION',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _endSessionAndOpen(const DriverHomePage()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'END SESSION',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: primaryContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility, color: onPrimaryContainer, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Monitoring',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _endSessionAndOpen(const DriverAnalyticsPage()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.leaderboard, color: onSurfaceVariant, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Analytics',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _endSessionAndOpen(const DriverProfilePage()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person, color: onSurfaceVariant, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertnessRingPainter extends CustomPainter {
  _AlertnessRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double radius = (size.width - 16) / 2;

    final Paint trackPaint = Paint()
      ..color = const Color(0xFFDEE8FF)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    final Paint progressPaint = Paint()
      ..color = const Color(0xFF3525CD)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AlertnessRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
