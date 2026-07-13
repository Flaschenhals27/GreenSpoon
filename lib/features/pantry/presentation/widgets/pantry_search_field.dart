import 'package:flutter/material.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';

/// Suchfeld unterm Header — erscheint nur bei aktiver Suche (Lupe).
class PantrySearchField extends StatelessWidget {
  const PantrySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Container(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, color: tone.inkMute, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: GSTypography.body(color: tone.ink, size: 15),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Name oder Marke suchen …',
                  hintStyle: GSTypography.body(color: tone.inkMute, size: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              Tooltip(
                message: 'Eingabe löschen',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.cancel, color: tone.inkMute, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
