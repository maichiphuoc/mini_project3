import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredReceipt {
  const StoredReceipt(this.imagePath, this.thumbnailPath);
  final String imagePath;
  final String thumbnailPath;
}

Uint8List? _thumbnail(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final small = img.copyResize(decoded, width: 240);
  return Uint8List.fromList(img.encodeJpg(small, quality: 75));
}

class ReceiptImageStore {
  Future<StoredReceipt> persist(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Ảnh hóa đơn không còn tồn tại.');
    }
    final root = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
    await root.create(recursive: true);
    final name = '${DateTime.now().microsecondsSinceEpoch}';
    final extension = p.extension(sourcePath).toLowerCase();
    final imagePath =
        p.join(root.path, '$name${extension.isEmpty ? '.jpg' : extension}');
    await source.copy(imagePath);
    final thumbPath = p.join(root.path, '${name}_thumb.jpg');
    final thumb = await compute(_thumbnail, await source.readAsBytes());
    if (thumb != null) await File(thumbPath).writeAsBytes(thumb);
    return StoredReceipt(imagePath, thumb == null ? imagePath : thumbPath);
  }

  Future<void> delete(String? imagePath, String? thumbnailPath) async {
    for (final path in {imagePath, thumbnailPath}) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }
}
