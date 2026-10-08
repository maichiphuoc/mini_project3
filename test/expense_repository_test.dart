import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spend_lens/core/expense.dart';
import 'package:spend_lens/data/expense_repository.dart';

void main() {
  late Directory directory;
  late ExpenseRepository repository;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.current.createTemp('spendlens_db_test_');
    databasePath = p.join(directory.path, 'expenses.db');
    repository = ExpenseRepository(databasePath: databasePath);
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('SQLite CRUD lưu số tiền, danh mục, ảnh và OCR text', () async {
    expect(await repository.all(), isEmpty);
    final id = await repository.insert(Expense(
      merchant: 'Mộc Cafe',
      amount: 50000,
      date: DateTime(2026, 10, 8),
      category: ExpenseCategory.food,
      imagePath: '/receipt.jpg',
      thumbnailPath: '/thumb.jpg',
      rawOcrText: 'TỔNG 50.000',
    ));
    var rows = await repository.all();
    expect(rows, hasLength(1));
    expect(rows.single.id, id);
    expect(rows.single.amount, 50000);
    expect(rows.single.imagePath, '/receipt.jpg');
    expect(rows.single.thumbnailPath, '/thumb.jpg');
    expect(rows.single.rawOcrText, 'TỔNG 50.000');

    await repository.update(Expense(
      id: id,
      merchant: 'Mộc Cafe',
      amount: 60000,
      date: DateTime(2026, 10, 8),
      category: ExpenseCategory.study,
      note: 'Đã sửa',
    ));
    rows = await repository.all();
    expect(rows.single.amount, 60000);
    expect(rows.single.category, ExpenseCategory.study);
    expect(rows.single.note, 'Đã sửa');

    await repository.delete(id);
    expect(await repository.all(), isEmpty);
  });

  test('dữ liệu vẫn tồn tại khi đóng và mở lại database', () async {
    await repository.insert(Expense(
      merchant: 'Nhà sách',
      amount: 75000,
      date: DateTime(2026, 10, 7),
      category: ExpenseCategory.study,
    ));
    await repository.close();
    repository = ExpenseRepository(databasePath: databasePath);
    expect((await repository.all()).single.merchant, 'Nhà sách');
  });

  test('giao dịch được sắp theo ngày mới nhất', () async {
    for (final day in [7, 9, 8]) {
      await repository.insert(Expense(
        merchant: 'Ngày $day',
        amount: 1000 * day,
        date: DateTime(2026, 10, day),
        category: ExpenseCategory.food,
      ));
    }
    expect((await repository.all()).map((e) => e.merchant),
        ['Ngày 9', 'Ngày 8', 'Ngày 7']);
  });

  test('SQLite không nhận số tiền không hợp lệ', () async {
    expect(
      () => repository.insert(Expense(
        merchant: 'Sai',
        amount: 0,
        date: DateTime(2026, 10, 8),
        category: ExpenseCategory.food,
      )),
      throwsA(isA<DatabaseException>()),
    );
  });
}
