import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/expense.dart';

class ExpenseRepository {
  ExpenseRepository({this.databasePath});

  final String? databasePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = databasePath == null ? await getDatabasesPath() : null;
    _database = await openDatabase(
      databasePath ?? p.join(root!, 'spendlens.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount > 0),
            date INTEGER NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            image_path TEXT,
            thumbnail_path TEXT,
            raw_ocr_text TEXT
          )
        ''');
        await db
            .execute('CREATE INDEX idx_expenses_date ON expenses(date DESC)');
      },
    );
    return _database!;
  }

  Future<List<Expense>> all() async {
    final rows =
        await (await database).query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> insert(Expense expense) async =>
      (await database).insert('expenses', expense.toMap());

  Future<void> update(Expense expense) async {
    if (expense.id == null) throw ArgumentError('Expense id is required');
    await (await database).update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<void> delete(int id) async =>
      (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
