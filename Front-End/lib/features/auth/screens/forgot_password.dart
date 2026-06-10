import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/core/widgets/textfield.dart';
import 'package:ai/core/widgets/button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isCodeSent = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
    );
    return emailRegex.hasMatch(email);
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AuthProvider auth) async {
    final email = _emailController.text.trim();

    
    if (!_isValidEmail(email)) {
      _showMessage("Please enter a valid email address");
      return;
    }

    if (!_isCodeSent) {
      
      final success = await auth.requestResetCode(email);
      if (!mounted) return;
      if (success) {
        setState(() => _isCodeSent = true);
        _showMessage("Reset code sent! Check your inbox.", isError: false);
      } else {
        _showMessage(auth.errorMessage ?? "Failed to send code.");
      }
    } else {
      

      final code = _codeController.text.trim();
      final pass = _passController.text;
      final confirmPass = _confirmPassController.text;

      
      if (code.isEmpty || code.length < 4) {
        _showMessage("Please enter the reset code");
        return;
      }

      
      if (pass.isEmpty) {
        _showMessage("Please enter a new password");
        return;
      }
      if (pass.length < 6) {
        _showMessage("Password must be at least 6 characters");
        return;
      }

      
      if (pass != confirmPass) {
        _showMessage("Passwords do not match");
        return;
      }

      final success = await auth.confirmResetPassword(email, code, pass);
      if (!mounted) return;

      if (success) {
        _showMessage("Password changed successfully!", isError: false);
        
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        _showMessage(auth.errorMessage ?? "Failed to reset password.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: _isCodeSent ? "Check Inbox" : "Reset Password",
        subtitle: _isCodeSent
            ? "Enter the code and choose a new password"
            : "Recover access to your learning account",
        icon: _isCodeSent
            ? Icons.mark_email_read_outlined
            : Icons.lock_reset_rounded,
        metricLabel: "Code",
        metricValue: _isCodeSent ? "6" : "Email",
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (_isCodeSent) {
              setState(() => _isCodeSent = false);
            } else {
              Navigator.maybePop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(
              _isCodeSent
                  ? Icons.mark_email_read_outlined
                  : Icons.lock_reset_rounded,
              size: 100,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 30),
            Text(
              _isCodeSent ? "Check your inbox" : "Reset Password",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _isCodeSent
                  ? "Enter the code sent to ${_emailController.text.trim()}"
                  : "Enter your email to receive a password reset code",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            
            if (!_isCodeSent) ...[
              CustomTextField(
                label: "Email Address",
                controller: _emailController,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ] else ...[
              CustomTextField(
                label: "Reset Code",
                controller: _codeController,
                icon: Icons.verified_user_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  CustomTextField(
                    label: "New Password",
                    controller: _passController,
                    icon: Icons.lock_outline,
                    isPassword: _obscurePass,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Stack(
                alignment: Alignment.centerRight,
                children: [
                  CustomTextField(
                    label: "Confirm New Password",
                    controller: _confirmPassController,
                    icon: Icons.lock_reset,
                    isPassword: _obscureConfirm,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ],
              ),
            ],

            
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
            CustomButton(
              text: _isCodeSent ? "Verify & Change" : "Send Code",
              isLoading: auth.isLoading,
              onPressed: auth.isLoading || auth.isRateLimited
                  ? null
                  : () => _handleSubmit(auth),
            ),
            if (auth.isRateLimited) ...[
              const SizedBox(height: 12),
              Text(
                'Too many requests. Try again in ${auth.rateLimitSecondsRemaining} seconds.',
                style: TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],

            
            if (_isCodeSent) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final email = _emailController.text.trim();
                        if (!_isValidEmail(email)) {
                          _showMessage("Please enter a valid email address");
                          return;
                        }
                        final success = await auth.requestResetCode(email);
                        if (!mounted) return;
                        if (success) {
                          _showMessage(
                            "Code resent successfully!",
                            isError: false,
                          );
                        } else {
                          _showMessage(
                            auth.errorMessage ?? "Failed to resend.",
                          );
                        }
                      },
                child: Text(
                  "Didn't receive the code? Resend",
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
