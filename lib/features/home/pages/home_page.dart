import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'Home Page',
          style: TextStyle(color: AppColors.onSurface),
        ),
      ),
    );
  }
}
