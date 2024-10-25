import 'package:flutter/material.dart';
import 'package:terminal_launcher/terminal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TerminalApp());
}

class TerminalApp extends StatelessWidget {
  const TerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Terminal Launcher',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
      ),
      home: const Terminal(),
    );
  }
}

