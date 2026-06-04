import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/avatar_store.dart';

/// Hält das lokale Profilbild (oder `null`). Lädt initial aus dem
/// App-Ordner und aktualisiert nach Auswahl/Entfernen.
class AvatarNotifier extends AsyncNotifier<File?> {
  @override
  Future<File?> build() async {
    return AvatarStore.load();
  }

  /// Wählt ein neues Bild aus der gegebenen Quelle und übernimmt es.
  /// Tut nichts, wenn der User abbricht.
  Future<void> pick(ImageSource source) async {
    final file = await AvatarStore.pickAndSave(source: source);
    if (file != null) {
      state = AsyncData(file);
    }
  }

  /// Entfernt das Profilbild wieder.
  Future<void> remove() async {
    await AvatarStore.clear();
    state = const AsyncData(null);
  }
}

final avatarProvider =
    AsyncNotifierProvider<AvatarNotifier, File?>(AvatarNotifier.new);
