import 'package:ai/core/models/interest.dart';
import 'package:ai/features/interests/widgets/interests_selector.dart';
import 'package:flutter/material.dart';

class InterestsSheet extends StatefulWidget {
  final List<InterestModel> currentSelected;
  final Future<bool> Function(List<InterestModel>) onSave;

  const InterestsSheet({
    super.key,
    required this.currentSelected,
    required this.onSave,
  });

  @override
  State<InterestsSheet> createState() => _InterestsSheetState();
}

class _InterestsSheetState extends State<InterestsSheet> {
  late List<InterestModel> _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.currentSelected);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final ok = await widget.onSave(_selected);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save interests. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Interests',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selected.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(_selected.length),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF755DC1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selected.length} selected',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF755DC1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InterestsSelector(
              initialSelected: _selected,
              onChanged: (data) => setState(() => _selected = data),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF755DC1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF755DC1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF755DC1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Interests',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
