import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'driver_home.dart';
import 'driver_profile.dart';
import 'profile_data.dart'; // Import global avatar state
import 'services/storage_service.dart';

class AnalyticsNotificationItem {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  bool isRead;

  AnalyticsNotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.isRead = false,
  });
}

class DriverAnalyticsPage extends StatefulWidget {
  const DriverAnalyticsPage({super.key});

  @override
  State<DriverAnalyticsPage> createState() => _DriverAnalyticsPageState();
}

class _DriverAnalyticsPageState extends State<DriverAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnimation;
  List<Map<String, dynamic>> _sessions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  int get _totalEvents => _events.length;

  int get _drowsyEvents =>
      _events.where((event) => event['label'] == 'drowsy').length;

  int get _distractedEvents =>
      _events.where((event) => event['label'] == 'distracted').length;

  int get _totalDriveSeconds => _sessions.fold<int>(
    0,
    (total, session) =>
        total + ((session['durationSeconds'] as num?)?.toInt() ?? 0),
  );

  double get _safetyScore {
    if (_sessions.isEmpty) return 1.0;
    final double penalty = (_totalEvents / (_sessions.length * 5))
        .clamp(0, 1)
        .toDouble();
    return (1 - (penalty * 0.5)).clamp(0.5, 1.0).toDouble();
  }

  final List<AnalyticsNotificationItem> _notifications = [
    AnalyticsNotificationItem(
      title: 'Rest Advisory from Fleet Manager',
      message: 'Manager requested you to take a mandatory 15-min rest stop.',
      time: '15m ago',
      icon: Icons.coffee,
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      isRead: false,
    ),
    AnalyticsNotificationItem(
      title: 'Weekly Safety Target Achieved',
      message: 'Your safety score stayed above 90% for 4 consecutive weeks.',
      time: '1d ago',
      icon: Icons.military_tech,
      iconBgColor: const Color(0xFFEDE9FE),
      iconColor: const Color(0xFF6D28D9),
      isRead: true,
    ),
  ];

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color onPrimaryContainer = Color(0xFFDAD7FF);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color secondaryColor = Color(0xFF515F74);
  static const Color secondaryContainer = Color(0xFFD5E3FC);
  static const Color surfaceColor = Color(0xFFF9F9FF);
  static const Color surfaceContainerHighest = Color(0xFFD8E3FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = Color(0xFFC7C4D8);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    profileData.addListener(_onProfileChanged);
    _sessions = StorageService.instance.getAllSessions();
    _events = StorageService.instance.getDetectionEvents();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnimation = Tween<double>(begin: 0.0, end: _safetyScore).animate(
      CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic),
    );
    _gaugeController.forward();
  }

  @override
  void dispose() {
    profileData.removeListener(_onProfileChanged);
    _gaugeController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatTime(DateTime value) {
    final int hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    return '$hour:${_twoDigits(value.minute)} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDate(DateTime value) {
    final DateTime now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return 'Today';
    }
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '$minutes min';
    return '$seconds sec';
  }

  Widget _buildStoredSession(Map<String, dynamic> session) {
    final DateTime startedAt =
        DateTime.tryParse(session['startedAt']?.toString() ?? '') ??
        DateTime.now();
    final int eventCount = (session['eventCount'] as num?)?.toInt() ?? 0;
    final int maxLevel = (session['maxAlertLevel'] as num?)?.toInt() ?? 0;
    final int duration = (session['durationSeconds'] as num?)?.toInt() ?? 0;

    if (eventCount == 0) {
      return _buildHistoryItem(
        icon: Icons.check_circle_outline,
        iconBgColor: primaryContainer.withValues(alpha: 0.1),
        iconColor: primaryColor,
        title: 'Normal Drive',
        time: _formatTime(startedAt),
        date: _formatDate(startedAt),
        duration: _formatDuration(duration),
      );
    }

    return _buildHistoryItem(
      icon: maxLevel >= 3 ? Icons.warning_amber_rounded : Icons.error_outline,
      iconBgColor: maxLevel >= 3 ? errorContainer : secondaryContainer,
      iconColor: maxLevel >= 3 ? errorColor : secondaryColor,
      title: maxLevel >= 3
          ? 'Severe Fatigue Alert'
          : '$eventCount Safety Event${eventCount == 1 ? '' : 's'}',
      time: _formatTime(startedAt),
      date: _formatDate(startedAt),
      duration: _formatDuration(duration),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        if (_unreadCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (var item in _notifications) {
                                  item.isRead = true;
                                }
                              });
                              setModalState(() {});
                            },
                            child: const Text(
                              'Mark all as read',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? surfaceContainerLowest
                                : const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: item.iconBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.icon,
                                  color: item.iconColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 13,
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            color: onSurface,
                                          ),
                                        ),
                                        Text(
                                          item.time,
                                          style: const TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 10,
                                            color: onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 12,
                                        color: onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Complete Driving History',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sessions.isEmpty
                    ? const Center(
                        child: Text(
                          'No driving history yet.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            color: onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _buildStoredSession(_sessions[index]),
                      ),
              ),
            ],
          ),
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: onSurfaceVariant,
                ),
                onPressed: _showNotificationsSheet,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverProfilePage(),
                  ),
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondaryContainer,
                  border: Border.all(
                    color: outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipOval(
                  child: profileData.avatarFile != null
                      ? Image.file(
                          File(profileData.avatarFile!.path),
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                        )
                      : const Icon(
                          Icons.person,
                          color: secondaryColor,
                          size: 22,
                        ),
                ),
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
                const Text(
                  'Safety Analytics',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your performance over the last 30 days.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _buildGaugeCard(),
                const SizedBox(height: 20),
                _buildStatisticsGrid(),
                const SizedBox(height: 20),
                _buildTrendChartSection(),
                const SizedBox(height: 20),
                _buildInsightsBanner(),
                const SizedBox(height: 24),
                _buildRecentHistorySection(),
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
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverHomePage(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors, color: onSurfaceVariant, size: 20),
                    SizedBox(height: 2),
                    Text(
                      'Monitoring',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: primaryContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.leaderboard, color: onPrimaryContainer, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Analytics',
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
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverProfilePage(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: onSurfaceVariant,
                      size: 20,
                    ),
                    SizedBox(height: 2),
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

  Widget _buildGaugeCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: AnimatedBuilder(
              animation: _gaugeAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(180, 180),
                      painter: _AnalyticsGaugePainter(
                        progress: _gaugeAnimation.value,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(_gaugeAnimation.value * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SAFETY SCORE',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: primaryColor, size: 18),
                SizedBox(width: 8),
                Text(
                  'Current Rating: Excellent',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.bedtime, color: primaryColor, size: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'THIS MONTH',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$_totalEvents',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Total Safety Events',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  color: onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_drowsyEvents drowsy • $_distractedEvents distracted',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule, color: secondaryColor, size: 22),
                    const SizedBox(height: 10),
                    Text(
                      _formatDuration(_totalDriveSeconds),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Total Drive Time',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: onSurfaceVariant,
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
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      color: errorColor,
                      size: 22,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_distractedEvents',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Distraction Events',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '4-Week Safety Trend',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              Icon(Icons.more_horiz, color: onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(painter: _SafetyTrendChartPainter()),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week 1',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: onSurfaceVariant,
                ),
              ),
              Text(
                'Week 2',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: onSurfaceVariant,
                ),
              ),
              Text(
                'Week 3',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: onSurfaceVariant,
                ),
              ),
              Text(
                'Week 4',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: onPrimaryContainer, size: 20),
              SizedBox(width: 8),
              Text(
                'PERSONALIZED INSIGHT',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: onPrimaryContainer,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '"You are most alert between 9:00 AM and 11:30 AM. Schedule your longest drives then."',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent History',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            TextButton(
              onPressed: _showAllHistoryModal,
              child: const Text(
                'VIEW ALL',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Complete a driving session to see history.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ..._sessions
              .take(3)
              .expand(
                (session) => <Widget>[
                  _buildStoredSession(session),
                  const SizedBox(height: 10),
                ],
              ),
      ],
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String time,
    required String date,
    required String duration,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: onSurfaceVariant,
                      ),
                    ),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsGaugePainter extends CustomPainter {
  final double progress;
  _AnalyticsGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    final trackPaint = Paint()
      ..color = const Color(0xFFDEE8FF)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = const Color(0xFF3525CD)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalyticsGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SafetyTrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFC7C4D8).withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.2),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      gridPaint,
    );

    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width, size.height * 0.35),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4D44E3).withValues(alpha: 0.25),
          const Color(0xFF4D44E3).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF3525CD)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF3525CD);
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, dotPaint);
      canvas.drawCircle(points[i], 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SafetyTrendChartPainter oldDelegate) => false;
}
