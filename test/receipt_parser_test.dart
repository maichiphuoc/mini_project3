import 'package:flutter_test/flutter_test.dart';
import 'package:spend_lens/services/receipt_parser.dart';

void main() {
  final parser = ReceiptParser();

  test('ưu tiên tổng thanh toán hơn tiền khách đưa và tiền thừa', () {
    final result = parser.parse('''
QUÁN CÀ PHÊ MỘC
Ngày: 08/10/2026 14:35
Cà phê 50.000đ
TỔNG THANH TOÁN: 50.000đ
TIỀN KHÁCH ĐƯA: 100.000đ
TIỀN THỪA: 50.000đ
''');
    expect(result.merchant, 'QUÁN CÀ PHÊ MỘC');
    expect(result.amount, 50000);
    expect(result.date, DateTime(2026, 10, 8));
    expect(result.amountConfidence, greaterThan(.8));
  });

  test('đọc các định dạng VND phổ biến', () {
    for (final text in [
      '150,000 VND',
      '150.000 đ',
      '150 000',
      '1.250.000 ₫',
      '1,250,000 VND',
      '150000',
      '150,000.00 VND',
    ]) {
      final expected = text.contains('250') ? 1250000 : 150000;
      expect(ReceiptParser.parseVnd(text), expected, reason: text);
    }
  });

  test('bỏ qua ngày không hợp lệ và số điện thoại', () {
    final result = parser.parse('''
SIÊU THỊ AN BÌNH
Điện thoại: 0901234567
Ngày: 31/02/2026
Tổng tiền 150.000 VND
''');
    expect(result.amount, 150000);
    expect(result.date, isNull);
    expect(result.warnings, isNotEmpty);
  });

  test('hóa đơn rỗng chuyển sang nhập thủ công', () {
    final result = parser.parse('');
    expect(result.merchant, isNull);
    expect(result.amount, isNull);
    expect(result.date, isNull);
  });

  final amountCases = <String, int>{
    'TỔNG CỘNG: 150.000đ': 150000,
    'TOTAL: 150,000 VND': 150000,
    'THANH TOÁN 1.250.000': 1250000,
    'GRAND TOTAL 1,250,000': 1250000,
    'TOTAL 150,000.00 VND': 150000,
    'Tong thanh toan: 150 000': 150000,
    'TỔNG THANH TOÁN:\n150.000đ': 150000,
    'Tiền thừa 50.000\nTổng tiền 150.000': 150000,
    'Tổng tiền 150.000\nKhách đưa 200.000': 150000,
  };
  for (final entry in amountCases.entries) {
    test('tổng tiền: ${entry.key.replaceAll('\n', ' / ')}', () {
      expect(parser.parse(entry.key).amount, entry.value);
    });
  }

  test('ngày có nhãn và năm hai chữ số', () {
    final result = parser.parse('Date: 08/10/26\nTOTAL 150.000');
    expect(result.date, DateTime(2026, 10, 8));
    expect(result.dateConfidence, greaterThan(.9));
  });

  test('ngày nhuận hợp lệ; ngày không nhuận bị loại', () {
    expect(parser.parse('Ngày: 29/02/2024').date, DateTime(2024, 2, 29));
    expect(parser.parse('Ngày: 29/02/2025').date, isNull);
  });

  test('mã số thuế và số điện thoại không là tổng tiền', () {
    final result = parser.parse('MST: 0312345678\nPhone: 0901234567');
    expect(result.amount, isNull);
    expect(result.warnings, contains('Không tìm thấy tổng tiền.'));
  });

  test('gợi ý danh mục từ tên cửa hàng', () {
    final result = parser.parse('NHÀ SÁCH HỒNG HÀ\nTổng cộng: 75.000đ');
    expect(result.merchant, 'NHÀ SÁCH HỒNG HÀ');
    expect(result.category?.name, 'study');
  });

  test('số tiền tràn giới hạn bị bỏ qua', () {
    expect(ReceiptParser.parseVnd('1234567890123'), isNull);
  });
}
