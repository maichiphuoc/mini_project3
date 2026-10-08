import '../core/expense.dart';

class AmountCandidate {
  const AmountCandidate(this.amount, this.line, this.score, this.text);
  final int amount;
  final int line;
  final int score;
  final String text;
}

class ReceiptParseResult {
  const ReceiptParseResult({
    required this.rawText,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.merchantConfidence,
    required this.amountConfidence,
    required this.dateConfidence,
    required this.candidates,
    required this.warnings,
  });
  final String rawText;
  final String? merchant;
  final int? amount;
  final DateTime? date;
  final ExpenseCategory? category;
  final double merchantConfidence;
  final double amountConfidence;
  final double dateConfidence;
  final List<AmountCandidate> candidates;
  final List<String> warnings;
}

class ReceiptParser {
  static final _amountPattern = RegExp(
    r'(?<!\d)(?:\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{2})?|\d{4,10})(?!\d)',
  );
  static final _datePattern = RegExp(
    r'(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2}|\d{4})(?!\d)',
  );

  ReceiptParseResult parse(String rawText, {DateTime? now}) {
    final lines = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final normalized = lines.map(_fold).toList();
    final candidates = <AmountCandidate>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = normalized[i];
      if (RegExp(
              r'\b(mst|ma so thue|tax code|so dien thoai|dien thoai|phone|tel|ma hoa don|invoice no|so hd|dia chi)\b')
          .hasMatch(folded)) continue;
      if (_datePattern.hasMatch(line) && !_hasTotalKeyword(folded)) continue;
      final previous = i > 0 ? normalized[i - 1] : '';
      final baseScore = _scoreKeyword(folded);
      final precedingScore = _scoreKeyword(previous);
      for (final match in _amountPattern.allMatches(line)) {
        final value = parseVnd(match.group(0)!);
        if (value == null || value < 100 || value > 10000000000) continue;
        var score = baseScore;
        if (score > 0) score += 35;
        if (baseScore == 0 && precedingScore > 0) score += precedingScore + 20;
        if (i >= lines.length * 0.55) score += 10;
        if (RegExp(r'(vnd|vnđ|₫|đ)', caseSensitive: false).hasMatch(line)) {
          score += 10;
        }
        if (RegExp(r'\b(sl|qty|quantity|don gia|unit price)\b')
            .hasMatch(folded)) score -= 100;
        candidates.add(AmountCandidate(value, i, score, match.group(0)!));
      }
    }
    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.line.compareTo(a.line);
    });
    final best = candidates.isEmpty ? null : candidates.first;
    final amountConfidence = best == null
        ? 0.0
        : best.score >= 130
            ? 0.94
            : best.score >= 75
                ? 0.72
                : 0.35;

    String? merchant;
    double merchantConfidence = 0;
    for (var i = 0; i < lines.length && i < 7; i++) {
      final folded = normalized[i];
      if (lines[i].length < 3 ||
          RegExp(r'^\d|\d{4}|(hoa don|receipt|invoice|dia chi|address|tel|phone|mst|ma so thue|ngay|date|time|gio|cam on|thank)')
              .hasMatch(folded)) continue;
      merchant = lines[i];
      merchantConfidence = i < 3 ? 0.82 : 0.58;
      break;
    }

    DateTime? date;
    var dateConfidence = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final match = _datePattern.firstMatch(lines[i]);
      if (match == null) continue;
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += year >= 70 ? 1900 : 2000;
      final parsed = DateTime(year, month, day);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        continue;
      }
      final confidence =
          RegExp(r'\b(ngay|date|time|thoi gian)\b').hasMatch(normalized[i])
              ? 0.94
              : 0.65;
      if (confidence > dateConfidence) {
        date = parsed;
        dateConfidence = confidence;
      }
    }

    final category = suggestCategory(merchant ?? rawText);
    final warnings = <String>[];
    if (merchant == null) warnings.add('Không xác định được tên cửa hàng.');
    if (best == null) warnings.add('Không tìm thấy tổng tiền.');
    if (best != null && best.score < 75) {
      warnings.add('Tổng tiền cần được kiểm tra.');
    }
    if (candidates.length > 1 &&
        best != null &&
        candidates[1].score >= best.score - 10 &&
        candidates[1].amount != best.amount) {
      warnings.add('Có nhiều số tiền tương tự; hãy xác nhận tổng tiền.');
    }
    if (date == null) {
      warnings.add('Không tìm thấy ngày; ngày hiện tại chỉ là gợi ý.');
    }
    if (category == null) warnings.add('Hãy chọn danh mục chi tiêu.');
    return ReceiptParseResult(
      rawText: rawText,
      merchant: merchant,
      amount: best?.amount,
      date: date,
      category: category,
      merchantConfidence: merchantConfidence,
      amountConfidence: amountConfidence,
      dateConfidence: dateConfidence,
      candidates: candidates,
      warnings: warnings,
    );
  }

  static int? parseVnd(String raw) {
    var value =
        raw.trim().replaceAll(RegExp(r'[^0-9., ]'), '').replaceAll(' ', '');
    if (value.isEmpty) return null;
    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    final lastSeparator = lastDot > lastComma ? lastDot : lastComma;
    if (lastSeparator >= 0 &&
        value.length - lastSeparator - 1 == 2 &&
        (value.contains('.') && value.contains(','))) {
      value = value.substring(0, lastSeparator);
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 12) return null;
    return int.tryParse(digits);
  }

  static int _scoreKeyword(String folded) {
    if (RegExp(
            r'\b(tien thua|tien khach dua|khach dua|change|discount|giam gia|chiet khau|vat|thue|don gia|subtotal)\b')
        .hasMatch(folded)) return -150;
    if (RegExp(
            r'(tong thanh toan|can thanh toan|thanh tien thanh toan|so tien phai tra|grand total|amount due|total payment)')
        .hasMatch(folded)) return 100;
    if (RegExp(r'(tong cong|tong tien|total|thanh toan)').hasMatch(folded)) {
      return 70;
    }
    return 0;
  }

  static bool _hasTotalKeyword(String folded) => _scoreKeyword(folded) > 0;

  static ExpenseCategory? suggestCategory(String text) {
    final value = _fold(text);
    if (RegExp(
            r'\b(cafe|coffee|restaurant|nha hang|quan an|tra sua|food|banh mi|com)\b')
        .hasMatch(value)) return ExpenseCategory.food;
    if (RegExp(r'\b(book|sach|school|truong|stationery|van phong pham)\b')
        .hasMatch(value)) return ExpenseCategory.study;
    if (RegExp(r'\b(grab|taxi|bus|xe buyt|xang|gojek|be)\b').hasMatch(value)) {
      return ExpenseCategory.travel;
    }
    if (RegExp(
            r'\b(laptop|electronics|dien may|phu kien|computer|the gioi di dong)\b')
        .hasMatch(value)) return ExpenseCategory.gear;
    if (RegExp(r'\b(cinema|movie|game|rap phim|cgv|lotte cinema)\b')
        .hasMatch(value)) return ExpenseCategory.entertainment;
    return null;
  }

  static String _fold(String text) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      out.write(index >= 0 ? to[index] : char);
    }
    return out.toString();
  }
}
