import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/admin_app.dart';

/// Back-office web : `flutter run -d chrome -t lib/main_admin.dart`
void main() => runApp(const ProviderScope(child: AdminApp()));
