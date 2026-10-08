enum ExpenseCategory {
  food('food', 'Ăn uống'),
  study('study', 'Học tập'),
  travel('travel', 'Di chuyển'),
  gear('gear', 'Mua sắm / Thiết bị'),
  entertainment('entertainment', 'Giải trí');

  const ExpenseCategory(this.key, this.label);
  final String key;
  final String label;

  static ExpenseCategory? fromKey(String? key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }
}

class Expense {
  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
    this.imagePath,
    this.thumbnailPath,
    this.rawOcrText,
  });

  final int? id;
  final String merchant;
  final int amount;
  final DateTime date;
  final ExpenseCategory category;
  final String note;
  final String? imagePath;
  final String? thumbnailPath;
  final String? rawOcrText;

  Map<String, Object?> toMap() => {
        'merchant': merchant,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'category': category.key,
        'note': note,
        'image_path': imagePath,
        'thumbnail_path': thumbnailPath,
        'raw_ocr_text': rawOcrText,
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int,
        merchant: map['merchant'] as String,
        amount: map['amount'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        category: ExpenseCategory.fromKey(map['category'] as String) ??
            ExpenseCategory.food,
        note: (map['note'] as String?) ?? '',
        imagePath: map['image_path'] as String?,
        thumbnailPath: map['thumbnail_path'] as String?,
        rawOcrText: map['raw_ocr_text'] as String?,
      );
}
