import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';

class FatigueLevel3Page extends StatefulWidget {
  const FatigueLevel3Page({super.key});

  @override
  State<FatigueLevel3Page> createState() => _FatigueLevel3PageState();
}

class _FatigueLevel3PageState extends State<FatigueLevel3Page> {
  final MapController _mapController = MapController();
  final LatLng _rrLocation = const LatLng(2.3020, 103.3245);
  
  final FlutterTts _flutterTts = FlutterTts();
  int _countdown = 7;
  Timer? _timer;
  bool _isSosTriggered = false;

  @override
  void initState() {
    super.initState();
    _playVoiceWarning();
    _startCountdown();
  }

  Future<void> _playVoiceWarning() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // 👈 Speech rate 0.5
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak("Severe fatigue detected. Navigating to nearest rest area automatically.");
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        _triggerAutoSos(); // 👈 Countdown ended, trigger Auto-SOS
      }
    });
  }

  // Auto-SOS action triggered when countdown ends
  void _triggerAutoSos() {
    if (!mounted) return;
    setState(() {
      _isSosTriggered = true;
    });
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.speak("Auto SOS initiated. Notifying emergency services and contacts.");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 AUTO-SOS TRIGGERED: Emergency services & contacts notified!'),
        backgroundColor: Color(0xFFBA1A1A),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFBA1A1A);
    const Color errorContainer = Color(0xFFFFDAD6);
    const Color onSurface = Color(0xFF111c2d);
    const Color onSurfaceVariant = Color(0xFF464555);

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFf9f9ff),
        body: SafeArea(
          child: Column(
            children: [
              // Top red alert bar (with countdown, displays AUTO-SOS ACTIVATED when finished)
              Container(
                height: 64,
                color: primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.emergency, color: Colors.white),
                    Text(
                      _isSosTriggered ? '🚨 AUTO-SOS ACTIVATED' : 'AUTO-SOS IN: ${_countdown}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _timer?.cancel();
                        _flutterTts.setSpeechRate(0.5);
                        _flutterTts.speak("SOS cancelled.");
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryRed,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('CANCEL SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.public, size: 16, color: onSurfaceVariant),
                    SizedBox(width: 8),
                    Text(
                      'LIVE MAP NAVIGATION VIEW',
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, letterSpacing: 1.0, color: onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.fatigue_guard',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _rrLocation,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primaryRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Icon(Icons.local_gas_station, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation, color: primaryRed, size: 32),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('NEXT TURN', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: onSurfaceVariant)),
                                Text('300m • Exit 231', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: const Border(left: BorderSide(color: primaryRed, width: 6)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: errorContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on, color: primaryRed, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('NEAREST REST AREA DETECTED:', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: onSurfaceVariant)),
                                      const Text('Ayer Keroh R&R (Northbound)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: const [
                                          Text('4 mins', style: TextStyle(fontWeight: FontWeight.bold, color: primaryRed)),
                                          Text(' • ', style: TextStyle(color: onSurfaceVariant)),
                                          Text('3.2km', style: TextStyle(fontWeight: FontWeight.bold, color: primaryRed)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _timer?.cancel();
                                _flutterTts.setSpeechRate(0.5);
                                _flutterTts.speak("Navigation started.");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Navigation started...')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                elevation: 6,
                              ),
                              icon: const Icon(Icons.directions),
                              label: const Text('Start Navigation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
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
}