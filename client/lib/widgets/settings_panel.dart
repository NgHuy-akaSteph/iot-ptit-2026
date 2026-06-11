import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../screen/login_screen.dart';

class SettingsPanel extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final double dustHigh;
  final double dustMed;
  final double gasHigh;
  final double gasMed;
  final double tempHigh;
  final double humLow;
  final Future<bool> Function(Map<String, double>) onThresholdsSaved;

  const SettingsPanel({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.dustHigh,
    required this.dustMed,
    required this.gasHigh,
    required this.gasMed,
    required this.tempHigh,
    required this.humLow,
    required this.onThresholdsSaved,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final _authService = AuthService();
  late double _dustHigh;
  late double _dustMed;
  late double _gasHigh;
  late double _gasMed;
  late double _tempHigh;
  late double _humLow;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dustHigh = widget.dustHigh;
    _dustMed = widget.dustMed;
    _gasHigh = widget.gasHigh;
    _gasMed = widget.gasMed;
    _tempHigh = widget.tempHigh;
    _humLow = widget.humLow;
  }

  @override
  void didUpdateWidget(SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dustHigh != widget.dustHigh) _dustHigh = widget.dustHigh;
    if (oldWidget.dustMed != widget.dustMed) _dustMed = widget.dustMed;
    if (oldWidget.gasHigh != widget.gasHigh) _gasHigh = widget.gasHigh;
    if (oldWidget.gasMed != widget.gasMed) _gasMed = widget.gasMed;
    if (oldWidget.tempHigh != widget.tempHigh) _tempHigh = widget.tempHigh;
    if (oldWidget.humLow != widget.humLow) _humLow = widget.humLow;
  }

  Future<void> _handleLogout() async {
    final nav = Navigator.of(context);
    final darkMode = widget.isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text(
          'Đăng xuất',
          style: TextStyle(color: darkMode ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất?',
          style: TextStyle(color: darkMode ? Colors.grey : Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _saveThresholds() async {
    setState(() => _isSaving = true);
    final success = await widget.onThresholdsSaved({
      'dustHigh': _dustHigh,
      'dustMed': _dustMed,
      'gasHigh': _gasHigh,
      'gasMed': _gasMed,
      'tempHigh': _tempHigh,
      'humLow': _humLow,
    });
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Lưu cấu hình thành công!' : 'Lưu cấu hình thất bại!'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildThresholdAdjuster({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.grey : Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.tealAccent : Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
          activeColor: widget.isDarkMode ? Colors.tealAccent : Colors.teal,
          inactiveColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Theme toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: widget.isDarkMode ? Colors.tealAccent : Colors.teal,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isDarkMode ? 'Chế độ tối' : 'Chế độ sáng',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: widget.isDarkMode,
                  onChanged: (value) => widget.onThemeChanged(value),
                  activeTrackColor: Colors.tealAccent,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Thresholds configuration card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấu hình ngưỡng cảnh báo',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildThresholdAdjuster(
                  label: 'Bụi mịn nguy hiểm (dustHigh) - µg/m³',
                  value: _dustHigh,
                  min: 50.0,
                  max: 300.0,
                  step: 5.0,
                  onChanged: (val) => setState(() => _dustHigh = val),
                ),
                _buildThresholdAdjuster(
                  label: 'Bụi mịn cảnh báo (dustMed) - µg/m³',
                  value: _dustMed,
                  min: 20.0,
                  max: 150.0,
                  step: 5.0,
                  onChanged: (val) => setState(() => _dustMed = val),
                ),
                const Divider(),
                _buildThresholdAdjuster(
                  label: 'Khí gas nguy hiểm (gasHigh) - ppm',
                  value: _gasHigh,
                  min: 400.0,
                  max: 1500.0,
                  step: 25.0,
                  onChanged: (val) => setState(() => _gasHigh = val),
                ),
                _buildThresholdAdjuster(
                  label: 'Khí gas cảnh báo (gasMed) - ppm',
                  value: _gasMed,
                  min: 100.0,
                  max: 600.0,
                  step: 25.0,
                  onChanged: (val) => setState(() => _gasMed = val),
                ),
                const Divider(),
                _buildThresholdAdjuster(
                  label: 'Nhiệt độ cao (tempHigh) - °C',
                  value: _tempHigh,
                  min: 20.0,
                  max: 50.0,
                  step: 1.0,
                  onChanged: (val) => setState(() => _tempHigh = val),
                ),
                _buildThresholdAdjuster(
                  label: 'Độ ẩm thấp (humLow) - %',
                  value: _humLow,
                  min: 20.0,
                  max: 80.0,
                  step: 1.0,
                  onChanged: (val) => setState(() => _humLow = val),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveThresholds,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDarkMode ? Colors.tealAccent : Colors.teal,
                      foregroundColor: widget.isDarkMode ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu cấu hình', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // App info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin ứng dụng',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Phiên bản',
                  value: '1.0.0',
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Thiết bị',
                  value: 'ESP32',
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Nền tảng',
                  value: 'ThingsBoard Cloud',
                  isDarkMode: widget.isDarkMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.grey : Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
