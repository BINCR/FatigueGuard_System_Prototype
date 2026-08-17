import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DistractionAlertPage extends StatefulWidget {
  const DistractionAlertPage({super.key});

  @override
  State<DistractionAlertPage> createState() => _DistractionAlertPageState();
}

class _DistractionAlertPageState extends State<DistractionAlertPage> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _playVoiceWarning();
  }

  Future<void> _playVoiceWarning() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak("Please focus on the road ahead.");
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF7F5F0);
    const Color primaryOrange = Color(0xFFD96B43);
    const Color darkText = Color(0xFF2D2A26);
    const Color labelText = Color(0xFF7D756D);
    const Color containerBg = Color(0xFFEFECE6);
    const Color outlineColor = Color(0xFFE6DCD1);

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Full Width Alert Banner at Top
              Container(
                width: double.infinity,
                color: primaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.visibility_off, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'DISTRACTION DETECTED',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // App Main Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute vertical space evenly to fill the middle
                    children: [
                      // 2. Centre Content Area (Icon, big title, expanded Reason box)
                      Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBE3),
                              shape: BoxShape.circle,
                              border: Border.all(color: outlineColor, width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.phonelink_off, color: Color(0xFFC2562E), size: 38),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'EYES ON THE ROAD!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Color(0xFF22201D),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Reason box with increased font size and padding
                          Column(
                            children: [
                              _buildReasonLine('Reason: Head Pose > 20° (Phone Usage Detected)', primaryOrange, containerBg),
                              const SizedBox(height: 10),
                              _buildReasonLine('Reason: Head Pose > 20° (Looking Away From Road)', primaryOrange, containerBg),
                            ],
                          ),
                        ],
                      ),

                      // Bottom Group (Expanded Voice Alert box, detection details row, big buttons)
                      Column(
                        children: [
                          // 3. Info Box (Voice Alert expanded and enriched)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: containerBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: outlineColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.volume_up, color: Color(0xFFC2562E), size: 24),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'VOICE ALERT ACTIVE:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: labelText,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Please focus on the road ahead',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: darkText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Detection Info Row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: containerBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: outlineColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'HEAD DEVIATION',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: labelText,
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8ECE7),
                                    borderRadius: BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Text(
                                      '> 20° for 2s',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFC2562E),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 5. Two Buttons at Bottom
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                _flutterTts.speak("Focus restored.");
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryOrange,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "I'M FOCUSED NOW",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                _flutterTts.speak("Locating nearest rest area.");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Finding nearest R&R...')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAE6DF),
                                foregroundColor: const Color(0xFF4A443E),
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFFD6CEBE)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Find Nearest R&R',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

  // Adjusted Reason box font size and padding to make it more prominent and full
  Widget _buildReasonLine(String text, Color borderColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF4A423B),
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}