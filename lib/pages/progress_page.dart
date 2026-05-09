import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/services/interview_service.dart';
import 'package:ai_interview/widgets/custom_bottom_nav.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoading = true);
    final result = await InterviewService.getDashboardMetrics();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _metrics = result['data'] as Map<String, dynamic>? ?? {};
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage =
            result['message']?.toString() ?? 'Failed to load metrics';
        _isLoading = false;
      });
    }
  }

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
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1E83FF)))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(_errorMessage!,
                                  style:
                                      const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed: _fetchMetrics,
                                  child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _buildContent(),
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

  Widget _buildContent() {
    final data = _metrics ?? {};
    final avgScore = (data['avg_score'] ?? 0).round();
    final bestScore = (data['best_score'] ?? 0).round();
    final totalMin = data['total_practice_minutes'] ?? 0;
    final totalSessions = data['total_sessions'] ?? 0;
    final trend = (data['performance_trend'] as List<dynamic>?) ?? [];
    final categories =
        (data['category_averages'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      color: const Color(0xFF1E83FF),
      onRefresh: _fetchMetrics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildTitleSection(),
            const SizedBox(height: 24),
            _buildMetricsRow(avgScore, bestScore, totalMin, totalSessions),
            const SizedBox(height: 20),
            if (trend.isNotEmpty) _buildPerformanceTrendCard(trend),
            if (trend.isNotEmpty) const SizedBox(height: 16),
            if (categories.isNotEmpty)
              _buildCategoryPerformanceCard(categories),
            if (trend.isEmpty && categories.isEmpty) _buildEmptyState(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Complete your first interview to see progress',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.black54),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined,
                size: 18, color: Color(0xFF4B5563)),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Progress',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 4),
        const Text('Track your improvement over time',
            style: TextStyle(
                fontSize: 14, color: Color.fromARGB(255, 55, 54, 54))),
      ],
    );
  }

  Widget _buildMetricsRow(
      int avgScore, int bestScore, int totalMin, int totalSessions) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Avg Score',
                value: avgScore.toString(),
                color: avgScore >= 70
                    ? Colors.green
                    : (avgScore >= 40 ? Colors.orange : Colors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Best Score',
                value: bestScore.toString(),
                color: bestScore >= 80
                    ? Colors.green
                    : (bestScore >= 50 ? Colors.orange : Colors.red),
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
                value: totalMin >= 60
                    ? '${(totalMin / 60).floor()}h ${totalMin % 60}m'
                    : '${totalMin}m',
                color: const Color(0xFF1E83FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Session numbers',
                value: totalSessions.toString(),
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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrendCard(List<dynamic> trend) {
    final points = trend.map((t) => (t['score'] as num).toDouble()).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Trend',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _LineChart(
              dataPoints: points,
              lineColor: Colors.purple,
              xLabels: trend.map((t) => t['date']?.toString() ?? '').toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPerformanceCard(Map<String, dynamic> categories) {
    final voice = (categories['voice_tone'] as num?)?.toDouble() ?? 0;
    final facial = (categories['facial_expression'] as num?)?.toDouble() ?? 0;
    final content = (categories['content_quality'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Performance',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _BarChart(
              bars: [
                _BarData(
                    label: 'Voice',
                    value: voice,
                    color: const Color(0xFF1E83FF)),
                _BarData(
                    label: 'Facial',
                    value: facial,
                    color: const Color(0xFF7B1FA2)),
                _BarData(
                    label: 'Content',
                    value: content,
                    color: const Color(0xFF6A1B9A)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Scores are out of 100',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final List<String> xLabels;

  const _LineChart({
    required this.dataPoints,
    required this.lineColor,
    required this.xLabels,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _LineChartPainter(
          dataPoints: dataPoints, lineColor: lineColor, xLabels: xLabels),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final List<String> xLabels;

  _LineChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.xLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final yAxisLabels = [0, 25, 50, 75, 100];
    final labels = xLabels.length >= 2
        ? xLabels
        : (dataPoints.length >= 2
            ? dataPoints.asMap().entries.map((e) => '#${e.key + 1}').toList()
            : ['#1', '#2']);
    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    final textStyle = const TextStyle(fontSize: 10, color: Colors.grey);
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      final tp = TextPainter(
        text: TextSpan(
            text: yAxisLabels[yAxisLabels.length - 1 - i].toString(),
            style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    for (int i = 0; i < labels.length; i++) {
      final x = labels.length > 1
          ? padding + (chartWidth / (labels.length - 1)) * i
          : padding + chartWidth / 2;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding + 8));
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = padding + (chartHeight / (yAxisLabels.length - 1)) * i;
      canvas.drawLine(
          Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints || oldDelegate.xLabels != xLabels;
}

class _BarData {
  final String label;
  final double value;
  final Color color;
  const _BarData(
      {required this.label, required this.value, required this.color});
}

class _BarChart extends StatelessWidget {
  final List<_BarData> bars;
  const _BarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _BarChartPainter(bars: bars),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_BarData> bars;
  _BarChartPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    final yAxisLabels = [0, 25, 50, 75, 100];
    final paddingL = 36.0;
    final paddingR = 16.0;
    final paddingT = 8.0;
    final paddingB = 28.0;
    final chartW = size.width - paddingL - paddingR;
    final chartH = size.height - paddingT - paddingB;

    final textStyle = TextStyle(fontSize: 10, color: Colors.grey[600]);
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Grid lines & Y labels
    for (int i = 0; i < yAxisLabels.length; i++) {
      final y = paddingT +
          (chartH / (yAxisLabels.length - 1)) * (yAxisLabels.length - 1 - i);
      canvas.drawLine(
          Offset(paddingL, y), Offset(size.width - paddingR, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: yAxisLabels[i].toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(paddingL - tp.width - 4, y - tp.height / 2));
    }

    if (bars.isEmpty) return;

    final barCount = bars.length;
    final totalGaps = barCount + 1;
    final gap = chartW / totalGaps * 0.4;
    final barWidth = (chartW - gap * totalGaps) / barCount;

    for (int i = 0; i < barCount; i++) {
      final bar = bars[i];
      final barH = (chartH * bar.value / 100).clamp(0.0, chartH);
      final x = paddingL + gap + i * (barWidth + gap);
      final y = paddingT + chartH - barH;

      final radius = Radius.circular(6);
      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barH),
        topLeft: radius,
        topRight: radius,
      );
      canvas.drawRRect(rrect, Paint()..color = bar.color);

      // Value label on top of bar
      final valTp = TextPainter(
        text: TextSpan(
          text: '${bar.value.round()}',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: bar.color),
        ),
        textDirection: TextDirection.ltr,
      );
      valTp.layout();
      valTp.paint(canvas,
          Offset(x + barWidth / 2 - valTp.width / 2, y - valTp.height - 4));

      // X label below bar
      final lblTp = TextPainter(
        text: TextSpan(text: bar.label, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      lblTp.layout();
      lblTp.paint(canvas,
          Offset(x + barWidth / 2 - lblTp.width / 2, paddingT + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    if (oldDelegate.bars.length != bars.length) return true;
    for (int i = 0; i < bars.length; i++) {
      if (oldDelegate.bars[i].value != bars[i].value) return true;
    }
    return false;
  }
}
