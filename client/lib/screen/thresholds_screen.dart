import 'package:flutter/material.dart';

class ThresholdsScreen extends StatefulWidget {
  final double dustHigh;
  final double dustMed;
  final double gasHigh;
  final double gasMed;
  final double tempHigh;
  final double humLow;
  final Future<bool> Function(Map<String, double>) onThresholdsSaved;
  final bool isDarkMode;

  const ThresholdsScreen({
    super.key,
    required this.dustHigh,
    required this.dustMed,
    required this.gasHigh,
    required this.gasMed,
    required this.tempHigh,
    required this.humLow,
    required this.onThresholdsSaved,
    required this.isDarkMode,
  });

  @override
  State<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  late double _dustHigh;
  late double _dustMed;
  late double _gasHigh;
  late double _gasMed;
  late double _tempHigh;
  late double _humLow;

  // Backup values to restore when clicking Cancel
  late double _backupDustHigh;
  late double _backupDustMed;
  late double _backupGasHigh;
  late double _backupGasMed;
  late double _backupTempHigh;
  late double _backupHumLow;

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  void _loadValues() {
    _dustHigh = widget.dustHigh;
    _dustMed = widget.dustMed;
    _gasHigh = widget.gasHigh;
    _gasMed = widget.gasMed;
    _tempHigh = widget.tempHigh;
    _humLow = widget.humLow;
  }

  void _saveBackup() {
    _backupDustHigh = _dustHigh;
    _backupDustMed = _dustMed;
    _backupGasHigh = _gasHigh;
    _backupGasMed = _gasMed;
    _backupTempHigh = _tempHigh;
    _backupHumLow = _humLow;
  }

  void _restoreBackup() {
    setState(() {
      _dustHigh = _backupDustHigh;
      _dustMed = _backupDustMed;
      _gasHigh = _backupGasHigh;
      _gasMed = _backupGasMed;
      _tempHigh = _backupTempHigh;
      _humLow = _backupHumLow;
    });
  }

  Future<void> _handleSave() async {
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
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cấu hình thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cấu hình thất bại!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildThresholdAdjuster({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required Function(double) onChanged,
    required bool isDarkMode,
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
                color: isDarkMode ? Colors.grey : Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: _isEditing
                    ? (isDarkMode ? Colors.tealAccent : Colors.teal)
                    : (isDarkMode ? Colors.grey : Colors.grey.shade600),
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
          onChanged: _isEditing ? onChanged : null, // Disable slider if not editing
          activeColor: isDarkMode ? Colors.tealAccent : Colors.teal,
          inactiveColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0D0D0D) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Ngưỡng cảnh báo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () {
                _saveBackup();
                setState(() => _isEditing = true);
              },
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              label: const Text(
                'Sửa',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cấu hình ngưỡng thiết bị',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isEditing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CHẾ ĐỘ SỬA',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdAdjuster(
                    label: 'Bụi mịn nguy hiểm (dustHigh) - µg/m³',
                    value: _dustHigh,
                    min: 50.0,
                    max: 300.0,
                    step: 5.0,
                    onChanged: (val) => setState(() => _dustHigh = val),
                    isDarkMode: isDarkMode,
                  ),
                  _buildThresholdAdjuster(
                    label: 'Bụi mịn cảnh báo (dustMed) - µg/m³',
                    value: _dustMed,
                    min: 20.0,
                    max: 150.0,
                    step: 5.0,
                    onChanged: (val) => setState(() => _dustMed = val),
                    isDarkMode: isDarkMode,
                  ),
                  const Divider(),
                  _buildThresholdAdjuster(
                    label: 'Khí gas nguy hiểm (gasHigh) - ppm',
                    value: _gasHigh,
                    min: 400.0,
                    max: 1500.0,
                    step: 25.0,
                    onChanged: (val) => setState(() => _gasHigh = val),
                    isDarkMode: isDarkMode,
                  ),
                  _buildThresholdAdjuster(
                    label: 'Khí gas cảnh báo (gasMed) - ppm',
                    value: _gasMed,
                    min: 100.0,
                    max: 600.0,
                    step: 25.0,
                    onChanged: (val) => setState(() => _gasMed = val),
                    isDarkMode: isDarkMode,
                  ),
                  const Divider(),
                  _buildThresholdAdjuster(
                    label: 'Nhiệt độ cao (tempHigh) - °C',
                    value: _tempHigh,
                    min: 20.0,
                    max: 50.0,
                    step: 1.0,
                    onChanged: (val) => setState(() => _tempHigh = val),
                    isDarkMode: isDarkMode,
                  ),
                  _buildThresholdAdjuster(
                    label: 'Độ ẩm thấp (humLow) - %',
                    value: _humLow,
                    min: 20.0,
                    max: 80.0,
                    step: 1.0,
                    onChanged: (val) => setState(() => _humLow = val),
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              _restoreBackup();
                              setState(() => _isEditing = false);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: isDarkMode ? Colors.grey : Colors.grey.shade400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.tealAccent : Colors.teal,
                        foregroundColor: isDarkMode ? Colors.black : Colors.white,
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
                          : const Text(
                              'Lưu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
