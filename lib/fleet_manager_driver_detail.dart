import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'fleet_manager_dashboard.dart';
import 'fleet_manager_select_driver.dart';

class FleetManagerDriverDetailPage extends StatefulWidget {
  final String driverName;
  final String driverId;
  final String vehicleId;
  final int score;
  final String statusText;
  final String riskLevel;
  final double latitude;   // Driver-specific latitude
  final double longitude;  // Driver-specific longitude

  const FleetManagerDriverDetailPage({
    super.key,
    this.driverName = 'Ahmad Fariz',
    this.driverId = 'DRV-8842',
    this.vehicleId = 'V-04',
    this.score = 72,
    this.statusText = 'Action Recommended',
    this.riskLevel = 'at_risk',
    this.latitude = 1.4927,   // Default coordinates
    this.longitude = 103.7414,
  });

  @override
  State<FleetManagerDriverDetailPage> createState() =>
      _FleetManagerDriverDetailPageState();
}

class _FleetManagerDriverDetailPageState
    extends State<FleetManagerDriverDetailPage> {
  final MapController _mapController = MapController();
  final double _currentZoom = 14.0;

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color onPrimaryContainer = Color(0xFFDAD7FF);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color secondaryColor = Color(0xFF515F74);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);
  static const Color outlineVariant = Color(0xFFC7C4D8);

  Color _getRiskBgColor(String level) {
    switch (level) {
      case 'at_risk':
        return const Color(0xFFFEF3C7);
      case 'warning':
        return const Color(0xFFFFE4D6);
      default:
        return const Color(0xFFD1FAE5);
    }
  }

  Color _getRiskFgColor(String level) {
    switch (level) {
      case 'at_risk':
        return const Color(0xFF92400E);
      case 'warning':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF065F46);
    }
  }

  IconData _getRiskIcon(String level) {
    switch (level) {
      case 'at_risk':
      case 'warning':
        return Icons.warning;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.driverName,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${widget.driverId} • Truck ${widget.vehicleId}',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getRiskBgColor(widget.riskLevel),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRiskIcon(widget.riskLevel),
                    size: 14,
                    color: _getRiskFgColor(widget.riskLevel),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.riskLevel.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRiskFgColor(widget.riskLevel),
                    ),
                  ),
                ],
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
                _buildSafetyRatingCard(),
                const SizedBox(height: 24),
                const Text(
                  "THIS WEEK'S SAFETY INCIDENTS",
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildIncidentsCard(),
                const SizedBox(height: 24),
                const Text(
                  'FLEET OPERATIONS INTERVENTIONS',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInterventionsButtons(),
                const SizedBox(height: 24),
                const Text(
                  'LIVE LOCATION TRACKING',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLiveLocationMap(),
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
          border: Border(
            top: BorderSide(color: outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FleetManagerDashboardPage(),
                  ),
                );
              },
              icon: const Icon(Icons.map, color: onSurfaceVariant),
              label: const Text(
                'Heatmap',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceVariant,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverSelectPage(),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryContainer,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group, color: onPrimaryContainer, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Drivers',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onPrimaryContainer,
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

  Widget _buildSafetyRatingCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getRiskBgColor(widget.riskLevel),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.score}%',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getRiskFgColor(widget.riskLevel),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Rating: ${widget.score}',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.statusText,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _getRiskFgColor(widget.riskLevel),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Below fleet target score (80)',
                  style: TextStyle(
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
  }

  Widget _buildIncidentsCard() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _buildIncidentRow(
            icon: Icons.bedtime,
            title: 'Drowsiness Events',
            subtitle: '3 Level-1 warnings triggered',
            badgeValue: '3',
            showDivider: true,
          ),
          _buildIncidentRow(
            icon: Icons.smartphone,
            title: 'Distraction Events',
            subtitle: '1 Head pose / phone event',
            badgeValue: '1',
            showDivider: true,
          ),
          _buildIncidentRow(
            icon: Icons.sos,
            title: 'SOS Emergency Calls',
            subtitle: '0 Critical emergency interventions',
            badgeValue: '0',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeValue,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: onSurfaceVariant, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badgeValue,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: outlineVariant.withValues(alpha: 0.3)),
      ],
    );
  }

  Widget _buildInterventionsButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${widget.driverName} (+60 12-345 6789)...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, size: 18),
                SizedBox(width: 8),
                Text(
                  'Call Driver',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Rest advisory sent to Truck ${widget.vehicleId}.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: surfaceContainerHigh,
              foregroundColor: onSurface,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: onSurfaceVariant),
                SizedBox(width: 8),
                Text(
                  'Rest Advisory',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveLocationMap() {
    // Uses the passed specific latitude and longitude
    final LatLng truckLocation = LatLng(widget.latitude, widget.longitude);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: truckLocation,
            initialZoom: _currentZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fatigue_guard',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: truckLocation,
                  width: 120,
                  height: 70,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Truck ${widget.vehicleId}',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.local_shipping, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}