/// Anzeigename aus einer E-Mail („fabian.zell@web.de" → „Fabian");
/// `null`, wenn nichts Brauchbares übrig bleibt.
String? deriveDisplayNameFromEmail(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return null;

  final first = local.split(RegExp(r'[._\-+]')).first;
  final letters = first.replaceAll(RegExp(r'[^a-zA-ZäöüÄÖÜß]'), '');
  if (letters.length < 2) return null;

  return letters[0].toUpperCase() + letters.substring(1).toLowerCase();
}
