import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:terminal_launcher/terminal.dart';

Future<void> main() async {
  await dotenv.load(); 
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

