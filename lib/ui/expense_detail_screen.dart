import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/expense.dart';
import '../core/formatters.dart';
import '../state/providers.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expense});
  final Expense expense;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  late Expense expense = widget.expense;

  Future<void> edit() async {
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ExpenseFormScreen(existing: expense)));
    if (changed == true && mounted) Navigator.pop(context);
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Xóa giao dịch?'),
              content: const Text('Giao dịch và ảnh hóa đơn đã lưu sẽ bị xóa.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xóa')),
              ],
            ));
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).delete(expense.id!);
      await ref
          .read(imageStoreProvider)
          .delete(expense.imagePath, expense.thumbnailPath);
      await refreshExpenses(ref);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xóa giao dịch.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết giao dịch'), actions: [
          IconButton(
              onPressed: edit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Sửa'),
          IconButton(
              onPressed: delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa'),
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (expense.imagePath != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(expense.imagePath!),
                    height: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                        height: 80,
                        child: Center(
                            child: Text('Ảnh hóa đơn không còn tồn tại'))))),
          const SizedBox(height: 20),
          Text(expense.merchant,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(formatVnd(expense.amount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0F9D76), fontWeight: FontWeight.bold)),
          const Divider(height: 32),
          ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Ngày giao dịch'),
              subtitle: Text(formatDate(expense.date))),
          ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Danh mục'),
              subtitle: Text(expense.category.label)),
          if (expense.note.isNotEmpty)
            ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: const Text('Ghi chú'),
                subtitle: Text(expense.note)),
          if (expense.rawOcrText != null && expense.rawOcrText!.isNotEmpty)
            ExpansionTile(
              title: const Text('Văn bản OCR gốc'),
              children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(expense.rawOcrText!))
              ],
            ),
        ]),
      );
}
