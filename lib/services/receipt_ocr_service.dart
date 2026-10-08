import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser.dart';

class ReceiptOcrResult {
  const ReceiptOcrResult(
      this.parseResult, this.recognitionTime, this.parserTime);
  final ReceiptParseResult parseResult;
  final Duration recognitionTime;
  final Duration parserTime;
}

class ReceiptOcrService {
  ReceiptOcrService(this.parser);
  final ReceiptParser parser;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptOcrResult> process(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw const FileSystemException('Không tìm thấy ảnh hóa đơn hợp lệ.');
    }
    final watch = Stopwatch()..start();
    final recognized =
        await _recognizer.processImage(InputImage.fromFilePath(path));
    final recognitionTime = watch.elapsed;
    watch.reset();
    final result = parser.parse(recognized.text);
    return ReceiptOcrResult(result, recognitionTime, watch.elapsed);
  }

  Future<void> dispose() => _recognizer.close();
}
