import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services/notification_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');

  // Inisialisasi notification service
  await NotificationService().init();

  runApp(
    const ProviderScope(
      child: RukunWargaApp(),
    ),
  );
}
