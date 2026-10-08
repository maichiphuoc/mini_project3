import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/providers.dart';
import 'ui/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SpendLensApp()));
}

class SpendLensApp extends StatelessWidget {
  const SpendLensApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SpendLens',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F9D76)),
          scaffoldBackgroundColor: const Color(0xFFF7FAF8),
          cardTheme: CardTheme(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          inputDecorationTheme: InputDecorationTheme(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        home: const InitializationScreen(),
      );
}

class InitializationScreen extends ConsumerStatefulWidget {
  const InitializationScreen({super.key});
  @override
  ConsumerState<InitializationScreen> createState() =>
      _InitializationScreenState();
}

class _InitializationScreenState extends ConsumerState<InitializationScreen> {
  late Future<void> init = initialize();
  Future<void> initialize() async {
    await ref.read(repositoryProvider).database;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long, size: 64, color: Color(0xFF0F9D76)),
            SizedBox(height: 16),
            Text('SpendLens',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ])));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Không thể khởi tạo dữ liệu trên thiết bị.'),
            TextButton(
                onPressed: () => setState(() => init = initialize()),
                child: const Text('Thử lại')),
          ])));
        }
        return const MainShell();
      });
}
