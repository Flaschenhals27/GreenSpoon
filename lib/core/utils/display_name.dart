/// Leitet einen präsentablen Anzeigenamen aus einer E-Mail-Adresse ab.
///
/// Heuristik: lokaler Teil vor dem @, an üblichen Trennzeichen (`.`, `_`,
/// `-`, `+`) gesplittet — der erste Teil ist meist der Vorname. Ziffern
/// fliegen raus, der Rest wird kapitalisiert.
///
///  - `fabian.zell@web.de`     → `Fabian`
///  - `fabianzell1502@gmx.de`  → `Fabianzell`
///  - `f_meier@firma.de`       → `F` → zu kurz → `null`
///
/// Liefert `null`, wenn nichts Brauchbares übrig bleibt — dann lieber
/// neutral grüßen als kryptisch.
String? deriveDisplayNameFromEmail(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return null;

  final first = local.split(RegExp(r'[._\-+]')).first;
  final letters = first.replaceAll(RegExp(r'[^a-zA-ZäöüÄÖÜß]'), '');
  if (letters.length < 2) return null;

  return letters[0].toUpperCase() + letters.substring(1).toLowerCase();
}
