import 'package:flutter/material.dart';
import '../../../shared/widgets/app_surface.dart';

class NotifikasiScreen extends StatelessWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: const AppPageBackground(
        child: AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Belum ada notifikasi',
          message: 'Pembaruan aplikasi dan aktivitas penting akan muncul di sini.',
        ),
      ),
    );
  }
}
