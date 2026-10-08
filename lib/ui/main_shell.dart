import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/expense.dart';
import '../core/formatters.dart';
import '../state/providers.dart';
import 'charts.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';
import 'scanner_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
          onHistory: () => setState(() => index = 1),
          onScan: () => setState(() => index = 2)),
      const HistoryScreen(),
      ScannerScreen(onSaved: () => setState(() => index = 0)),
      const AnalyticsScreen(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Lịch sử'),
          NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner),
              label: 'Quét'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Thống kê'),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onHistory, required this.onScan});
  final VoidCallback onHistory;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SpendLens'), actions: [
        IconButton(
            onPressed: () => ref.invalidate(expensesProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới'),
      ]),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Không thể tải dữ liệu.'),
          TextButton(
              onPressed: () => ref.invalidate(expensesProvider),
              child: const Text('Thử lại')),
        ])),
        data: (expenses) {
          final now = DateTime.now();
          final monthly = expenses
              .where((item) =>
                  item.date.year == now.year && item.date.month == now.month)
              .toList();
          final monthTotal =
              monthly.fold<int>(0, (sum, item) => sum + item.amount);
          final todayTotal = monthly
              .where((item) => item.date.day == now.day)
              .fold<int>(0, (sum, item) => sum + item.amount);
          final categories = totalsByCategory(monthly);
          final top = categories.entries
              .where((entry) => entry.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return RefreshIndicator(
            onRefresh: () => refreshExpenses(ref),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('Xin chào 👋',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Chi tiêu tháng ${now.month}/${now.year}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                  color: const Color(0xFF0C8F6B),
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tổng tháng này',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(formatVnd(monthTotal),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                  child: _metric(
                                      'Hôm nay', formatVnd(todayTotal))),
                              Expanded(
                                  child: _metric(
                                      'Giao dịch', '${monthly.length}')),
                            ]),
                          ]))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: FilledButton.icon(
                        onPressed: onScan,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('Quét hóa đơn'))),
                const SizedBox(width: 8),
                IconButton.outlined(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpenseFormScreen())),
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm thủ công'),
              ]),
              const SizedBox(height: 20),
              if (expenses.isEmpty)
                const _EmptyState(
                    'Chưa có giao dịch. Quét hóa đơn hoặc thêm chi tiêu đầu tiên.'),
              if (expenses.isNotEmpty) ...[
                _section(context, 'Phân bố tháng này'),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Center(child: DonutChart(totals: categories)),
                          Text(top.isEmpty
                              ? 'Chưa có chi tiêu trong tháng'
                              : 'Cao nhất: ${top.first.key.label}'),
                        ]))),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _section(context, 'Giao dịch gần đây')),
                  TextButton(
                      onPressed: onHistory, child: const Text('Xem tất cả'))
                ]),
                ...expenses.take(5).map((item) => ExpenseTile(expense: item)),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _metric(String title, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ]);
}

