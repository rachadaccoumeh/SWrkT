import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'Login Page',
          style: TextStyle(color: AppColors.onSurface),
        ),
      ),
    );
  }
}
