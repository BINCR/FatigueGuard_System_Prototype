import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart'; // 1. Import voice plugin

class FatigueLevel1Page extends StatefulWidget {
  const FatigueLevel1Page({super.key});

  @override
  State<FatigueLevel1Page> createState() => _FatigueLevel1PageState();
}

class _FatigueLevel1PageState extends State<FatigueLevel1Page> {
  // 2. Initialize TTS instance
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTtsAndPlay();
  }

  // 3. Configure voice parameters and start broadcasting
  Future<void> _initTtsAndPlay() async {
    // Set language (can be set to Chinese "zh-CN" or English "en-US" as needed)
    await _flutterTts.setLanguage("en-US");

    // Set speech rate (between 0.0 and 1.0, 0.9 is slightly steady and clear)
    await _flutterTts.setSpeechRate(0.5);

    // Set pitch
    await _flutterTts.setPitch(1.0);

    // Trigger voice broadcast
    await _flutterTts.speak(
      "Please consider stopping at a rest area soon to maintain safety standards.",
    );
  }

  @override
  void dispose() {
    // 4. Stop voice and release resources when page is disposed
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(
          0xFFFFFBEB,
        ), // Light yellow bright background
        body: SafeArea(
          child: Column(
            children: [
              // Top alert bar
              Container(
                width: double.infinity,
                color: const Color(0xFFFBBF24),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning, color: Color(0xFF1E1B4B), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'LEVEL 1 DROWSINESS DETECTED',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 192,
                              height: 192,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE685),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '🥱',
                                  style: TextStyle(fontSize: 84),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'MILD FATIGUE DETECTED!',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111c2d),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: const Text(
                                'EAR < 0.25 (Frequent Blink)',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF464555),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Voice reminder card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.volume_up,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VOICE REMINDER (ACTIVE)',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '"Please consider stopping at a rest area soon to maintain safety standards."',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 16,
                                        color: Color(0xFF111c2d),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Find R&R button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _flutterTts.speak(
                                "Opening nearest rest and recreation map.",
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Opening nearest R&R map...'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.local_gas_station),
                            label: const Text(
                              'FIND NEAREST R&R / PETROL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF464555),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom fatigue progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: 0.25,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: const Color(0xFFF59E0B),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'FATIGUE LEVEL',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: Color(0xFF464555),
                            ),
                          ),
                          Text(
                            '25% (MILD)',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
