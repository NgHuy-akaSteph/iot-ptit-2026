import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class RadialGaugeWidget extends StatelessWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final String title;
  final String unit;
  final IconData icon;
  final Color arcColor;
  final bool isDarkMode;

  const RadialGaugeWidget({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.title,
    required this.unit,
    required this.icon,
    required this.arcColor,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.clamp(minValue, maxValue);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: arcColor,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 160,
            child: SfRadialGauge(
              enableLoadingAnimation: true,
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: minValue,
                  maximum: maxValue,
                  startAngle: 150,
                  endAngle: 30,
                  radiusFactor: 0.8,
                  interval: (maxValue - minValue) / 5,
                  showTicks: false,
                  showLabels: true,
                  axisLineStyle: AxisLineStyle(
                    thickness: 0.15,
                    cornerStyle: CornerStyle.bothCurve,
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.grey.shade200,
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  axisLabelStyle: GaugeTextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 10,
                  ),
                  pointers: <GaugePointer>[
                    MarkerPointer(
                      value: displayValue,
                      markerType: MarkerType.circle,
                      color: arcColor,
                      markerWidth: 14,
                      markerHeight: 14,
                      elevation: 2,
                      enableAnimation: true,
                    ),
                  ],
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: minValue,
                      endValue: displayValue,
                      color: arcColor,
                      startWidth: 0.15,
                      endWidth: 0.15,
                      sizeUnit: GaugeSizeUnit.factor,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayValue.toStringAsFixed(1),
                            style: TextStyle(
                              color: arcColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            unit,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      angle: 90,
                      positionFactor: 0.75,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
