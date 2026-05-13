import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _SignUpContent()),
    );
  }
}

class _SignUpContent extends StatefulWidget {
  @override
  State<_SignUpContent> createState() => _SignUpContentState();
}

class _SignUpContentState extends State<_SignUpContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _obscure = true.obs;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Get.find<AuthController>().signUp(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Create Account',
              style: GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Start tracking your fitness journey',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 40),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _TextFieldS(label: 'Name', hint: 'Your name', controller: _nameCtrl, validator: (v) => v != null && v.length >= 2 ? null : 'Name required'),
                const SizedBox(height: 16),
                _TextFieldS(label: 'Email', hint: 'you@example.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, validator: (v) => v?.isEmail ?? false ? null : 'Valid email required'),
                const SizedBox(height: 16),
                _TextFieldS(
                  label: 'Password',
                  hint: 'Min 8 characters',
                  controller: _passwordCtrl,
                  obscure: _obscure.value,
                  suffix: IconButton(
                    icon: Icon(_obscure.value ? Icons.visibility_off : Icons.visibility, color: AppColors.onSurfaceVariant, size: 20),
                    onPressed: () => _obscure.toggle(),
                  ),
                  validator: (v) => v != null && v.length >= 8 ? null : 'Min 8 characters',
                ),
                const SizedBox(height: 16),
                _TextFieldS(
                  label: 'Confirm Password',
                  hint: 'Repeat password',
                  controller: _confirmCtrl,
                  obscure: true,
                  validator: (v) => v == _passwordCtrl.text ? null : 'Passwords do not match',
                ),
              ],
            ),
          ),
          if (auth.errorMessage.value != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF5C3535)),
              ),
              child: Text(auth.errorMessage.value!, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: auth.isLoading.value ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: auth.isLoading.value
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                  : Text('Create Account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ));
  }
}

class _TextFieldS extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _TextFieldS({required this.label, required this.hint, this.controller, this.obscure=false, this.suffix, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant, letterSpacing: 0.02)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