Widget _section(BuildContext context, String title) => Text(title,
    style: Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.bold));

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});
  final Expense expense;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: expense.thumbnailPath == null
            ? CircleAvatar(
                backgroundColor:
                    categoryColors[expense.category]!.withOpacity(.12),
                child: Icon(Icons.receipt_long,
                    color: categoryColors[expense.category]))
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(expense.thumbnailPath!),
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.receipt_long))),
        title: Text(expense.merchant,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('${expense.category.label} · ${formatDate(expense.date)}'),
        trailing: Text(formatVnd(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ExpenseDetailScreen(expense: expense))),
      ));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(children: [
        const Icon(Icons.receipt_long_outlined,
            size: 64, color: Color(0xFF9EB6AC)),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge),
      ]));
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String search = '';
  ExpenseCategory? category;
  DateTimeRange? range;
  String sort = 'newest';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chi tiêu')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Tìm cửa hàng'),
              onChanged: (value) =>
                  setState(() => search = value.trim().toLowerCase()),
            )),
        SizedBox(
            height: 48,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  DropdownButton<ExpenseCategory?>(
                      value: category,
                      hint: const Text('Tất cả danh mục'),
                      items: [
                        const DropdownMenuItem<ExpenseCategory?>(
                            value: null, child: Text('Tất cả danh mục')),
                        ...ExpenseCategory.values.map((item) =>
                            DropdownMenuItem(
                                value: item, child: Text(item.label))),
                      ],
                      onChanged: (value) => setState(() => category = value)),
                  const SizedBox(width: 16),
                  TextButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(range == null
                          ? 'Chọn ngày'
                          : '${formatDate(range!.start)}–${formatDate(range!.end)}'),
                      onPressed: () async {
                        final result = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (result != null) setState(() => range = result);
                      }),
                  if (range != null)
                    IconButton(
                        onPressed: () => setState(() => range = null),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Bỏ lọc ngày'),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                      value: sort,
                      items: const [
                        DropdownMenuItem(
                            value: 'newest', child: Text('Mới nhất')),
                        DropdownMenuItem(
                            value: 'oldest', child: Text('Cũ nhất')),
                        DropdownMenuItem(
                            value: 'high', child: Text('Tiền cao nhất')),
                        DropdownMenuItem(
                            value: 'low', child: Text('Tiền thấp nhất')),
                      ],
                      onChanged: (value) => setState(() => sort = value!)),
                ])),
        Expanded(
            child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(expensesProvider),
                  child: const Text('Không thể tải dữ liệu. Thử lại'))),
          data: (items) {
            final filtered = items.where((item) {
              if (!item.merchant.toLowerCase().contains(search)) return false;
              if (category != null && item.category != category) return false;
              if (range != null) {
                final day =
                    DateTime(item.date.year, item.date.month, item.date.day);
                if (day.isBefore(range!.start) || day.isAfter(range!.end)) {
                  return false;
                }
              }
              return true;
            }).toList();
            filtered.sort((a, b) => switch (sort) {
                  'oldest' => a.date.compareTo(b.date),
                  'high' => b.amount.compareTo(a.amount),
                  'low' => a.amount.compareTo(b.amount),
                  _ => b.date.compareTo(a.date),
                });
            if (filtered.isEmpty) {
              return const _EmptyState('Không có giao dịch phù hợp.');
            }
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    ExpenseTile(expense: filtered[index]));
          },
        )),
      ]),
    );
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String period = 'month';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: TextButton(
                onPressed: () => ref.invalidate(expensesProvider),
                child: const Text('Không thể tải dữ liệu. Thử lại'))),
        data: (all) {
          final now = DateTime.now();
          final currentWeek = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          final filtered = all
              .where((item) => switch (period) {
                    'week' => !item.date.isBefore(currentWeek),
                    'all' => true,
                    _ => item.date.year == now.year &&
                        item.date.month == now.month,
                  })
              .toList();
          final total = filtered.fold<int>(0, (sum, item) => sum + item.amount);
          final byCategory = totalsByCategory(filtered);
          final weekly = totalsByWeekday(all, now);
          return ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButton<String>(
                value: period,
                items: const [
                  DropdownMenuItem(value: 'week', child: Text('Tuần này')),
                  DropdownMenuItem(value: 'month', child: Text('Tháng này')),
                  DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                ],
                onChanged: (value) => setState(() => period = value!)),
            const SizedBox(height: 12),
            Card(
                color: const Color(0xFF0C8F6B),
                child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tổng chi tiêu trong kỳ',
                              style: TextStyle(color: Colors.white70)),
                          Text(formatVnd(total),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                          Text('${filtered.length} giao dịch',
                              style: const TextStyle(color: Colors.white70)),
                        ]))),
            const SizedBox(height: 20),
            _section(context, 'Theo danh mục'),
            if (filtered.isEmpty)
              const _EmptyState('Chưa có chi tiêu trong kỳ này.')
            else ...[
              Center(
                  child: DonutChart(
                      totals: byCategory,
                      onCategoryTap: (category) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '${category.label}: ${formatVnd(byCategory[category] ?? 0)}')));
                      })),
              ...ExpenseCategory.values.map((category) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 6, backgroundColor: categoryColors[category]),
                    const SizedBox(width: 10),
                    Expanded(child: Text(category.label)),
                    Text(formatVnd(byCategory[category] ?? 0)),
                  ]))),
            ],
            const SizedBox(height: 24),
            _section(context, 'Chi tiêu tuần này'),
            const SizedBox(height: 12),
            WeeklyBarChart(
                amounts: weekly,
                onDayTap: (day) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text('Ngày ${day + 1}: ${formatVnd(weekly[day])}')));
                }),
          ]);
        },
      ),
    );
  }
}
