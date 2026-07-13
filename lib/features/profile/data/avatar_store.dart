import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale Persistenz des Profilbilds (App-Ordner + SharedPreferences,
/// kein Backend).
class AvatarStore {
  AvatarStore._();
  static const _kKey = 'profile_avatar_path';

  /// Liefert die aktuelle Avatar-Datei, falls vorhanden und noch existent.
  /// Räumt verwaiste Pfade (z.B. nach App-Update) automatisch auf.
  static Future<File?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kKey);
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) return file;
    await prefs.remove(_kKey);
    return null;
  }

  /// Bild aus Galerie/Kamera holen und dauerhaft speichern;
  /// `null` bei Abbruch.
  static Future<File?> pickAndSave({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    // Zeitstempel im Namen, damit Flutters FileImage-Cache (cached per Pfad)
    // nicht das alte Bild weiterzeigt.
    final dest = File(
      '${dir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(picked.path).copy(dest.path);

    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_kKey);
    await prefs.setString(_kKey, dest.path);

    // Alte Datei aufräumen.
    if (old != null && old != dest.path) {
      final oldFile = File(old);
      if (await oldFile.exists()) await oldFile.delete();
    }
    return dest;
  }

  /// Entfernt das Profilbild wieder.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kKey);
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      await prefs.remove(_kKey);
    }
  }
}
