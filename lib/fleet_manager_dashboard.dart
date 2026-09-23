import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'fleet_manager_driver_detail.dart';
import 'fleet_manager_select_driver.dart'; // 1. Ensure selection page is imported
import 'login.dart';

class FleetManagerDashboardPage extends StatefulWidget {
  const FleetManagerDashboardPage({super.key});

  @override
  State<FleetManagerDashboardPage> createState() =>
      _FleetManagerDashboardPageState();
}

class _FleetManagerDashboardPageState extends State<FleetManagerDashboardPage> {
  String _activeTab = 'heatmap';

  final MapController _mapController = MapController();
  double _currentZoom = 13.0;

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color onPrimaryContainer = Color(0xFFDAD7FF);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);
  static const Color outlineVariant = Color(0xFFC7C4D8);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
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
                  'Fleet Manager Dashboard',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Real-Time Operations & Risk Analytics',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatsGrid(),
                const SizedBox(height: 20),
                _buildTabSwitcher(),
                const SizedBox(height: 16),
                if (_activeTab == 'heatmap')
                  _buildHeatmapView()
                else
                  _buildDriverRankView(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceContainerHigh,
                    foregroundColor: primaryColor,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = 'heatmap';
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _activeTab == 'heatmap'
                      ? primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: _activeTab == 'heatmap'
                          ? onPrimaryContainer
                          : onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Heatmap',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'heatmap'
                            ? onPrimaryContainer
                            : onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 2. Modify Drivers button: Navigate to DriverSelectPage first
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverSelectPage(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.group, color: onSurfaceVariant, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Drivers',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
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

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'ACTIVE FLEET',
            value: '12',
            valueColor: primaryColor,
            badgeWidget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'ONLINE',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'EVENTS TODAY',
            value: '3',
            valueColor: Colors.amber.shade800,
            badgeWidget: const Text(
              'ALERTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'SOS TODAY',
            value: '0',
            valueColor: errorColor,
            badgeWidget: const Text(
              'CRITICAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: errorColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color valueColor,
    required Widget badgeWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          badgeWidget,
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = 'heatmap';
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'heatmap'
                      ? primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Fatigue Heatmap',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'heatmap'
                            ? Colors.white
                            : onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = 'rank';
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'rank'
                      ? primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Driver Rank',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'rank'
                            ? Colors.white
                            : onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapView() {
    final LatLng defaultLocation = LatLng(1.4927, 103.7414);

    return Column(
      children: [
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: defaultLocation,
                    initialZoom: _currentZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.fatigue_guard',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(1.4950, 103.7450),
                          width: 40,
                          height: 40,
                          child: _buildVehicleMarker('V1', Colors.green),
                        ),
                        Marker(
                          point: LatLng(1.4900, 103.7380),
                          width: 40,
                          height: 40,
                          child: _buildVehicleMarker(
                            'V2',
                            Colors.amber.shade700,
                          ),
                        ),
                        Marker(
                          point: LatLng(1.4880, 103.7460),
                          width: 40,
                          height: 40,
                          child: _buildVehicleMarker('V3', Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Leaflet Live Map Active',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _buildMapButton(Icons.add, () {
                        setState(() {
                          if (_currentZoom < 18.0) _currentZoom += 1;
                          _mapController.move(
                            _mapController.camera.center,
                            _currentZoom,
                          );
                        });
                      }),
                      const SizedBox(height: 6),
                      _buildMapButton(Icons.remove, () {
                        setState(() {
                          if (_currentZoom > 3.0) _currentZoom -= 1;
                          _mapController.move(
                            _mapController.camera.center,
                            _currentZoom,
                          );
                        });
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(errorColor, 'High Risk Zone'),
              _buildLegendItem(Colors.amber.shade600, 'Moderate Risk'),
              _buildLegendItem(Colors.green, 'Normal Driving'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleMarker(String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: onSurface, size: 20),
      ),
    );
  }

  Widget _buildLegendItem(Color dotColor, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 10,
            color: onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverRankView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAFETY SCOREBOARD',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Top performing drivers this week',
                    style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                  ),
                ],
              ),
              Icon(Icons.military_tech, color: primaryColor, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 3. Leaderboard click can also directly jump to the specific DriverSelectPage, or pass specific driver data
        _buildDriverRankItem(
          rank: 1,
          rankBadgeColor: const Color(0xFFFBBF24),
          rankBadgeTextColor: Colors.white,
          name: 'V1 - Alex Chen',
          statusText: '0 Fatigue Events',
          statusColor: Colors.green,
          scoreText: '98 pts',
          scoreColor: primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FleetManagerDriverDetailPage(
                  driverName: 'Alex Chen',
                  driverId: 'DRV-1123',
                  vehicleId: 'V-01',
                  score: 98,
                  statusText: '0 Fatigue Events',
                  riskLevel: 'safe',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildDriverRankItem(
          rank: 2,
          rankBadgeColor: const Color(0xFFCBD5E1),
          rankBadgeTextColor: const Color(0xFF334155),
          name: 'V3 - David Lee',
          statusText: '0 Fatigue Events',
          statusColor: Colors.green,
          scoreText: '95 pts',
          scoreColor: primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FleetManagerDriverDetailPage(
                  driverName: 'David Lee',
                  driverId: 'DRV-2231',
                  vehicleId: 'V-03',
                  score: 95,
                  statusText: '0 Fatigue Events',
                  riskLevel: 'safe',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildDriverRankItem(
          rank: 3,
          rankBadgeColor: const Color(0xFFB45309),
          rankBadgeTextColor: Colors.white,
          name: 'V2 - John Smith',
          statusText: '2 Warnings Today',
          statusColor: Colors.amber.shade700,
          scoreText: '82 pts',
          scoreColor: Colors.amber.shade700,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FleetManagerDriverDetailPage(
                  driverName: 'John Smith',
                  driverId: 'DRV-3391',
                  vehicleId: 'V-02',
                  score: 82,
                  statusText: '2 Warnings Today',
                  riskLevel: 'warning',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDriverRankItem({
    required int rank,
    required Color rankBadgeColor,
    required Color rankBadgeTextColor,
    required String name,
    required String statusText,
    required Color statusColor,
    required String scoreText,
    required Color scoreColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankBadgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rankBadgeTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  scoreText,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: outlineVariant,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
