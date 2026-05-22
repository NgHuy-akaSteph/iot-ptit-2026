import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../model/enviroment_data.dart';
import '../service/websocket_service.dart';
import '../service/thingsboard_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/control_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/telemetry_chart.dart';
import '../widgets/time_range_selector.dart';
import '../service/theme_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WebSocketService _wsService = WebSocketService();
  final ThingsBoardService _tbService = ThingsBoardService();

  EnvironmentData _currentData = EnvironmentData();
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentIndex = 0;
  bool _isDarkMode = true;

  final List<FlSpot> _tempHistory = [];
  final List<FlSpot> _humidityHistory = [];
  final List<FlSpot> _dustHistory = [];
  final List<FlSpot> _gasHistory = [];
  final List<DateTime> _timestamps = [];
  double _timeIndex = 0;

  TimeRange _selectedRange = TimeRange.oneHour;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeConnection();
  }

  Future<void> _loadTheme() async {
    final dark = await ThemeService.isDarkMode;
    setState(() => _isDarkMode = dark);
  }

  Future<void> _handleThemeChange(bool isDark) async {
    await ThemeService.setDarkMode(isDark);
    setState(() => _isDarkMode = isDark);
  }

  Future<void> _initializeConnection() async {
    try {
      await _wsService.connect();

      _wsService.telemetryStream.listen((data) {
        setState(() {
          _currentData = EnvironmentData.fromThingsBoard(data, _currentData);
          _isLoading = false;
          _errorMessage = '';

          _addToHistory(_tempHistory, _currentData.temperature);
          _addToHistory(_humidityHistory, _currentData.humidity);
          _addToHistory(_dustHistory, _currentData.dustUg);
          _addToHistory(_gasHistory, _currentData.gasPpm);
          _timestamps.add(DateTime.now());
          if (_timestamps.length > 20) {
            _timestamps.removeAt(0);
          }
          _timeIndex++;
        });
      });

      final telemetry = await _tbService.getLatestTelemetry();
      if (telemetry != null) {
        setState(() {
          _currentData = EnvironmentData.fromThingsBoard(telemetry, _currentData);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể kết nối đến ThingsBoard';
      });
    }
  }

  void _addToHistory(List<FlSpot> history, double value) {
    history.add(FlSpot(_timeIndex, value));
    if (history.length > 20) {
      history.removeAt(0);
    }
  }

  Future<void> _fetchAndDisplayHistory() async {
    setState(() => _isLoadingHistory = true);

    try {
      final data = await _tbService.fetchHistoricalTelemetry(_selectedRange);
      if (data != null && mounted) {
        setState(() {
          _timestamps.clear();
          _tempHistory.clear();
          _humidityHistory.clear();
          _dustHistory.clear();
          _gasHistory.clear();

          final tempEntries = data['temperature'] ?? [];
          final humidityEntries = data['humidity'] ?? [];
          final dustEntries = data['dust_ug'] ?? [];
          final gasEntries = data['gas_ppm'] ?? [];

          // Find the maximum length to align data points
          final maxLength = [
            tempEntries.length,
            humidityEntries.length,
            dustEntries.length,
            gasEntries.length,
          ].reduce((a, b) => a > b ? a : b);

          for (int i = 0; i < maxLength; i++) {
            // Collect all timestamps at this index
            final times = <DateTime>[];
            if (i < tempEntries.length) times.add(tempEntries[i].timestamp);
            if (i < humidityEntries.length) times.add(humidityEntries[i].timestamp);
            if (i < dustEntries.length) times.add(dustEntries[i].timestamp);
            if (i < gasEntries.length) times.add(gasEntries[i].timestamp);

            // Use the most recent timestamp at this index
            if (times.isNotEmpty) {
              times.sort();
              _timestamps.add(times.last);
            } else {
              _timestamps.add(DateTime.now());
            }

            _tempHistory.add(FlSpot(i.toDouble(),
                i < tempEntries.length ? tempEntries[i].value : 0.0));
            _humidityHistory.add(FlSpot(i.toDouble(),
                i < humidityEntries.length ? humidityEntries[i].value : 0.0));
            _dustHistory.add(FlSpot(i.toDouble(),
                i < dustEntries.length ? dustEntries[i].value : 0.0));
            _gasHistory.add(FlSpot(i.toDouble(),
                i < gasEntries.length ? gasEntries[i].value : 0.0));

            _timeIndex++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải dữ liệu lịch sử'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _handleAutoModeChange(bool enabled) async {
    final success = await _tbService.setAutoMode(enabled);
    if (success) {
      setState(() {
        _currentData = EnvironmentData(
          temperature: _currentData.temperature,
          humidity: _currentData.humidity,
          dustUg: _currentData.dustUg,
          gasPpm: _currentData.gasPpm,
          autoMode: enabled,
          fanLevel: _currentData.fanLevel,
        );
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể thay đổi chế độ tự động'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleFanLevelChange(int level) async {
    final success = await _tbService.setFanLevel(level);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thay đổi mức quạt'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final telemetry = await _tbService.getLatestTelemetry();
        if (telemetry != null && mounted) {
          setState(() {
            _currentData = EnvironmentData.fromThingsBoard(telemetry, _currentData);
          });
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: SensorCard(
                      title: 'Nhiệt độ',
                      value: _currentData.temperature.toStringAsFixed(1),
                      unit: '°C',
                      icon: Icons.thermostat,
                      valueColor: Colors.redAccent,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SensorCard(
                      title: 'Độ ẩm',
                      value: _currentData.humidity.toStringAsFixed(1),
                      unit: '%',
                      icon: Icons.water_drop,
                      valueColor: Colors.blueAccent,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SensorCard(
                      title: 'Bụi mịn',
                      value: _currentData.dustUg.toStringAsFixed(1),
                      unit: 'µg/m³',
                      icon: Icons.air,
                      valueColor: Colors.orangeAccent,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SensorCard(
                      title: 'Không khí',
                      value: _currentData.gasPpm.toStringAsFixed(1),
                      unit: 'ppm',
                      icon: Icons.eco,
                      valueColor: Colors.greenAccent,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ControlPanel(
                autoMode: _currentData.autoMode,
                fanLevel: _currentData.fanLevel,
                onAutoModeChanged: _handleAutoModeChange,
                onFanLevelChanged: (level) => _handleFanLevelChange(level.round()),
                isDarkMode: _isDarkMode,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimeRangeSelector(
            selected: _selectedRange,
            onChanged: (range) {
              setState(() => _selectedRange = range);
              _fetchAndDisplayHistory();
            },
            isDarkMode: _isDarkMode,
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!_isLoadingHistory) ...[
            TelemetryChart(
              dataPoints: _tempHistory,
              lineColor: Colors.redAccent,
              title: 'Nhiệt độ',
              timestamps: _timestamps,
              isDarkMode: _isDarkMode,
            ),
            const SizedBox(height: 16),
            TelemetryChart(
              dataPoints: _humidityHistory,
              lineColor: Colors.blueAccent,
              title: 'Độ ẩm',
              timestamps: _timestamps,
              isDarkMode: _isDarkMode,
            ),
            const SizedBox(height: 16),
            TelemetryChart(
              dataPoints: _dustHistory,
              lineColor: Colors.orangeAccent,
              title: 'Nồng độ bụi mịn',
              timestamps: _timestamps,
              isDarkMode: _isDarkMode,
            ),
            const SizedBox(height: 16),
            TelemetryChart(
              dataPoints: _gasHistory,
              lineColor: Colors.greenAccent,
              title: 'Chất lượng không khí',
              timestamps: _timestamps,
              isDarkMode: _isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SettingsPanel(
      isDarkMode: _isDarkMode,
      onThemeChanged: _handleThemeChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0D0D0D) : Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    ['Tổng quan', 'Biểu đồ', 'Cài đặt'][_currentIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildOverviewTab(),
                  _buildChartsTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
          selectedItemColor: _isDarkMode ? Colors.teal : Colors.blue,
          unselectedItemColor: _isDarkMode ? Colors.grey : Colors.grey.shade500,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Tổng quan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_outlined),
              activeIcon: Icon(Icons.show_chart),
              label: 'Biểu đồ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }
}
