import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawConfidence = json['confidence'];

    return DetectionResult(
      label: (json['label'] ?? 'uncertain')
          .toString()
          .trim()
          .toLowerCase(),
      confidence: rawConfidence is num
          ? rawConfidence.toDouble()
          : double.tryParse(rawConfidence?.toString() ?? '') ?? 0.0,
    );
  }
}

class Esp32Service {
  Esp32Service({
    this.baseUrl = 'http://192.168.4.1',
  });

  final String baseUrl;
  final http.Client _client = http.Client();

  final StreamController<DetectionResult> _resultController =
      StreamController<DetectionResult>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Timer? _pollingTimer;
  bool _requestInProgress = false;
  bool? _lastConnectionState;
  int _mockIndex = 0;

  Stream<DetectionResult> get results => _resultController.stream;

  Stream<bool> get connectionStatus => _connectionController.stream;

  void start({bool mockMode = false}) {
    stop();

    if (mockMode) {
      _setConnected(true);
      _emitMockResult();

      _pollingTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _emitMockResult(),
      );
      return;
    }

    _readStatus();

    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _readStatus(),
    );
  }

  Future<void> _readStatus() async {
    if (_requestInProgress) return;
    _requestInProgress = true;

    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        throw Exception('ESP32 returned ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid ESP32 response');
      }

      final result = DetectionResult.fromJson(decoded);

      _setConnected(true);
      _resultController.add(result);
    } catch (_) {
      _setConnected(false);
    } finally {
      _requestInProgress = false;
    }
  }

  void _emitMockResult() {
    const mockResults = <DetectionResult>[
      DetectionResult(label: 'normal', confidence: 0.97),
      DetectionResult(label: 'eyes_closed', confidence: 0.91),
      DetectionResult(label: 'yawning', confidence: 0.89),
      DetectionResult(label: 'distracted', confidence: 0.93),
      DetectionResult(label: 'uncertain', confidence: 0.55),
    ];

    _resultController.add(mockResults[_mockIndex]);
    _mockIndex = (_mockIndex + 1) % mockResults.length;
  }

  void _setConnected(bool connected) {
    if (_lastConnectionState == connected) return;

    _lastConnectionState = connected;
    _connectionController.add(connected);
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stop();
    _client.close();
    _resultController.close();
    _connectionController.close();
  }
}