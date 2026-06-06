import 'package:flutter/material.dart';
import 'package:ai/core/models/interest.dart';

class InterestsSelector extends StatefulWidget {
  final List<InterestModel> initialSelected;
  final Function(List<InterestModel>) onChanged;

  const InterestsSelector({
    super.key,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<InterestsSelector> createState() => _InterestsSelectorState();
}

class _InterestsSelectorState extends State<InterestsSelector> {
  late List<InterestModel> _selected;

  final List<String> _customInterests = [];

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = [];

    for (final item in widget.initialSelected) {
      final existsInDefault = kInterests.any((e) => e.label == item.label);

      if (existsInDefault) {
        _selected.add(item);
      } else {
        _customInterests.add(item.label);
      }
    }
  }

  void _notifyChanges() {
    final customModels = _customInterests.map(
      (e) => InterestModel(label: e, icon: Icons.tag),
    );

    widget.onChanged([..._selected, ...customModels]);
  }

  void _toggleInterest(InterestModel item) {
    setState(() {
      final exists = _selected.any((e) => e.label == item.label);

      if (exists) {
        _selected.removeWhere((e) => e.label == item.label);
      } else {
        _selected.add(item);
      }
    });

    _notifyChanges();
  }

  void _addCustomInterest() {
    final val = _controller.text.trim();

    if (val.isEmpty) return;

    final exists = [
      ..._selected.map((e) => e.label.toLowerCase()),
      ..._customInterests.map((e) => e.toLowerCase()),
    ].contains(val.toLowerCase());

    if (exists) return;

    setState(() {
      _customInterests.add(val);
      _controller.clear();
    });

    _notifyChanges();
  }

  @override
  Widget build(BuildContext context) {
    final total = _selected.length + _customInterests.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFFF8F7FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE0DEF7)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF755DC1),
              ),

              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Add your own interest...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _addCustomInterest(),
                ),
              ),

              TextButton(
                onPressed: _addCustomInterest,
                child: Text(
                  "+ Add",
                  style: TextStyle(
                    color: Color(0xFF755DC1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        if (total > 0)
          Text(
            "$total interests selected",
            style: TextStyle(
              color: Color(0xFF755DC1),
              fontWeight: FontWeight.w600,
            ),
          ),

        SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _customInterests.map((tag) {
            return Chip(
              label: Text(tag, style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF755DC1),
              deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
              onDeleted: () {
                setState(() {
                  _customInterests.remove(tag);
                });

                _notifyChanges();
              },
            );
          }).toList(),
        ),

        SizedBox(height: 20),

        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: kInterests.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, i) {
            final item = kInterests[i];

            final selected = _selected.any((e) => e.label == item.label);

            return GestureDetector(
              onTap: () => _toggleInterest(item),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected
                      ? Color(0xFF755DC1).withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? Color(0xFF755DC1) : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: selected ? Color(0xFF755DC1) : Colors.grey,
                    ),

                    SizedBox(width: 8),

                    Flexible(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected ? Color(0xFF755DC1) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
