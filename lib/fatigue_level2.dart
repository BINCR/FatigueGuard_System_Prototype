import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Import voice broadcast plugin

class FatigueLevel2Page extends StatefulWidget {
  const FatigueLevel2Page({super.key});

  @override
  State<FatigueLevel2Page> createState() => _FatigueLevel2PageState();
}

class _FatigueLevel2PageState extends State<FatigueLevel2Page> {
  final MapController _mapController = MapController();
  final LatLng _rrLocation = const LatLng(
    2.3020,
    103.3245,
  ); // Simulated nearest rest area coordinates
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _playCriticalVoiceWarning();
  }

  Future<void> _playCriticalVoiceWarning() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Moderate and clear speech rate
    await _flutterTts.setPitch(1.0);
    // Trigger critical voice warning
    await _flutterTts.speak(
      "Severe fatigue detected. Pull over immediately. Navigating now!",
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color dangerRed = Color(0xFFDC2626);
    const Color dangerSurface = Color(0xFFFEE2E2);
    const Color onSurfaceVariant = Color(0xFF464555);

    return Theme(
      data: ThemeData.light(), // Force light theme, reject dark inversion
      child: Scaffold(
        backgroundColor: dangerSurface,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Top emergency warning bar
                  Container(
                    height: 64,
                    color: dangerRed,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'SEVERE FATIGUE DETECTED',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.warning, color: Colors.white),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            // Header warning icon and title
                            Column(
                              children: [
                                Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    color: dangerRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🛑',
                                      style: TextStyle(fontSize: 64),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'CRITICAL WARNING!',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: dangerRed,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: const Text(
                                    'EAR < 0.18 (Microsleep Risk)',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 👇 Replace original static image with real Leaflet dynamic map
                            Container(
                              height: 192,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: dangerRed, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: _rrLocation,
                                        initialZoom: 14.0,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName:
                                              'com.example.fatigue_guard',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: _rrLocation,
                                              width: 32,
                                              height: 32,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: dangerRed,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.local_gas_station,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: dangerRed),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.near_me,
                                              color: dangerRed,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Recalculating to R&R...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Emergency prompt information card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: dangerRed,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: dangerRed.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.campaign,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'ALARM ACTIVE',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'PULL OVER IMMEDIATELY! NAVIGATING NOW.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Navigation button
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _flutterTts.speak(
                                    "Starting navigation to the nearest rest area.",
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Starting navigation to R&R...',
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: dangerRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.directions_car),
                                label: const Text(
                                  'NAVIGATE TO NEAREST R&R NOW',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Emergency SOS button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _flutterTts.speak(
                                    "Calling emergency contacts and services.",
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: dangerRed,
                                  side: const BorderSide(
                                    color: dangerRed,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.sos),
                                label: const Text(
                                  'EMERGENCY SOS / CALL HELP',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Dismiss/Close button
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'DISMISS (STAY ALERT)',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  color: onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Edge red warning border
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: dangerRed.withValues(alpha: 0.3),
                    width: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
