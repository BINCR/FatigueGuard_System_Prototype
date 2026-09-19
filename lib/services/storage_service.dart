import 'dart:math' as math;

import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String sessionsBoxName = 'driving_sessions';
  static const String eventsBoxName = 'detection_events';

  static const Duration _eventCooldown = Duration(seconds: 10);

  String? _activeSessionId;
  DateTime? _activeSessionStartedAt;

  final Map<String, DateTime> _lastSavedAt = <String, DateTime>{};

  Box<dynamic> get _sessionsBox {
    return Hive.box<dynamic>(sessionsBoxName);
  }

  Box<dynamic> get _eventsBox {
    return Hive.box<dynamic>(eventsBoxName);
  }

  String? get activeSessionId => _activeSessionId;

  bool get hasActiveSession => _activeSessionId != null;

  /// Starts a new driving session.
  ///
  /// If a driving session is already active, the existing ID is returned.
  Future<String> startDrivingSession() async {
    if (_activeSessionId != null) {
      return _activeSessionId!;
    }

    final DateTime now = DateTime.now();
    final String sessionId = 'session_${now.microsecondsSinceEpoch}';

    _activeSessionId = sessionId;
    _activeSessionStartedAt = now;
    _lastSavedAt.clear();

    await _sessionsBox.put(
      sessionId,
      <String, dynamic>{
        'id': sessionId,
        'startedAt': now.toIso8601String(),
        'endedAt': null,
        'durationSeconds': 0,
        'eventCount': 0,
        'yawningCount': 0,
        'eyesClosedCount': 0,
        'distractedCount': 0,
        'maxAlertLevel': 0,
        'status': 'active',

        // Reserved for future MySQL or cloud synchronization.
        'synced': false,
      },
    );

    return sessionId;
  }

  /// Saves an important fatigue or distraction event.
  ///
  /// Normal and uncertain detections are not saved.
  /// The same type of event will only be saved once every 10 seconds.
  Future<void> saveDetectionEvent({
    required String label,
    required double confidence,
    required int alertLevel,
  }) async {
    final String normalizedLabel = label.trim().toLowerCase();

    const Set<String> importantLabels = <String>{
      'eyes_closed',
      'yawning',
      'distracted',
    };

    if (!importantLabels.contains(normalizedLabel)) {
      return;
    }

    final String sessionId =
        _activeSessionId ?? await startDrivingSession();

    final DateTime now = DateTime.now();
    final DateTime? lastSaved = _lastSavedAt[normalizedLabel];

    // Prevent the same ESP32 result from producing too many records.
    if (lastSaved != null &&
        now.difference(lastSaved) < _eventCooldown) {
      return;
    }

    final String eventId = 'event_${now.microsecondsSinceEpoch}';

    final double safeConfidence =
        confidence.clamp(0.0, 1.0).toDouble();

    final int safeAlertLevel = alertLevel.clamp(0, 3);

    await _eventsBox.put(
      eventId,
      <String, dynamic>{
        'id': eventId,
        'sessionId': sessionId,
        'timestamp': now.toIso8601String(),
        'label': normalizedLabel,
        'confidence': safeConfidence,
        'alertLevel': safeAlertLevel,

        // This will become true after future MySQL/cloud upload.
        'synced': false,
      },
    );

    await _updateSessionSummary(
      sessionId: sessionId,
      label: normalizedLabel,
      alertLevel: safeAlertLevel,
    );

    _lastSavedAt[normalizedLabel] = now;
  }

  Future<void> _updateSessionSummary({
    required String sessionId,
    required String label,
    required int alertLevel,
  }) async {
    final dynamic rawSession = _sessionsBox.get(sessionId);

    if (rawSession is! Map) {
      return;
    }

    final Map<String, dynamic> session =
        Map<String, dynamic>.from(rawSession);

    session['eventCount'] =
        ((session['eventCount'] as num?)?.toInt() ?? 0) + 1;

    switch (label) {
      case 'yawning':
        session['yawningCount'] =
            ((session['yawningCount'] as num?)?.toInt() ?? 0) + 1;
        break;

      case 'eyes_closed':
        session['eyesClosedCount'] =
            ((session['eyesClosedCount'] as num?)?.toInt() ?? 0) + 1;
        break;

      case 'distracted':
        session['distractedCount'] =
            ((session['distractedCount'] as num?)?.toInt() ?? 0) + 1;
        break;
    }

    final int currentMaximum =
        (session['maxAlertLevel'] as num?)?.toInt() ?? 0;

    session['maxAlertLevel'] =
        math.max(currentMaximum, alertLevel);

    session['updatedAt'] = DateTime.now().toIso8601String();
    session['synced'] = false;

    await _sessionsBox.put(sessionId, session);
  }

  /// Ends the active driving session and calculates its duration.
  Future<void> endDrivingSession() async {
    final String? sessionId = _activeSessionId;
    final DateTime? startedAt = _activeSessionStartedAt;

    if (sessionId == null || startedAt == null) {
      return;
    }

    final dynamic rawSession = _sessionsBox.get(sessionId);

    if (rawSession is Map) {
      final DateTime now = DateTime.now();

      final Map<String, dynamic> session =
          Map<String, dynamic>.from(rawSession);

      session['endedAt'] = now.toIso8601String();
      session['durationSeconds'] =
          now.difference(startedAt).inSeconds;
      session['status'] = 'completed';
      session['synced'] = false;

      await _sessionsBox.put(sessionId, session);
    }

    _activeSessionId = null;
    _activeSessionStartedAt = null;
    _lastSavedAt.clear();
  }

  /// Returns all driving sessions with the newest session first.
  List<Map<String, dynamic>> getAllSessions() {
    final List<Map<String, dynamic>> sessions =
        _sessionsBox.values
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> session) =>
                  Map<String, dynamic>.from(session),
            )
            .toList();

    sessions.sort(
      (
        Map<String, dynamic> first,
        Map<String, dynamic> second,
      ) {
        final String firstTime =
            first['startedAt']?.toString() ?? '';

        final String secondTime =
            second['startedAt']?.toString() ?? '';

        return secondTime.compareTo(firstTime);
      },
    );

    return sessions;
  }

  /// Returns all detection events with the newest event first.
  ///
  /// Supplying a session ID returns events from that session only.
  List<Map<String, dynamic>> getDetectionEvents({
    String? sessionId,
  }) {
    final List<Map<String, dynamic>> events =
        _eventsBox.values
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> event) =>
                  Map<String, dynamic>.from(event),
            )
            .where(
              (Map<String, dynamic> event) =>
                  sessionId == null ||
                  event['sessionId'] == sessionId,
            )
            .toList();

    events.sort(
      (
        Map<String, dynamic> first,
        Map<String, dynamic> second,
      ) {
        final String firstTime =
            first['timestamp']?.toString() ?? '';

        final String secondTime =
            second['timestamp']?.toString() ?? '';

        return secondTime.compareTo(firstTime);
      },
    );

    return events;
  }

  /// Returns one session using its session ID.
  Map<String, dynamic>? getSession(String sessionId) {
    final dynamic rawSession = _sessionsBox.get(sessionId);

    if (rawSession is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawSession);
  }

  /// Returns the number of locally stored driving sessions.
  int get sessionCount => _sessionsBox.length;

  /// Returns the number of locally stored detection events.
  int get eventCount => _eventsBox.length;

  /// Deletes all locally stored sessions and detection events.
  ///
  /// This can later be connected to a Clear History button.
  Future<void> clearAllData() async {
    await _eventsBox.clear();
    await _sessionsBox.clear();

    _activeSessionId = null;
    _activeSessionStartedAt = null;
    _lastSavedAt.clear();
  }
}