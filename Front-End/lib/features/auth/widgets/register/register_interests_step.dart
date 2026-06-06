import 'package:ai/core/models/interest.dart';
import 'package:ai/features/auth/widgets/register/register_step_progress.dart';
import 'package:ai/features/interests/widgets/interests_selector.dart';
import 'package:flutter/material.dart';

class RegisterInterestsStep extends StatelessWidget {
  final Key? stepKey;
  final List<InterestModel> selectedInterests;
  final bool isLoading;
  final ValueChanged<int> onBackToStep;
  final ValueChanged<List<InterestModel>> onChanged;
  final VoidCallback onContinue;

  const RegisterInterestsStep({
    super.key,
    this.stepKey,
    required this.selectedInterests,
    required this.isLoading,
    required this.onBackToStep,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: stepKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onBackToStep(1),
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
              const SizedBox(height: 20),
              const RegisterStepProgress(step: 2),
              const SizedBox(height: 20),
              const Text(
                'Your Interests',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF755DC1),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Step 3 of 3 - Pick topics you love',
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
              initialSelected: selectedInterests,
              onChanged: onChanged,
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
              onPressed: isLoading ? null : onContinue,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      selectedInterests.isEmpty
                          ? 'Skip - Take Level Test'
                          : 'Next - Take Level Test',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
