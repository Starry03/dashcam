import 'package:flutter/material.dart';
import 'features/dashcam/presentation/dashcam_home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashcamApp());
}

class DashcamApp extends StatelessWidget {
  const DashcamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashcam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashcamHomePage(),
    );
  }
}
