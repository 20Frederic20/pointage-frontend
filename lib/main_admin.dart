import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
void main() => runApp(const ProviderScope(child: AdminApp()));

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pointage — Administration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: Column(children: [
          FlagStripe(),
          Expanded(child: Center(child: Text('Administration — à venir'))),
        ]),
      ),
    );
  }
}
