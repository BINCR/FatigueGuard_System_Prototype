import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'driver_analytics.dart';
import 'driver_profile.dart';
import 'driving_ing.dart';
import 'profile_data.dart'; // Import global avatar state

class DriverNotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  bool isRead;

  DriverNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.isRead = false,
  });
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<DriverNotificationItem> _notifications = [
    DriverNotificationItem(
      id: '1',
      title: 'Rest Advisory from Fleet Manager',
      message:
          'Manager requested you to take a mandatory 15-min rest stop at the nearest R&R.',
      time: '10m ago',
      icon: Icons.coffee,
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      isRead: false,
    ),
    DriverNotificationItem(
      id: '2',
      title: 'ESP32 Sensor Reconnected',
      message:
          'Head pose tracking and G-force sensors calibrated successfully.',
      time: '45m ago',
      icon: Icons.sensors,
      iconBgColor: const Color(0xFFDCFCE7),
      iconColor: const Color(0xFF16A34A),
      isRead: false,
    ),
    DriverNotificationItem(
      id: '3',
      title: 'Fatigue Risk Resolved',
      message: 'Blink rate normalized. Safety score restored to 85.',
      time: '2h ago',
      icon: Icons.check_circle_outline,
      iconBgColor: const Color(0xFFDEE8FF),
      iconColor: const Color(0xFF3525CD),
      isRead: true,
    ),
    DriverNotificationItem(
      id: '4',
      title: 'Weekly Safety Score Ready',
      message:
          'Great job! You achieved a 92% safe driving compliance this week.',
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
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = Color(0xFFC7C4D8);

  @override
  void initState() {
    super.initState();
    profileData.addListener(_onProfileChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    profileData.removeListener(_onProfileChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  int get _unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
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
                        Row(
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
                            if (_unreadNotificationCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_unreadNotificationCount new',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_unreadNotificationCount > 0)
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
                    child: _notifications.isEmpty
                        ? const Center(
                            child: Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _notifications.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _notifications[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    item.isRead = true;
                                  });
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: item.isRead
                                        ? surfaceContainerLowest
                                        : const Color(0xFFF0F4FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: item.isRead
                                          ? outlineVariant.withValues(
                                              alpha: 0.3,
                                            )
                                          : primaryContainer.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: item.iconBgColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
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
                                                ),
                                                Text(
                                                  item.time,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        'JetBrains Mono',
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
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!item.isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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
                  size: 24,
                ),
                onPressed: _showNotificationsSheet,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBA1A1A),
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
          const SizedBox(width: 8),
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
                _buildGreetingBanner(),
                const SizedBox(height: 20),
                _buildStatusRow(),
                const SizedBox(height: 20),
                _buildCentralStatusCard(),
                const SizedBox(height: 20),
                _buildMetricsSection(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DrivingIngPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withValues(alpha: 0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'START DRIVING SESSION',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: primaryContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility, color: onPrimaryContainer, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Monitoring',
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
                    builder: (context) => const DriverAnalyticsPage(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.leaderboard_outlined,
                      color: onSurfaceVariant,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Analytics',
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
                child: const Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: onSurfaceVariant,
                      size: 18,
                    ),
                    SizedBox(width: 6),
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

  Widget _buildGreetingBanner() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hi, Chew Rong Bin',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                const Text(
                  'DRIVER ROLE',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DriverProfilePage(),
              ),
            );
          },
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: profileData.avatarFile != null
                  ? Image.file(
                      File(profileData.avatarFile!.path),
                      fit: BoxFit.cover,
                      width: 54,
                      height: 54,
                    )
                  : const Icon(Icons.person, color: secondaryColor, size: 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.settings_input_component,
                      color: primaryColor,
                      size: 22,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'CONNECTION',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ESP32',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
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
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.sensors, color: primaryColor, size: 22),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'G-FORCE SENSOR',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentralStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.mood, size: 54, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SAFE!',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Status: Optimal Fatigue Levels',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MONITORING...',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAFETY SCORE',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(76, 76),
                          painter: _ScoreGaugePainter(score: 0.85),
                        ),
                        const Text(
                          '85',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Excellent!',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
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
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUMMARY',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSummaryItem(
                  Icons.warning_amber_rounded,
                  'FATIGUE',
                  '0 Events',
                ),
                const SizedBox(height: 8),
                _buildSummaryItem(Icons.schedule, 'DRIVE TIME', '42 min'),
                const SizedBox(height: 8),
                _buildSummaryItem(Icons.coffee_outlined, 'REST REQ.', 'No'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                color: onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  final double score;
  _ScoreGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    final trackPaint = Paint()
      ..color = const Color(0xFFDEE8FF)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = const Color(0xFF3525CD)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * score;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
