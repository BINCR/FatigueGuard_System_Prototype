import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CollisionDetectPage extends StatefulWidget {
  const CollisionDetectPage({super.key});

  @override
  State<CollisionDetectPage> createState() => _CollisionDetectPageState();
}

class _CollisionDetectPageState extends State<CollisionDetectPage> {
  final FlutterTts _flutterTts = FlutterTts();
  int _countdown = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _playVoiceWarning();
    _startCountdown();
  }

  Future<void> _playVoiceWarning() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); //Voice speech rate set to 0.5
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak("Collision detected! Emergency SOS initiated.");
  }

  // Start dynamic countdown
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        _triggerEmergencyCall();
      }
    });
  }

  void _triggerEmergencyCall() {
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.speak("Calling emergency services now.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-dialing emergency services (999)...')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color errorColor = Color(0xFFBA1A1A);
    const Color errorContainer = Color(0xFFFFDAD6);
    const Color onSurface = Color(0xFF111c2d);
    const Color onSurfaceVariant = Color(0xFF464555);
    const Color surfaceContainer = Color(0xFFE7EEFF);
    const Color surfaceContainerHighest = Color(0xFFDEE8FF);
    const Color outlineVariant = Color(0xFFC7C4D8);

    double progressValue = _countdown / 10.0;

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Emergency Alert Bar with red styling
              Container(
                height: 80,
                width: double.infinity,
                color: errorColor,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.car_crash, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'COLLISION DETECTED!',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        // SOS Title
                        const Text(
                          'SOS',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: errorColor,
                            height: 1.0,
                            letterSpacing: -2.0,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Countdown Timer Visual
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 160,
                              height: 160,
                              child: CircularProgressIndicator(
                                value: progressValue,
                                strokeWidth: 10,
                                backgroundColor: errorContainer,
                                valueColor: const AlwaysStoppedAnimation<Color>(errorColor),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_countdown}s',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Auto Responding',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: onSurfaceVariant,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Emergency Data Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              left: BorderSide(color: errorColor, width: 6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EMERGENCY BROADCAST DATA:',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: errorColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildEmergencyItem(
                                icon: Icons.call,
                                title: 'Auto-Dial: 999 Service',
                                subtitle: 'Connecting to dispatchers in ${_countdown}s',
                              ),
                              const SizedBox(height: 12),
                              _buildEmergencyItem(
                                icon: Icons.sms,
                                title: 'Auto-SMS: Emergency Contacts',
                                subtitle: 'Sending alert to 3 contacts',
                              ),
                              const SizedBox(height: 12),
                              _buildEmergencyItem(
                                icon: Icons.location_on,
                                title: 'Location: Real-Time GPS',
                                subtitle: 'Current: 1.4927° N, 103.7414° E',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 72,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _timer?.cancel();
                              _flutterTts.setSpeechRate(0.5);
                              _flutterTts.speak("Calling emergency services.");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Calling emergency services (999)...')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: errorColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            icon: const Icon(Icons.emergency, size: 28),
                            label: const Text(
                              'CALL 999 IMMEDIATELY NOW',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              _timer?.cancel();
                              _flutterTts.setSpeechRate(0.5);
                              _flutterTts.speak("SOS cancelled.");
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: surfaceContainerHighest,
                              foregroundColor: onSurfaceVariant,
                              side: BorderSide(color: outlineVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "CANCEL ALARM (I'M SAFE)",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer Security Brand
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.security, size: 14, color: onSurfaceVariant),
                    SizedBox(width: 6),
                    Text(
                      'FATIGUEGUARD ACTIVE PROTECTION SYSTEM',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildEmergencyItem({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFBA1A1A), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111c2d),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: Color(0xFF464555),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}