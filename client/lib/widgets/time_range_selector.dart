import 'package:flutter/material.dart';
import '../service/thingsboard_service.dart';

class TimeRangeSelector extends StatelessWidget {
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;
  final bool isDarkMode;

  const TimeRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isDarkMode = true,
  });

  static const _labels = {
    TimeRange.oneMinute: '1P',
    TimeRange.oneHour: '1G',
    TimeRange.oneDay: '1N',
    TimeRange.oneWeek: '1T',
  };

  static const _fullLabels = {
    TimeRange.oneMinute: '1 phút',
    TimeRange.oneHour: '1 giờ',
    TimeRange.oneDay: '1 ngày',
    TimeRange.oneWeek: '1 tuần',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TimeRange.values.map((range) {
        final isSelected = range == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => onChanged(range),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.blue.shade50)
                      : (isDarkMode
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? (isDarkMode ? Colors.white30 : Colors.blue.shade300)
                        : (isDarkMode
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey.shade200),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labels[range]!,
                      style: TextStyle(
                        color: isSelected
                            ? (isDarkMode ? Colors.white : Colors.blue.shade700)
                            : (isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade500),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      _fullLabels[range]!,
                      style: TextStyle(
                        color: isSelected
                            ? (isDarkMode
                                ? Colors.grey.shade300
                                : Colors.blue.shade600)
                            : (isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade400),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
