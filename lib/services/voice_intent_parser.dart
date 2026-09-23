import '../models/voice_intent.dart';

class VoiceIntentParser {
  static const List<String> _wakeWords = <String>[
    'fatigue guard',
    'fatigued guard',
    'fatigue card',
    'fatigueguard',
  ];

  static const Set<String> _dismissCommands = <String>{
    'no',
    'dismiss',
    'cancel',
    'close',
    '不用',
    '取消',
    '关闭',
    'tidak',
    'batal',
    'tutup',
  };

  static const Set<String> _startCommands = <String>{
    'start',
    'begin',
    '开始',
    '开始监测',
    'mula',
    'mulakan',
  };

  static const Set<String> _stopCommands = <String>{
    'stop',
    'pause',
    '停止',
    '暂停',
    'henti',
    'hentikan',
  };

  static const Set<String> _statusCommands = <String>{
    'status',
    'check status',
    '当前状态',
    '状态',
    'semak status',
    'status sekarang',
  };

  static const Set<String> _monitoringCommands = <String>{
    'monitoring',
    'monitor',
    '监测',
    '监测页面',
    'pemantauan',
  };

  static const Set<String> _analyticsCommands = <String>{
    'analytics',
    'analysis',
    '分析',
    '分析页面',
    'analitik',
  };

  static const Set<String> _profileCommands = <String>{
    'profile',
    '个人页面',
    '个人资料',
    'profil',
  };

  static const Set<String> _muteCommands = <String>{
    'mute',
    'silent',
    '静音',
    'senyap',
    'senyapkan',
  };

  static const Set<String> _soundCommands = <String>{
    'sound',
    'unmute',
    'enable sound',
    '开启声音',
    '打开声音',
    'bunyi',
    'hidupkan suara',
  };

  VoiceCommand parse(String recognisedText) {
    final String normalised = _normalise(recognisedText);
    final String? wakeWord = _findWakeWord(normalised);

    if (wakeWord == null) {
      return VoiceCommand(
        intent: VoiceIntent.none,
        rawText: recognisedText,
        commandText: '',
      );
    }

    final String command = normalised.substring(wakeWord.length).trim();

    return VoiceCommand(
      intent: _classify(command),
      rawText: recognisedText,
      commandText: command,
    );
  }

  String? _findWakeWord(String text) {
    for (final String wakeWord in _wakeWords) {
      if (text == wakeWord || text.startsWith('$wakeWord ')) {
        return wakeWord;
      }
    }
    return null;
  }

  VoiceIntent _classify(String command) {
    if (command.isEmpty) {
      return VoiceIntent.unknown;
    }
    if (_dismissCommands.contains(command)) return VoiceIntent.dismissWarning;
    if (_startCommands.contains(command)) return VoiceIntent.startMonitoring;
    if (_stopCommands.contains(command)) return VoiceIntent.stopMonitoring;
    if (_statusCommands.contains(command)) return VoiceIntent.checkStatus;
    if (_monitoringCommands.contains(command)) {
      return VoiceIntent.openMonitoring;
    }
    if (_analyticsCommands.contains(command)) return VoiceIntent.openAnalytics;
    if (_profileCommands.contains(command)) return VoiceIntent.openProfile;
    if (_muteCommands.contains(command)) return VoiceIntent.mute;
    if (_soundCommands.contains(command)) return VoiceIntent.enableSound;
    return VoiceIntent.unknown;
  }

  String _normalise(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
