import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/expense.dart';
import '../core/formatters.dart';
import '../services/receipt_parser.dart';
import '../state/providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen(
      {super.key, this.existing, this.parsed, this.imagePath});
  final Expense? existing;
  final ReceiptParseResult? parsed;
  final String? imagePath;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final key = GlobalKey<FormState>();
  late final TextEditingController merchant;
  late final TextEditingController amount;
  late final TextEditingController note;
  late DateTime date;
  ExpenseCategory? category;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    merchant = TextEditingController(
        text: widget.existing?.merchant ?? widget.parsed?.merchant ?? '');
    amount = TextEditingController(
        text: (widget.existing?.amount ?? widget.parsed?.amount)?.toString() ??
            '');
    note = TextEditingController(text: widget.existing?.note ?? '');
    date = widget.existing?.date ?? widget.parsed?.date ?? DateTime.now();
    category = widget.existing?.category ?? widget.parsed?.category;
  }

  @override
  void dispose() {
    merchant.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !(key.currentState?.validate() ?? false)) return;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn danh mục.')));
      return;
    }
    setState(() => saving = true);
    String? newImage;
    String? newThumbnail;
    try {
      if (widget.existing == null && widget.imagePath != null) {
        final stored =
            await ref.read(imageStoreProvider).persist(widget.imagePath!);
        newImage = stored.imagePath;
        newThumbnail = stored.thumbnailPath;
      }
      final expense = Expense(
        id: widget.existing?.id,
        merchant: merchant.text.trim(),
        amount: int.parse(amount.text.trim()),
        date: date,
        category: category!,
        note: note.text.trim(),
        imagePath: newImage ?? widget.existing?.imagePath,
        thumbnailPath: newThumbnail ?? widget.existing?.thumbnailPath,
        rawOcrText: widget.parsed?.rawText ?? widget.existing?.rawOcrText,
      );
      final repository = ref.read(repositoryProvider);
      if (widget.existing == null) {
        await repository.insert(expense);
      } else {
        await repository.update(expense);
      }
      await refreshExpenses(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (newImage != null) {
        await ref.read(imageStoreProvider).delete(newImage, newThumbnail);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể lưu giao dịch. Vui lòng thử lại.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.parsed;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing != null
              ? 'Sửa chi tiêu'
              : parsed != null
                  ? 'Kiểm tra hóa đơn'
                  : 'Thêm chi tiêu')),
      body: SafeArea(
          child: Form(
        key: key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            if (widget.imagePath != null || widget.existing?.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                    File(widget.imagePath ?? widget.existing!.imagePath!),
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                        height: 80,
                        child:
                            Center(child: Text('Không thể mở ảnh hóa đơn')))),
              ),
            if (parsed != null && parsed.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                  color: const Color(0xFFFFF4DA),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(parsed.warnings.join('\n'),
                        style: const TextStyle(color: Color(0xFF71540A))),
                  )),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: merchant,
              decoration: const InputDecoration(
                  labelText: 'Cửa hàng / nội dung',
                  prefixIcon: Icon(Icons.storefront_outlined)),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên cửa hàng'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amount,
              decoration: const InputDecoration(
                  labelText: 'Số tiền (VND)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: '₫'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                return parsed == null || parsed <= 0
                    ? 'Nhập số tiền nguyên dương'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Ngày: ${formatDate(date)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => date = picked);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ExpenseCategory>(
              value: category,
              decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  prefixIcon: Icon(Icons.category_outlined)),
              items: ExpenseCategory.values
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)))
                  .toList(),
              onChanged: (value) => setState(() => category = value),
              validator: (value) => value == null ? 'Chọn danh mục' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  alignLabelWithHint: true),
            ),
            if (parsed != null)
              ExpansionTile(
                title: const Text('Văn bản OCR gốc'),
                children: [
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(parsed.rawText.isEmpty
                          ? 'Không nhận diện được chữ'
                          : parsed.rawText))
                ],
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Đang lưu...' : 'Lưu chi tiêu'),
            ),
          ],
        ),
      )),
    );
  }
}
