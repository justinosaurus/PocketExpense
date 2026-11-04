import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 20, 133, 65),
        brightness: Brightness.light),
    scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
    appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color.fromARGB(255, 255, 255, 255)),
    cardTheme: CardThemeData(
        elevation: 0,
        color: const Color.fromARGB(255, 233, 245, 210),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
  );
}
