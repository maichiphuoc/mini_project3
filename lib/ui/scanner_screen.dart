import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/receipt_parser.dart';
import '../state/providers.dart';
import 'expense_form_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? error;
  bool busy = false;
  FlashMode flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Thiết bị không có camera.');
      }
      final camera = cameras.firstWhere(
          (item) => item.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      final next =
          CameraController(camera, ResolutionPreset.high, enableAudio: false);
      await next.initialize();
      await next.setFlashMode(FlashMode.off);
      if (!mounted) {
        await next.dispose();
        return;
      }
      final old = controller;
      setState(() {
        controller = next;
        error = null;
      });
      await old?.dispose();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => error = e.code == 'CameraAccessDenied'
            ? 'Quyền camera bị từ chối. Hãy cấp quyền trong Cài đặt hoặc chọn ảnh từ thư viện.'
            : 'Không thể mở camera: ${e.description ?? e.code}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Không thể mở camera. Bạn vẫn có thể chọn ảnh từ thư viện.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final current = controller;
      controller = null;
      current?.dispose();
    } else if (state == AppLifecycleState.resumed && controller == null) {
      initialize();
    }
  }

  Future<void> toggleFlash() async {
    final current = controller;
    if (current == null) return;
    final next = switch (flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await current.setFlashMode(next);
      if (mounted) setState(() => flash = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thiết bị không hỗ trợ chế độ đèn này.')));
      }
    }
  }

  Future<void> capture() async {
    final current = controller;
    if (busy || current == null || !current.value.isInitialized) return;
    setState(() => busy = true);
    try {
      final image = await current.takePicture();
      if (mounted) await openPreview(image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể chụp ảnh. Vui lòng thử lại.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickGallery() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) await openPreview(image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể chọn ảnh từ thư viện.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openPreview(String path) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(path: path)));
    if (saved == true && mounted) widget.onSaved();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn'), actions: [
        if (current != null)
          IconButton(
              tooltip: 'Đèn flash: ${flash.name}',
              onPressed: toggleFlash,
              icon: Icon(flash == FlashMode.off
                  ? Icons.flash_off
                  : flash == FlashMode.auto
                      ? Icons.flash_auto
                      : Icons.flash_on)),
      ]),
      body: Column(children: [
        Expanded(
            child: Container(
          color: const Color(0xFF101A17),
          width: double.infinity,
          child: current != null && current.value.isInitialized
              ? Center(
                  child: AspectRatio(
                  aspectRatio:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? 1 / current.value.aspectRatio
                          : current.value.aspectRatio,
                  child: LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                            onTapDown: (details) async {
                              try {
                                await current.setFocusPoint(Offset(
                                  (details.localPosition.dx /
                                          constraints.maxWidth)
                                      .clamp(0.0, 1.0),
                                  (details.localPosition.dy /
                                          constraints.maxHeight)
                                      .clamp(0.0, 1.0),
                                ));
                              } catch (_) {
                                /* Focus is optional on some devices. */
                              }
                            },
                            child: Stack(fit: StackFit.expand, children: [
                              CameraPreview(current),
                              const IgnorePointer(
                                  child: CustomPaint(
                                      painter: ReceiptFramePainter())),
                            ]),
                          )),
                ))
              : Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: error == null
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                  onPressed: initialize,
                                  child: const Text('Thử lại')),
                            ]))),
        )),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(children: [
            const Text('Đặt hóa đơn trong khung, giữ máy ổn định và đủ sáng.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              OutlinedButton.icon(
                  onPressed: busy ? null : pickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện')),
              IconButton.filled(
                  onPressed: busy || current == null ? null : capture,
                  iconSize: 34,
                  padding: const EdgeInsets.all(16),
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Chụp ảnh'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class ReceiptFramePainter extends CustomPainter {
  const ReceiptFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(
        size.width * .1, size.height * .15, size.width * .8, size.height * .7);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(18)));
    canvas.drawPath(
        outside,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.srcOver);
    final border = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(18)), border);
    final corner = Paint()
      ..color = const Color(0xFF5FE2B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const length = 26.0;
    for (final x in [frame.left, frame.right]) {
      for (final y in [frame.top, frame.bottom]) {
        final dx = x == frame.left ? 1.0 : -1.0;
        final dy = y == frame.top ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y + dy * length), Offset(x, y), corner);
        canvas.drawLine(Offset(x, y), Offset(x + dx * length, y), corner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ReceiptFramePainter oldDelegate) => false;
}

class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  const ReceiptPreviewScreen({super.key, required this.path});
  final String path;
  @override
  ConsumerState<ReceiptPreviewScreen> createState() =>
      _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> {
  late String path = widget.path;
  bool processing = false;
  String? error;

  Future<void> crop() async {
    try {
      final cropped =
          await ImageCropper().cropImage(sourcePath: path, uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Cắt hóa đơn',
            toolbarColor: const Color(0xFF0F9D76),
            toolbarWidgetColor: Colors.white),
        IOSUiSettings(title: 'Cắt hóa đơn'),
      ]);
      if (cropped != null && mounted) {
        setState(() {
          path = cropped.path;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Không thể cắt ảnh. Bạn có thể dùng ảnh hiện tại.');
      }
    }
  }

  Future<void> recognize() async {
    if (processing) return;
    setState(() {
      processing = true;
      error = null;
    });
    ReceiptParseResult result;
    try {
      if (!await File(path).exists()) {
        throw const FileSystemException('Ảnh không tồn tại');
      }
      result = (await ref.read(ocrProvider).process(path)).parseResult;
    } catch (_) {
      result = ReceiptParser().parse('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Không thể đọc chữ trong ảnh. Vui lòng nhập thủ công trên màn hình tiếp theo.')));
      }
    }
    if (!mounted) return;
    setState(() => processing = false);
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ExpenseFormScreen(parsed: result, imagePath: path)));
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kiểm tra ảnh')),
        body: Column(children: [
          Expanded(
              child: Container(
                  color: const Color(0xFF101A17),
                  width: double.infinity,
                  child: Image.file(File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('Không thể mở ảnh',
                              style: TextStyle(color: Colors.white)))))),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Colors.red))),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                OutlinedButton.icon(
                    onPressed: processing ? null : crop,
                    icon: const Icon(Icons.crop_rotate),
                    label: const Text('Cắt / xoay ảnh')),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: processing ? null : recognize,
                      icon: processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.document_scanner_outlined),
                      label: Text(processing
                          ? 'Đang nhận diện...'
                          : 'Nhận diện hóa đơn'),
                    )),
              ])),
        ]),
      );
}
