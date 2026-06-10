import 'package:ai/features/auth/widgets/register/register_error_box.dart';
import 'package:ai/features/auth/widgets/register/register_text_field.dart';
import 'package:flutter/material.dart';

class RegisterFormStep extends StatelessWidget {
  final Key? stepKey;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool isLoading;
  final bool isRateLimited;
  final int rateLimitSecondsRemaining;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onLoginTap;

  const RegisterFormStep({
    super.key,
    this.stepKey,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.isLoading,
    required this.isRateLimited,
    required this.rateLimitSecondsRemaining,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: stepKey,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            RegisterTextField(
              controller: nameController,
              hint: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),
            const SizedBox(height: 14),
            RegisterTextField(
              controller: emailController,
              hint: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$',
                ).hasMatch(value.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            RegisterTextField(
              controller: passwordController,
              hint: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscure: obscurePassword,
              onToggleObscure: onTogglePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) return 'At least 6 characters required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            RegisterTextField(
              controller: confirmController,
              hint: 'Confirm Password',
              icon: Icons.lock_reset,
              isPassword: true,
              obscure: obscureConfirm,
              onToggleObscure: onToggleConfirm,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              RegisterErrorBox(message: errorMessage!),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF755DC1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: isLoading || isRateLimited ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next - Verify Email',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
            if (isRateLimited) ...[
              const SizedBox(height: 12),
              Text(
                'Too many requests. Try again in $rateLimitSecondsRemaining seconds.',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onLoginTap,
                child: const Text(
                  'Already have an account? Login',
                  style: TextStyle(color: Color(0xFF755DC1)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
