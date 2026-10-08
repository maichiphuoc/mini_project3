import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/expense.dart';
import '../data/expense_repository.dart';
import '../services/receipt_image_store.dart';
import '../services/receipt_ocr_service.dart';
import '../services/receipt_parser.dart';

final repositoryProvider =
    Provider<ExpenseRepository>((ref) => ExpenseRepository());
final imageStoreProvider =
    Provider<ReceiptImageStore>((ref) => ReceiptImageStore());
final ocrProvider = Provider<ReceiptOcrService>((ref) {
  final service = ReceiptOcrService(ReceiptParser());
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  return ref.watch(repositoryProvider).all();
});

Future<void> refreshExpenses(WidgetRef ref) async {
  ref.invalidate(expensesProvider);
  await ref.read(expensesProvider.future);
}
