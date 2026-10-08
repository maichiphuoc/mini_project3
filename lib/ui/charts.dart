import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/expense.dart';

const categoryColors = <ExpenseCategory, Color>{
  ExpenseCategory.food: Color(0xFF0F9D76),
  ExpenseCategory.study: Color(0xFF397AE5),
  ExpenseCategory.travel: Color(0xFFFFB447),
  ExpenseCategory.gear: Color(0xFFAF6DD8),
  ExpenseCategory.entertainment: Color(0xFFF16E7B),
};

Map<ExpenseCategory, int> totalsByCategory(Iterable<Expense> expenses) {
  final totals = {for (final category in ExpenseCategory.values) category: 0};
  for (final expense in expenses) {
    totals[expense.category] = totals[expense.category]! + expense.amount;
  }
  return totals;
}

List<int> totalsByWeekday(Iterable<Expense> expenses, DateTime now) {
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final totals = List<int>.filled(7, 0);
  for (final expense in expenses) {
    final day =
        DateTime(expense.date.year, expense.date.month, expense.date.day);
    final index = day.difference(start).inDays;
    if (index >= 0 && index < 7) totals[index] += expense.amount;
  }
  return totals;
}

class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.totals, this.onCategoryTap});
  final Map<ExpenseCategory, int> totals;
  final ValueChanged<ExpenseCategory>? onCategoryTap;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totals != widget.totals) controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _tap(TapDownDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final point = details.localPosition - center;
    final radius = point.distance;
    if (radius < size.shortestSide * 0.25 ||
        radius > size.shortestSide * 0.48) {
      return;
    }
    final total = widget.totals.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    final angle = (math.atan2(point.dy, point.dx) + math.pi / 2 + math.pi * 2) %
        (math.pi * 2);
    var sweep = 0.0;
    for (final category in ExpenseCategory.values) {
      sweep += (widget.totals[category] ?? 0) / total * math.pi * 2;
      if (angle <= sweep) {
        widget.onCategoryTap?.call(category);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = Size(200, 200);
    return GestureDetector(
      onTapDown: (details) => _tap(details, size),
      child: SizedBox.fromSize(
        size: size,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            painter: DonutPainter(widget.totals, controller.value),
            child: const Center(
                child: Icon(Icons.pie_chart_outline,
                    color: Color(0xFF0F9D76), size: 32)),
          ),
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  DonutPainter(this.totals, this.progress);
  final Map<ExpenseCategory, int> totals;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.39;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..color = const Color(0xFFE7F1ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, radius, base);
    final total = totals.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return;
    var angle = -math.pi / 2;
    for (final category in ExpenseCategory.values) {
      final amount = totals[category] ?? 0;
      if (amount == 0) continue;
      final sweep = amount / total * math.pi * 2 * progress;
      final paint = Paint()
        ..color = categoryColors[category]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;
      canvas.drawArc(rect, angle, sweep, false, paint);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.totals != totals || oldDelegate.progress != progress;
}

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({super.key, required this.amounts, this.onDayTap});
  final List<int> amounts;
  final ValueChanged<int>? onDayTap;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void didUpdateWidget(covariant WeeklyBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amounts != widget.amounts) controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onTapDown: (details) {
            final index = (details.localPosition.dx / constraints.maxWidth * 7)
                .floor()
                .clamp(0, 6);
            widget.onDayTap?.call(index);
          },
          child: SizedBox(
            height: 184,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => CustomPaint(
                painter: BarChartPainter(widget.amounts, controller.value),
              ),
            ),
          ),
        ),
      );
}

class BarChartPainter extends CustomPainter {
  BarChartPainter(this.amounts, this.progress);
  final List<int> amounts;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final maxAmount = amounts.reduce(math.max);
    final barArea = size.height - 30;
    final cell = size.width / 7;
    final baseline = Paint()
      ..color = const Color(0xFFE3EBE7)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, barArea), Offset(size.width, barArea), baseline);
    for (var i = 0; i < 7; i++) {
      final height = maxAmount == 0
          ? 0.0
          : amounts[i] / maxAmount * (barArea - 18) * progress;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            cell * i + cell * .24, barArea - height, cell * .52, height),
        const Radius.circular(7),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFF0F9D76));
      final painter = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Color(0xFF65756F), fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas,
          Offset(cell * i + (cell - painter.width) / 2, size.height - 20));
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) =>
      oldDelegate.amounts != amounts || oldDelegate.progress != progress;
}
