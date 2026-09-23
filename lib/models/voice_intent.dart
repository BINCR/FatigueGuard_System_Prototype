enum VoiceIntent {
  none,
  startMonitoring,
  stopMonitoring,
  dismissWarning,
  checkStatus,
  openMonitoring,
  openAnalytics,
  openProfile,
  mute,
  enableSound,
  unknown,
}

class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    required this.rawText,
    required this.commandText,
  });

  final VoiceIntent intent;
  final String rawText;
  final String commandText;

  bool get hasWakeWord => intent != VoiceIntent.none;
}
