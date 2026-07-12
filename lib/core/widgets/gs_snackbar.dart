import 'package:flutter/material.dart';

/// Kompakte SnackBar mit dezentem „Rückgängig"-Link. Nimmt den
/// [ScaffoldMessengerState], damit Undo auch nach dem Pop des Screens geht.
void showGsUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
  String actionLabel = 'Rückgängig',
}) {
  final snackTheme = Theme.of(messenger.context).snackBarTheme;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        content: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(message),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                messenger.hideCurrentSnackBar();
                onUndo();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: snackTheme.actionTextColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
