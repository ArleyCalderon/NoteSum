import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/note_sum_screen.dart';

class NoteSumApp extends StatefulWidget {
  const NoteSumApp({super.key});

  static _NoteSumAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_NoteSumAppState>()!;

  @override
  State<NoteSumApp> createState() => _NoteSumAppState();
}

class _NoteSumAppState extends State<NoteSumApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = _themeMode == ThemeMode.dark;

    setState(() {
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });

    await prefs.setBool('dark_mode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteSum',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: _themeMode,

      home: const NoteSumScreen(),
    );
  }
}