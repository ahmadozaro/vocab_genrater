import 'dart:async';
import 'package:ai/features/interests/widgets/interests_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/models/interest.dart';

class SignUpScreen extends StatefulWidget {
  final PageController? controller;
  const SignUpScreen({super.key, this.controller});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // ─── Controllers ───────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // OTP controllers
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // ─── State ─────────────────────────────────────
  /// 0 = معلومات شخصية  |  1 = تحقق OTP  |  2 = اهتمامات
  int _step = 0;
  List<InterestModel> _selectedInterests = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // OTP countdown
  int _resendCountdown = 60;
  Timer? _timer;
  bool _isResending = false;

  // ✅ منع التحقق التلقائي من الإرسال المزدوج
  bool _isVerifying = false;

  // ─── Dispose ───────────────────────────────────
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────
  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Step 0 → Step 1 ───────────────────────────
  Future<void> _handleRegisterAndSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _confirmController.text,
      initialInterests: [],
    );

    if (!mounted) return;

    if (success) {
      // ✅ امسح خانات OTP عند الانتقال للخطوة الجديدة
      for (final c in _otpControllers) {
        c.clear();
      }
      _startCountdown();
      setState(() => _step = 1);
      final code = auth.lastVerificationDebugCode;
      if (code != null && code.isNotEmpty) {
        _showSnack('Development verification code: $code', isError: false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } else {
      _showSnack(auth.errorMessage ?? 'Registration failed.');
    }
  }

  // ─── Step 1 → Step 2 ───────────────────────────
  Future<void> _handleVerifyOtp() async {
    // ✅ منع الإرسال المزدوج (auto-submit + زر)
    if (_isVerifying) return;
    if (_otpCode.length < 6) {
      _showSnack('Please enter the 6-digit code');
      return;
    }

    setState(() => _isVerifying = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyEmail(
      _emailController.text.trim(),
      _otpCode,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      // ✅ verifyEmail يُعيّن _isLoggedIn = true في AuthProvider
      // → _AppRouter سيقفز تلقائياً إلى InterestsScreen
      // لا حاجة لـ Navigator هنا
    } else {
      _showSnack(auth.errorMessage ?? 'Invalid code. Try again.');
      for (final c in _otpControllers) {
        c.clear();
      }
      if (mounted) _otpFocusNodes[0].requestFocus();
    }
  }

  // ─── Resend OTP ────────────────────────────────
  Future<void> _handleResend() async {
    if (_resendCountdown > 0 || _isResending) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isResending = true);

    final success = await auth.resendVerificationCode(
      _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      // ✅ امسح الخانات ليعيد المستخدم الإدخال
      for (final c in _otpControllers) {
        c.clear();
      }
      if (mounted) _otpFocusNodes[0].requestFocus();
      _startCountdown();
      final code = auth.lastVerificationDebugCode;
      _showSnack(
        code == null || code.isEmpty
            ? 'Code resent successfully!'
            : 'Code resent. Development code: $code',
        isError: false,
      );
    } else {
      _showSnack(auth.errorMessage ?? 'Failed to resend code.');
    }
  }

  // ─── OTP field input handler ───────────────────
  void _onOtpChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        // ✅ آخر خانة: أغلق الكيبورد ثم تحقق
        _otpFocusNodes[index].unfocus();
        // ✅ نتحقق أن الكود مكتمل فعلاً قبل الإرسال التلقائي
        final code = _otpCode;
        if (code.length == 6) {
          // ✅ تأخير بسيط لضمان تحديث الـ state أولاً
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _handleVerifyOtp();
          });
        }
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
          child: switch (_step) {
            0 => _buildFormStep(key: const ValueKey('form')),
            1 => _buildOtpStep(key: const ValueKey('otp')),
            2 => _buildInterestsStep(key: const ValueKey('interests')),
            _ => _buildFormStep(key: const ValueKey('form')),
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // STEP 0 — معلومات شخصية
  // ══════════════════════════════════════════════
  Widget _buildFormStep({Key? key}) {
    final auth = Provider.of<AuthProvider>(context);
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            _buildProgress(step: 0),
            const SizedBox(height: 28),
            const Text(
              "Create Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF755DC1),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Step 1 of 3 — Personal info",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 28),

            // Full Name
            _buildTextField(
              controller: _nameController,
              hint: "Full Name",
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email
            _buildTextField(
              controller: _emailController,
              hint: "Email Address",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$',
                ).hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            _buildTextField(
              controller: _passwordController,
              hint: "Password",
              icon: Icons.lock_outline,
              isPassword: true,
              obscure: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a password';
                if (v.length < 6) return 'At least 6 characters required';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password
            _buildTextField(
              controller: _confirmController,
              hint: "Confirm Password",
              icon: Icons.lock_reset,
              isPassword: true,
              obscure: _obscureConfirm,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password';
                }
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            // Error message
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
                onPressed: auth.isLoading ? null : _handleRegisterAndSendOtp,
                child: auth.isLoading
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
                            "Next — Verify Email",
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
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  auth.clearError();
                  widget.controller?.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
                child: const Text(
                  "Already have an account? Login",
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

  // ══════════════════════════════════════════════
  // STEP 1 — تحقق OTP
  // ══════════════════════════════════════════════
  Widget _buildOtpStep({Key? key}) {
    final auth = Provider.of<AuthProvider>(context);
    final isLoading = auth.isLoading || _isVerifying;

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ✅ زر الرجوع يعود للخطوة 0 (ليس 1)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                _timer?.cancel();
                setState(() => _step = 0);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Color(0xFF755DC1),
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Back",
                    style: TextStyle(
                      color: Color(0xFF755DC1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildProgress(step: 1),
          const SizedBox(height: 40),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF755DC1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 40,
              color: Color(0xFF755DC1),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Check Your Email",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF755DC1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "We sent a 6-digit verification code to",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _emailController.text.trim(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF755DC1),
            ),
            textAlign: TextAlign.center,
          ),
          if (auth.lastVerificationDebugCode != null) ...[
            const SizedBox(height: 10),
            Text(
              'Development code: ${auth.lastVerificationDebugCode}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 36),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _buildOtpBox),
          ),

          // Error message
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 16),
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
          const SizedBox(height: 36),

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
              onPressed: isLoading ? null : _handleVerifyOtp,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Verify Email",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Resend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              _resendCountdown > 0
                  ? Text(
                      "Resend in ${_resendCountdown}s",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF755DC1),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : GestureDetector(
                      onTap: _isResending ? null : _handleResend,
                      child: _isResending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF755DC1),
                              ),
                            )
                          : const Text(
                              "Resend",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF755DC1),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // STEP 2 — اهتمامات
  // ══════════════════════════════════════════════
  // ✅ هذه الخطوة لن تظهر أبداً في التدفق الطبيعي لأن verifyEmail
  //    يُعيّن isLoggedIn = true → _AppRouter يقفز لـ InterestsScreen تلقائياً.
  //    لكن نتركها كـ fallback في حال احتجتها لاحقاً.
  Widget _buildInterestsStep({Key? key}) {
    final auth = Provider.of<AuthProvider>(context);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _step = 1),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Color(0xFF755DC1),
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Color(0xFF755DC1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildProgress(step: 2),
              const SizedBox(height: 20),
              const Text(
                "Your Interests",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF755DC1),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Step 3 of 3 — Pick topics you love",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InterestsSelector(
              initialSelected: _selectedInterests,
              onChanged: (data) => setState(() => _selectedInterests = data),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(
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
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      if (_selectedInterests.isNotEmpty) {
                        await auth.updateInterestsModels(_selectedInterests);
                      }
                      if (!mounted) return;
                      // ✅ بعد حفظ الاهتمامات، نعتمد على _AppRouter
                      // لكن hasTakenTest = false → سيعرض TestScreen
                      // لا حاجة لـ pushNamed هنا إذا كان _AppRouter يتعامل معه
                    },
              child: auth.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _selectedInterests.isEmpty
                          ? "Skip — Take Level Test"
                          : "Next — Take Level Test",
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // WIDGETS مشتركة
  // ══════════════════════════════════════════════

  Widget _buildProgress({required int step}) {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF755DC1) : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF755DC1),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF755DC1), width: 2),
          ),
        ),
        onChanged: (v) => _onOtpChanged(index, v),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF755DC1), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF755DC1), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
    );
  }
}
