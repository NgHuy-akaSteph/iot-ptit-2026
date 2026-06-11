import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final bool autoMode;
  final int fanLevel;
  final bool mistOn;
  final Function(bool) onAutoModeChanged;
  final Function(double) onFanLevelChanged;
  final Function(bool) onMistChanged;
  final bool isDarkMode;

  const ControlPanel({
    super.key,
    required this.autoMode,
    required this.fanLevel,
    required this.mistOn,
    required this.onAutoModeChanged,
    required this.onFanLevelChanged,
    required this.onMistChanged,
    this.isDarkMode = true,
  });

  Widget _buildCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final segmentLabels = ['Thấp', 'Trung', 'Cao'];
    final segmentValues = [1, 2, 3];

    return Column(
      children: [
        _buildCard(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chế độ tự động',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: autoMode,
                onChanged: onAutoModeChanged,
                activeTrackColor: Colors.tealAccent,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCard(
          IgnorePointer(
            ignoring: autoMode,
            child: Opacity(
              opacity: autoMode ? 0.4 : 1.0,
              child: Row(
                children: List.generate(segmentLabels.length, (i) {
                  final isSelected = fanLevel == segmentValues[i];
                  return Expanded(
                    child: Padding(
                      padding: i == 0
                          ? const EdgeInsets.only(right: 4)
                          : i == segmentLabels.length - 1
                          ? const EdgeInsets.only(left: 4)
                          : const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () =>
                            onFanLevelChanged(segmentValues[i].toDouble()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode ? Colors.tealAccent : Colors.blue)
                                : (isDarkMode
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              segmentLabels[i],
                              style: TextStyle(
                                color: isSelected
                                    ? (isDarkMode
                                          ? Colors.black87
                                          : Colors.white)
                                    : (isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600),
                                fontSize: 20,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildCard(
          IgnorePointer(
            ignoring: autoMode,
            child: Opacity(
              opacity: autoMode ? 0.4 : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bơm phun sương',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: mistOn,
                    onChanged: onMistChanged,
                    activeTrackColor: Colors.tealAccent,
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
