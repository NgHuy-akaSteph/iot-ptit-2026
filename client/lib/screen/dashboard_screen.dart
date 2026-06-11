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

// ==========================================
// Ngưỡng mặc định lấy từ device/src/main.cpp
// ==========================================
class _Thresholds {
  static const double dustHigh = 150.0;  // µg/m³ — mức nguy hiểm
  static const double dustMed  = 75.0;   // µg/m³ — mức cảnh báo
  static const double gasHigh  = 800.0;  // ppm   — mức nguy hiểm
  static const double gasMed   = 400.0;  // ppm   — mức cảnh báo
}

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

  // Theo dõi cảnh báo đã hiển thị để không spam SnackBar
  bool _alertShownThisSession = false;

  bool _showAlertLogs = true;
  List<dynamic> _alertLogs = [];
  List<dynamic> _thresholdLogs = [];
  bool _isLoadingLogs = false;

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

  /// Kiểm tra bụi mịn có vượt ngưỡng không
  bool get _isDustAlert => _currentData.dustUg > _Thresholds.dustHigh;
  bool get _isDustWarning =>
      !_isDustAlert && _currentData.dustUg > _Thresholds.dustMed;

  /// Kiểm tra khí gas có vượt ngưỡng không
  bool get _isGasAlert => _currentData.gasPpm > _Thresholds.gasHigh;
  bool get _isGasWarning =>
      !_isGasAlert && _currentData.gasPpm > _Thresholds.gasMed;

  /// true nếu có bất kỳ cảm biến nào vượt ngưỡng cao (nguy hiểm)
  bool get _hasHighAlert => _isDustAlert || _isGasAlert;

  /// true nếu có cảm biến vượt ngưỡng trung (cảnh báo)
  bool get _hasWarning => _isDustWarning || _isGasWarning;

  /// Hiển thị SnackBar cảnh báo — chỉ 1 lần mỗi phiên vượt ngưỡng
  void _maybeShowAlertSnackBar() {
    if (!mounted) return;

    if (_hasHighAlert && !_alertShownThisSession) {
      _alertShownThisSession = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isDustAlert && _isGasAlert
                      ? 'Bụi mịn & khí gas vượt ngưỡng nguy hiểm!'
                      : _isDustAlert
                          ? 'Bụi mịn vượt ngưỡng nguy hiểm!'
                          : 'Khí gas vượt ngưỡng nguy hiểm!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (!_hasHighAlert) {
      // Reset để cảnh báo lại nếu về bình thường rồi vượt tiếp
      _alertShownThisSession = false;
    }
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
        // Kiểm tra và hiển thị cảnh báo sau khi cập nhật state
        _maybeShowAlertSnackBar();
      });

      final telemetry = await _tbService.getLatestTelemetry();
      if (telemetry != null) {
        setState(() {
          _currentData = EnvironmentData.fromThingsBoard(telemetry, _currentData);
          _isLoading = false;
        });
        _maybeShowAlertSnackBar();
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

  Future<void> _fetchLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final alerts = await _tbService.fetchAlertHistory();
      final thresholds = await _tbService.fetchThresholdHistory();
      setState(() {
        _alertLogs = alerts ?? [];
        _thresholdLogs = thresholds ?? [];
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _handleMistChange(bool enabled) async {
    if (_currentData.autoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tắt chế độ tự động để điều chỉnh phun sương'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final oldMistOn = _currentData.mistOn;

    setState(() {
      _currentData = EnvironmentData(
        temperature: _currentData.temperature,
        humidity: _currentData.humidity,
        dustUg: _currentData.dustUg,
        gasPpm: _currentData.gasPpm,
        autoMode: _currentData.autoMode,
        fanLevel: _currentData.fanLevel,
        mistOn: enabled,
        waterLow: _currentData.waterLow,
      );
    });

    final success = await _tbService.setMist(enabled);
    if (!success) {
      if (mounted) {
        setState(() {
          _currentData = EnvironmentData(
            temperature: _currentData.temperature,
            humidity: _currentData.humidity,
            dustUg: _currentData.dustUg,
            gasPpm: _currentData.gasPpm,
            autoMode: _currentData.autoMode,
            fanLevel: _currentData.fanLevel,
            mistOn: oldMistOn,
            waterLow: _currentData.waterLow,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể thay đổi trạng thái phun sương'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleAutoModeChange(bool enabled) async {
    final oldAutoMode = _currentData.autoMode;

    // Optimistically update the UI state
    setState(() {
      _currentData = EnvironmentData(
        temperature: _currentData.temperature,
        humidity: _currentData.humidity,
        dustUg: _currentData.dustUg,
        gasPpm: _currentData.gasPpm,
        autoMode: enabled,
        fanLevel: _currentData.fanLevel,
        mistOn: _currentData.mistOn,
        waterLow: _currentData.waterLow,
      );
    });

    final success = await _tbService.setAutoMode(enabled);
    if (!success) {
      // Rollback to previous state on failure
      if (mounted) {
        setState(() {
          _currentData = EnvironmentData(
            temperature: _currentData.temperature,
            humidity: _currentData.humidity,
            dustUg: _currentData.dustUg,
            gasPpm: _currentData.gasPpm,
            autoMode: oldAutoMode,
            fanLevel: _currentData.fanLevel,
            mistOn: _currentData.mistOn,
            waterLow: _currentData.waterLow,
          );
        });
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
    if (_currentData.autoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tắt chế độ tự động để điều chỉnh quạt'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final oldFanLevel = _currentData.fanLevel;

    // Optimistically update the UI state
    setState(() {
      _currentData = EnvironmentData(
        temperature: _currentData.temperature,
        humidity: _currentData.humidity,
        dustUg: _currentData.dustUg,
        gasPpm: _currentData.gasPpm,
        autoMode: _currentData.autoMode,
        fanLevel: level,
        mistOn: _currentData.mistOn,
        waterLow: _currentData.waterLow,
      );
    });

    final success = await _tbService.setFanLevel(level);
    if (!success) {
      // Rollback to previous state on failure
      if (mounted) {
        setState(() {
          _currentData = EnvironmentData(
            temperature: _currentData.temperature,
            humidity: _currentData.humidity,
            dustUg: _currentData.dustUg,
            gasPpm: _currentData.gasPpm,
            autoMode: _currentData.autoMode,
            fanLevel: oldFanLevel,
            mistOn: _currentData.mistOn,
            waterLow: _currentData.waterLow,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể thay đổi mức quạt'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Banner cảnh báo hiển thị ở đầu tab Tổng quan
  Widget _buildAlertBanner() {
    if (!_hasHighAlert && !_hasWarning) return const SizedBox.shrink();

    final isHigh = _hasHighAlert;
    final bgColor = isHigh
        ? Colors.red.shade700
        : Colors.orange.shade800;
    final icon = isHigh ? Icons.dangerous_rounded : Icons.warning_amber_rounded;

    final messages = <String>[];
    if (_isDustAlert) {
      messages.add('Bụi mịn ${_currentData.dustUg.toStringAsFixed(0)} µg/m³ (ngưỡng ${_Thresholds.dustHigh.toInt()})');
    } else if (_isDustWarning) {
      messages.add('Bụi mịn ${_currentData.dustUg.toStringAsFixed(0)} µg/m³ (ngưỡng ${_Thresholds.dustMed.toInt()})');
    }
    if (_isGasAlert) {
      messages.add('Khí gas ${_currentData.gasPpm.toStringAsFixed(0)} ppm (ngưỡng ${_Thresholds.gasHigh.toInt()})');
    } else if (_isGasWarning) {
      messages.add('Khí gas ${_currentData.gasPpm.toStringAsFixed(0)} ppm (ngưỡng ${_Thresholds.gasMed.toInt()})');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHigh ? '⚠ MỨC NGUY HIỂM' : '⚠ CẢNH BÁO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                ...messages.map((m) => Text(
                      m,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final telemetry = await _tbService.getLatestTelemetry();
        if (telemetry != null && mounted) {
          setState(() {
            _currentData = EnvironmentData.fromThingsBoard(telemetry, _currentData);
          });
          _maybeShowAlertSnackBar();
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
              // Banner cảnh báo vượt ngưỡng
              _buildAlertBanner(),
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
                      // Nhiệt độ chưa có ngưỡng định nghĩa trong C++
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
                      isAlert: _isDustAlert,
                      isWarning: _isDustWarning,
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
                      isAlert: _isGasAlert,
                      isWarning: _isGasWarning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SensorCard(
                      title: 'Mực nước',
                      value: _currentData.waterLow ? 'CẠN' : 'ĐẦY',
                      unit: '',
                      icon: Icons.water,
                      valueColor: _currentData.waterLow ? Colors.redAccent : Colors.tealAccent,
                      isDarkMode: _isDarkMode,
                      isAlert: _currentData.waterLow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SensorCard(
                      title: 'Phun sương',
                      value: _currentData.mistOn ? 'BẬT' : 'TẮT',
                      unit: '',
                      icon: Icons.blur_on,
                      valueColor: _currentData.mistOn ? Colors.tealAccent : Colors.grey,
                      isDarkMode: _isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ControlPanel(
                autoMode: _currentData.autoMode,
                fanLevel: _currentData.fanLevel,
                mistOn: _currentData.mistOn,
                onAutoModeChanged: _handleAutoModeChange,
                onFanLevelChanged: (level) => _handleFanLevelChange(level.round()),
                onMistChanged: _handleMistChange,
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

  Widget _buildThresItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLogsTab() {
    return _isLoadingLogs
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchLogs,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showAlertLogs = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showAlertLogs
                                ? (_isDarkMode ? Colors.tealAccent : Colors.blue)
                                : (_isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade200),
                            foregroundColor: _showAlertLogs
                                ? Colors.black
                                : (_isDarkMode ? Colors.white : Colors.black87),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Nhật ký cảnh báo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showAlertLogs = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_showAlertLogs
                                ? (_isDarkMode ? Colors.tealAccent : Colors.blue)
                                : (_isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade200),
                            foregroundColor: !_showAlertLogs
                                ? Colors.black
                                : (_isDarkMode ? Colors.white : Colors.black87),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Thay đổi ngưỡng'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_showAlertLogs) ...[
                    if (_alertLogs.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Không có lịch sử cảnh báo nào.')))
                    else
                      ..._alertLogs.map((log) {
                        final isResolved = log['resolved'] == true;
                        final severity = log['severity'];
                        final alertColor = severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent;
                        final String timeStr = log['timestamp'] != null
                            ? DateTime.parse(log['timestamp']).toLocal().toString().substring(0, 19)
                            : '';
                        final String resolvedTimeStr = log['resolvedAt'] != null
                            ? DateTime.parse(log['resolvedAt']).toLocal().toString().substring(11, 19)
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isResolved
                                  ? (_isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200)
                                  : alertColor,
                              width: isResolved ? 1.0 : 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        log['alertType'] == 'WATER_LOW'
                                            ? Icons.water
                                            : log['alertType'] == 'DUST'
                                                ? Icons.air
                                                : log['alertType'] == 'GAS'
                                                    ? Icons.eco
                                                    : Icons.thermostat,
                                        color: alertColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        log['alertType'] ?? '',
                                        style: TextStyle(
                                          color: _isDarkMode ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isResolved
                                          ? Colors.green.withOpacity(0.2)
                                          : alertColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isResolved ? 'ĐÃ KHẮC PHỤC' : 'HOẠT ĐỘNG',
                                      style: TextStyle(
                                        color: isResolved ? Colors.green : alertColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                log['message'] ?? '',
                                style: TextStyle(
                                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (log['value'] != null)
                                Text(
                                  'Giá trị đo: ${log['value']} (Ngưỡng: ${log['thresholdValue']})',
                                  style: TextStyle(
                                    color: _isDarkMode ? Colors.grey : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Divider(color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Bắt đầu: $timeStr',
                                    style: TextStyle(
                                      color: _isDarkMode ? Colors.grey : Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isResolved)
                                    Text(
                                      'Kết thúc: $resolvedTimeStr',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ] else ...[
                    if (_thresholdLogs.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Không có lịch sử thay đổi ngưỡng.')))
                    else
                      ..._thresholdLogs.map((log) {
                        final String timeStr = log['timestamp'] != null
                            ? DateTime.parse(log['timestamp']).toLocal().toString().substring(0, 19)
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.edit_road_rounded, color: _isDarkMode ? Colors.tealAccent : Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cập nhật ngưỡng thiết bị',
                                    style: TextStyle(
                                      color: _isDarkMode ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (log['dustHigh'] != null)
                                    _buildThresItem('Bụi (Cao)', '${log['dustHigh']}'),
                                  if (log['dustMed'] != null)
                                    _buildThresItem('Bụi (Vừa)', '${log['dustMed']}'),
                                  if (log['gasHigh'] != null)
                                    _buildThresItem('Gas (Cao)', '${log['gasHigh']}'),
                                  if (log['gasMed'] != null)
                                    _buildThresItem('Gas (Vừa)', '${log['gasMed']}'),
                                  if (log['tempHigh'] != null)
                                    _buildThresItem('Nhiệt độ', '${log['tempHigh']}°C'),
                                  if (log['humLow'] != null)
                                    _buildThresItem('Độ ẩm', '${log['humLow']}%'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200),
                              const SizedBox(height: 4),
                              Text(
                                'Thời gian áp dụng: $timeStr',
                                style: TextStyle(
                                  color: _isDarkMode ? Colors.grey : Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ]
                ],
              ),
            ),
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
                    ['Tổng quan', 'Biểu đồ', 'Nhật ký', 'Cài đặt'][_currentIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Chỉ báo nguy hiểm trên title bar
                  if (_hasHighAlert || _hasWarning) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _hasHighAlert ? Colors.redAccent : Colors.orangeAccent,
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildOverviewTab(),
                  _buildChartsTab(),
                  _buildLogsTab(),
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
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 2) {
              _fetchLogs();
            }
          },
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
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Nhật ký',
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
