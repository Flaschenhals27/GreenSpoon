import 'package:flutter/material.dart';

/// Zeigt eine kompakte SnackBar mit dezentem „Rückgängig"-Link.
///
/// Der Standard-[SnackBarAction] rendert als ausgewachsener TextButton
/// (erbt das fette TextButtonTheme: 14pt/w700 + großzügiges Padding) —
/// für einen beiläufigen Undo zu dominant. Hier: kleiner Link, aber mit
/// ausreichend Tap-Fläche (~40px hoch durch das Innen-Padding).
///
/// Nimmt den [ScaffoldMessengerState] statt eines BuildContext, damit
/// der Undo-Tap auch nach dem Pop des auslösenden Screens funktioniert
/// (die Call-Sites sichern den Messenger vor der Navigation).
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
