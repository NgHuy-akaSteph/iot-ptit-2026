import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../screen/login_screen.dart';
import '../screen/thresholds_screen.dart';

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

          // Thresholds configuration card (Navigation tile)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ThresholdsScreen(
                    dustHigh: widget.dustHigh,
                    dustMed: widget.dustMed,
                    gasHigh: widget.gasHigh,
                    gasMed: widget.gasMed,
                    tempHigh: widget.tempHigh,
                    humLow: widget.humLow,
                    onThresholdsSaved: widget.onThresholdsSaved,
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              );
            },
            child: Container(
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
                        Icons.tune,
                        color: widget.isDarkMode ? Colors.tealAccent : Colors.teal,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cấu hình ngưỡng',
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bụi mịn, khí gas, nhiệt độ, độ ẩm',
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.grey : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: widget.isDarkMode ? Colors.grey : Colors.grey.shade400,
                  ),
                ],
              ),
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
