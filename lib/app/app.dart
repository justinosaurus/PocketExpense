import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../core/data/app_database.dart';
import '../features/expenses/presentation/expense_controller.dart';
import '../features/accounts/presentation/account_controller.dart';
import 'app_shell.dart';
import 'theme.dart';

class ExpenseApp extends StatefulWidget {
  const ExpenseApp(
      {super.key,
      required this.controller,
      required this.accountController,
      this.database});

  final ExpenseController controller;
  final AccountController accountController;
  final AppDatabase? database;

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final database = widget.database;
    if (database == null) return;
    try {
      final saved = await database.getSetting('theme_mode');
      final mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (mounted) setState(() => _themeMode = mode);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while loading the saved theme preference'),
      ));
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final oldMode = _themeMode;
    setState(() => _themeMode = mode);
    final database = widget.database;
    if (database == null) return;
    try {
      await database.setSetting('theme_mode', mode.name);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while saving the theme preference'),
      ));
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
        content:
            Text('Theme changed for this session, but could not be saved.'),
      ));
      setState(() => _themeMode = oldMode);
    }
  }

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) => MaterialApp(
          title: 'Pocket Expenses',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          theme: buildAppTheme(
            brightness: Brightness.light,
            dynamicColorScheme: lightDynamic,
          ),
          darkTheme: buildAppTheme(
            brightness: Brightness.dark,
            dynamicColorScheme: darkDynamic,
          ),
          themeMode: _themeMode,
          home: AppShell(
            controller: widget.controller,
            accountController: widget.accountController,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          ),
        ),
      );
}
