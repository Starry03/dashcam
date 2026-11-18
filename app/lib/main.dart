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
          seedColor: const Color(0xFF75B8CA),
          brightness: Brightness.dark,
          surface: const Color(0xFF11151A),
        ),
        scaffoldBackgroundColor: const Color(0xFF080A0D),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const DashcamHomePage(),
    );
  }
}
