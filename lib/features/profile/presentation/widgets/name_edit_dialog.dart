import 'package:flutter/material.dart';

/// Eingabe-Dialog für den Anzeigenamen. Besitzt seinen Controller selbst
/// (Disposal erst nach vollständigem Schließen der Route — kein Zugriff
/// auf einen toten Controller während der Ausblend-Animation).
class NameEditDialog extends StatefulWidget {
  const NameEditDialog({super.key, required this.initial});
  final String initial;

  @override
  State<NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<NameEditDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wie sollen wir dich nennen?'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 30,
        decoration: const InputDecoration(
          hintText: 'z.B. Fabian',
          counterText: '',
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          // Das Theme setzt volle Breite (Size.fromHeight) — in den
          // Dialog-Actions (OverflowBar, unbegrenzte Breite) würde das
          // eine unendliche Mindestbreite erzwingen → Layout-Crash.
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
