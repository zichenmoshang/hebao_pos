import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/cashier/screens/cashier_screen.dart';
import 'theme.dart';

class HebaoPosApp extends StatelessWidget {
  const HebaoPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '和宝收银',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CashierScreen(),
    );
  }
}
