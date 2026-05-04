import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/widgets/custom_bottom_nav.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildAppBar(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildTitleSection(),
                    const SizedBox(height: 24),
                    _buildMetricsRow(),
                    const SizedBox(height: 20),
                    _buildPerformanceTrendCard(),
                    const SizedBox(height: 16),
                    _buildCategoryPerformanceCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: CustomBottomNav(activeRoute: AppRoutes.progress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.black54),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        // Settings button
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined,
                size: 18, color: Color(0xFF4B5563)),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progress',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Track your improvement over time',
          style:
              TextStyle(fontSize: 14, color: Color.fromARGB(255, 55, 54, 54)),
        ),
      ],
    );
  }

  Widget _buildMetricsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Avg Score',
                value: '72',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Best Score',
                value: '91',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Practice Time',
                value: '4h',
                color: const Color(0xFF1E83FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Session numbers',
                value: '3',
                color: const Color(0xFF1E83FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _buildLineChart(
              dataPoints: [100, 100],
              lineColor: Colors.purple,
              showLegend: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: _buildMultiLineChart()),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLineChart({
    required List<double> dataPoints,
    required Color lineColor,
    bool showLegend = false,
  }) {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _LineChartPainter(dataPoints: dataPoints, lineColor: lineColor),
    );
  }

  Widget _buildMultiLineChart() {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _MultiLineChartPainter(),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Facial', Colors.purple),
        const SizedBox(width: 20),
        _buildLegendItem('Voice', const Color(0xFF1E83FF)),
        const SizedBox(width: 20),
        _buildLegendItem('Content', const Color(0xFF6A1B9A)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;

  _LineChartPainter({required this.dataPoints, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final yAxisLabels = [0, 25, 50, 75, 100];
    final xAxisLabels = ['#1', '#2'];
    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Draw Y-axis labels
    final textStyle = const TextStyle(fontSize: 10, color: Colors.grey);
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: yAxisLabels[yAxisLabels.length - 1 - i].toString(),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // Draw X-axis labels
    for (int i = 0; i < xAxisLabels.length; i++) {
      final x = padding + (chartWidth / (xAxisLabels.length - 1)) * i;
      final textPainter = TextPainter(
        text: TextSpan(text: xAxisLabels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - padding + 8),
      );
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw line
    if (dataPoints.length >= 2) {
      final path = Path();
      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / (dataPoints.length - 1)) * i;
        final y = padding + chartHeight - (chartHeight * dataPoints[i] / 100);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      // Draw points
      final pointPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / (dataPoints.length - 1)) * i;
        final y = padding + chartHeight - (chartHeight * dataPoints[i] / 100);
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MultiLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yAxisLabels = [0, 25, 50, 75, 100];
    final xAxisLabels = ['#1', '#2'];
    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Draw Y-axis labels
    final textStyle = const TextStyle(fontSize: 10, color: Colors.grey);
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: yAxisLabels[yAxisLabels.length - 1 - i].toString(),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // Draw X-axis labels
    for (int i = 0; i < xAxisLabels.length; i++) {
      final x = padding + (chartWidth / (xAxisLabels.length - 1)) * i;
      final textPainter = TextPainter(
        text: TextSpan(text: xAxisLabels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - padding + 8),
      );
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw three lines: Facial (purple ~92), Voice (blue ~87), Content (dark purple ~97)
    final lines = [
      {
        'points': [92.0, 92.0],
        'color': Colors.purple,
      },
      {
        'points': [87.0, 87.0],
        'color': const Color(0xFF1E83FF),
      },
      {
        'points': [97.0, 97.0],
        'color': const Color(0xFF6A1B9A),
      },
    ];

    for (var line in lines) {
      final points = line['points'] as List<double>;
      final color = line['color'] as Color;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final x = padding + (chartWidth / (points.length - 1)) * i;
        final y = padding + chartHeight - (chartHeight * points[i] / 100);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      // Draw points
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (int i = 0; i < points.length; i++) {
        final x = padding + (chartWidth / (points.length - 1)) * i;
        final y = padding + chartHeight - (chartHeight * points[i] / 100);
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
