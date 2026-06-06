import 'package:ai/features/auth/widgets/register/register_error_box.dart';
import 'package:ai/features/auth/widgets/register/register_step_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegisterOtpStep extends StatelessWidget {
  final Key? stepKey;
  final String email;
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpFocusNodes;
  final String? errorMessage;
  final String? debugCode;
  final int resendCountdown;
  final bool isLoading;
  final bool isResending;
  final ValueChanged<int> onBackToStep;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onSkip;
  final void Function(int index, String value) onOtpChanged;

  const RegisterOtpStep({
    super.key,
    this.stepKey,
    required this.email,
    required this.otpControllers,
    required this.otpFocusNodes,
    required this.errorMessage,
    required this.debugCode,
    required this.resendCountdown,
    required this.isLoading,
    required this.isResending,
    required this.onBackToStep,
    required this.onVerify,
    required this.onResend,
    required this.onSkip,
    required this.onOtpChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: stepKey,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => onBackToStep(0),
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
                    'Back',
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
          const RegisterStepProgress(step: 1),
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
            'Check Your Email',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF755DC1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We sent a 6-digit verification code to',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF755DC1),
            ),
            textAlign: TextAlign.center,
          ),
          if (debugCode != null) ...[
            const SizedBox(height: 10),
            Text(
              'Development code: $debugCode',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _buildOtpBox),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            RegisterErrorBox(message: errorMessage!),
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
              onPressed: isLoading ? null : onVerify,
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
                      'Verify Email',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              resendCountdown > 0
                  ? Text(
                      'Resend in ${resendCountdown}s',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF755DC1),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : GestureDetector(
                      onTap: isResending ? null : onResend,
                      child: isResending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF755DC1),
                              ),
                            )
                          : const Text(
                              'Resend',
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF755DC1),
                side: const BorderSide(color: Color(0xFF755DC1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onSkip,
              child: const Text('Skip for now', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: otpControllers[index],
        focusNode: otpFocusNodes[index],
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
        onChanged: (value) => onOtpChanged(index, value),
      ),
    );
  }
}
