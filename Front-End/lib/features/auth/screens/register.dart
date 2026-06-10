import 'dart:async';

import 'package:ai/core/models/interest.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/features/auth/widgets/register/register_form_step.dart';
import 'package:ai/features/auth/widgets/register/register_interests_step.dart';
import 'package:ai/features/auth/widgets/register/register_otp_step.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SignUpScreen extends StatefulWidget {
  final PageController? controller;

  const SignUpScreen({super.key, this.controller});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _step = 0;
  List<InterestModel> _selectedInterests = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isResending = false;
  bool _isVerifying = false;
  int _resendCountdown = 60;
  Timer? _timer;

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showSnack(String message, {bool isError = true}) {
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

  void _goToStep(int step) {
    if (step == 0) _timer?.cancel();
    setState(() => _step = step);
  }

  Future<void> _registerAndSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _confirmController.text,
      initialInterests: [],
    );

    if (!mounted) return;

    if (!success) {
      _showSnack(auth.errorMessage ?? 'Registration failed.');
      return;
    }

    for (final controller in _otpControllers) {
      controller.clear();
    }
    _startCountdown();
    setState(() => _step = 1);

    final code = auth.lastVerificationDebugCode;
    if (code != null && code.isNotEmpty) {
      _showSnack('Development verification code: $code', isError: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNodes.first.requestFocus();
    });
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    if (_otpCode.length < 6) {
      _showSnack('Please enter the 6-digit code');
      return;
    }

    setState(() => _isVerifying = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyEmail(
      _emailController.text.trim(),
      _otpCode,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) return;

    _showSnack(auth.errorMessage ?? 'Invalid code. Try again.');
    for (final controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes.first.requestFocus();
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    final auth = context.read<AuthProvider>();
    setState(() => _isResending = true);
    final success = await auth.resendVerificationCode(
      _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    if (!success) {
      _showSnack(auth.errorMessage ?? 'Failed to resend code.');
      return;
    }

    for (final controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes.first.requestFocus();
    _startCountdown();

    final code = auth.lastVerificationDebugCode;
    _showSnack(
      code == null || code.isEmpty
          ? 'Code resent successfully!'
          : 'Code resent. Development code: $code',
      isError: false,
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1) {
      if (index < _otpFocusNodes.length - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _otpCode.length == 6) _verifyOtp();
        });
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _continueFromInterests() async {
    final auth = context.read<AuthProvider>();
    if (_selectedInterests.isNotEmpty) {
      await auth.updateInterestsModels(_selectedInterests);
    }
  }

  Widget _buildCurrentStep(AuthProvider auth) {
    return switch (_step) {
      0 => RegisterFormStep(
          stepKey: const ValueKey('form'),
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmController: _confirmController,
          obscurePassword: _obscurePassword,
          obscureConfirm: _obscureConfirm,
          isLoading: auth.isLoading,
          isRateLimited: auth.isRateLimited,
          rateLimitSecondsRemaining: auth.rateLimitSecondsRemaining,
          errorMessage: auth.errorMessage,
          onTogglePassword: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          onToggleConfirm: () {
            setState(() => _obscureConfirm = !_obscureConfirm);
          },
          onSubmit: _registerAndSendOtp,
          onLoginTap: () {
            auth.clearError();
            widget.controller?.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
            );
          },
        ),
      1 => RegisterOtpStep(
          stepKey: const ValueKey('otp'),
          email: _emailController.text.trim(),
          otpControllers: _otpControllers,
          otpFocusNodes: _otpFocusNodes,
          errorMessage: auth.errorMessage,
          debugCode: auth.lastVerificationDebugCode,
          resendCountdown: _resendCountdown,
          isLoading: auth.isLoading || _isVerifying,
          isResending: _isResending,
          onBackToStep: _goToStep,
          onVerify: _verifyOtp,
          onResend: _resendOtp,
          onSkip: auth.skipVerification,
          onOtpChanged: _onOtpChanged,
        ),
      2 => RegisterInterestsStep(
          stepKey: const ValueKey('interests'),
          selectedInterests: _selectedInterests,
          isLoading: auth.isLoading,
          onBackToStep: _goToStep,
          onChanged: (data) => setState(() => _selectedInterests = data),
          onContinue: _continueFromInterests,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: LearningAppBar(
        title: 'Create Account',
        subtitle: 'Set up your vocabulary learning path',
        icon: Icons.person_add_alt_1_rounded,
        metricLabel: 'Step',
        metricValue: '${_step + 1}/3',
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
          child: _buildCurrentStep(auth),
        ),
      ),
    );
  }
}
