import 'package:ai/features/auth/screens/forgot_password.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/textfield.dart';
import 'package:ai/core/widgets/button.dart';

class LoginScreen extends StatefulWidget {
  final PageController controller;
  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _awaitingOtp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    auth.clearError();

    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _awaitingOtp = true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Verification code sent to your email."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _showError(messenger, auth.errorMessage ?? 'Login failed.');
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.verifyLoginOtp(
      _emailController.text.trim(),
      _otpController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Welcome back!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _showError(messenger, auth.errorMessage ?? 'Invalid verification code.');
    }
  }

  Future<void> _handleResendOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.resendLoginOtp(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Verification code resent."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _showError(messenger, auth.errorMessage ?? 'Failed to resend code.');
    }
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 250,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        _awaitingOtp ? "Verify Login" : "Log In",
                        style: TextStyle(
                          fontSize: 26,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (_awaitingOtp)
                        _buildOtpStep(auth)
                      else
                        _buildPasswordStep(auth),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          label: "Email",
          controller: _emailController,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: "Password",
          controller: _passwordController,
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            "Forget Password?",
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: "Sign In",
          isLoading: auth.isLoading,
          onPressed: auth.isLoading ? null : _handleLogin,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: TextStyle(color: AppColors.textLight),
            ),
            TextButton(
              onPressed: () {
                auth.clearError();
                widget.controller.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                "Sign Up",
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter the 6-digit code sent to ${_emailController.text.trim()}",
          style: TextStyle(color: AppColors.textLight),
        ),
        if (auth.lastLoginOtpDebugCode != null) ...[
          const SizedBox(height: 8),
          Text(
            "Development code: ${auth.lastLoginOtpDebugCode}",
            style: TextStyle(color: AppColors.secondary),
          ),
        ],
        const SizedBox(height: 16),
        CustomTextField(
          label: "Verification Code",
          controller: _otpController,
          icon: Icons.verified_user_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: "Verify & Continue",
          isLoading: auth.isLoading,
          onPressed: auth.isLoading ? null : _handleVerifyOtp,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
                      setState(() {
                        _awaitingOtp = false;
                        _otpController.clear();
                      });
                    },
              child: Text("Back", style: TextStyle(color: AppColors.secondary)),
            ),
            TextButton(
              onPressed: auth.isLoading ? null : _handleResendOtp,
              child: Text(
                "Resend Code",
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
