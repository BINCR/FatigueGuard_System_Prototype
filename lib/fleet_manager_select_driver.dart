import 'package:flutter/material.dart';
import 'fleet_manager_driver_detail.dart';

class FleetDriverItem {
  final String id;
  final String name;
  final String vehicleId;
  final String riskLevel;
  final int score;
  final String statusText;

  const FleetDriverItem({
    required this.id,
    required this.name,
    required this.vehicleId,
    required this.riskLevel,
    required this.score,
    required this.statusText,
  });
}

class DriverSelectPage extends StatefulWidget {
  const DriverSelectPage({super.key});

  @override
  State<DriverSelectPage> createState() => _DriverSelectPageState();
}

class _DriverSelectPageState extends State<DriverSelectPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final String _filter = 'all';

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = Color(0xFFC7C4D8);

  final List<FleetDriverItem> _drivers = const [
    FleetDriverItem(
      id: 'DRV-8842',
      name: 'Ahmad Fariz',
      vehicleId: 'V-04',
      riskLevel: 'at_risk',
      score: 72,
      statusText: 'Action Recommended',
    ),
    FleetDriverItem(
      id: 'DRV-1123',
      name: 'Alex Chen',
      vehicleId: 'V-01',
      riskLevel: 'safe',
      score: 98,
      statusText: '0 Fatigue Events',
    ),
    FleetDriverItem(
      id: 'DRV-2231',
      name: 'David Lee',
      vehicleId: 'V-03',
      riskLevel: 'safe',
      score: 95,
      statusText: '0 Fatigue Events',
    ),
    FleetDriverItem(
      id: 'DRV-3391',
      name: 'John Smith',
      vehicleId: 'V-02',
      riskLevel: 'warning',
      score: 82,
      statusText: '2 Warnings Today',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FleetDriverItem> get _filteredDrivers {
    return _drivers.where((d) {
      final q = _query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.id.toLowerCase().contains(q) ||
          d.vehicleId.toLowerCase().contains(q);
      final matchesFilter = _filter == 'all' || d.riskLevel == _filter;
      return matchesQuery && matchesFilter;
    }).toList();
  }

  ({Color bg, Color fg, String label}) _riskStyle(String riskLevel) {
    switch (riskLevel) {
      case 'at_risk':
        return (
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFF92400E),
          label: 'AT RISK',
        );
      case 'warning':
        return (
          bg: const Color(0xFFFFE4D6),
          fg: const Color(0xFFB45309),
          label: 'WARNING',
        );
      default:
        return (
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
          label: 'SAFE',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _filteredDrivers;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Driver',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Search by name, driver ID, or truck',
                  prefixIcon: const Icon(Icons.search, color: onSurfaceVariant),
                  filled: true,
                  fillColor: surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDriverListItem(drivers[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverListItem(FleetDriverItem driver) {
    final style = _riskStyle(driver.riskLevel);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FleetManagerDriverDetailPage(
              driverName: driver.name,
              driverId: driver.id,
              vehicleId: driver.vehicleId,
              score: driver.score,
              statusText: driver.statusText,
              riskLevel: driver.riskLevel,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          // Use withOpacity instead of withValues to ensure compatibility with older Flutter versions
          border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: primaryContainer.withValues(alpha: 0.15),
              child: Text(
                driver.name.isNotEmpty ? driver.name[0] : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${driver.id} • Truck ${driver.vehicleId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    style.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: style.fg,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${driver.score} pts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
