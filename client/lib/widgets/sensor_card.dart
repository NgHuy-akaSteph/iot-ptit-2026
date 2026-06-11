import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color valueColor;
  final bool isDarkMode;
  // true = vượt ngưỡng cao (đỏ), false = bình thường
  final bool isAlert;
  // true = vượt ngưỡng trung (vàng)
  final bool isWarning;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.valueColor,
    this.isDarkMode = true,
    this.isAlert = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    // Xác định màu viền & màu giá trị theo trạng thái
    final Color borderColor = isAlert
        ? Colors.redAccent
        : isWarning
            ? Colors.orangeAccent
            : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200);

    final Color displayColor = isAlert
        ? Colors.redAccent
        : isWarning
            ? Colors.orangeAccent
            : valueColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert
            ? (isDarkMode
                ? const Color(0xFF2A1010)
                : Colors.red.shade50)
            : isWarning
                ? (isDarkMode
                    ? const Color(0xFF2A1E00)
                    : Colors.orange.shade50)
                : (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: (isAlert || isWarning) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: displayColor,
                size: 28,
              ),
              // Badge cảnh báo
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NGUY HIỂM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CẢNH BÁO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: displayColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
