import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../providers/avatar_providers.dart';

/// Runder Profil-Avatar. Zeigt das lokal gewählte Bild, sonst die Initiale
/// auf grünem Grund. Optional mit Kamera-Badge (z.B. im Profil-Header).
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.initial,
    required this.size,
    this.showEditBadge = false,
  });

  final String initial;
  final double size;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(avatarProvider).valueOrNull;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GSColors.primary,
        shape: BoxShape.circle,
        image: file != null
            ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: file == null
          ? Text(
              initial,
              textAlign: TextAlign.center,
              style: GSTypography.headline(
                color: GSColors.cream,
                size: size * 0.44,
                weight: FontWeight.w500,
              ).copyWith(
                // headline() ist auf Fließtext ausgelegt (height 1.02,
                // negatives letterSpacing). Bei einer Einzel-Initiale
                // schiebt das den Glyph über die optische Mitte des
                // Kreises. height 1 + gleichmäßig verteiltes Leading
                // zentrieren den Großbuchstaben exakt.
                height: 1.0,
                letterSpacing: 0,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            )
          : null,
    );

    if (!showEditBadge) return avatar;

    final badge = size * 0.36;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: GSColors.accent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.camera_alt,
                size: badge * 0.5,
                color: GSColors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Öffnet das Auswahl-Sheet: Galerie, Kamera und (falls vorhanden) Entfernen.
Future<void> showAvatarPicker(
  BuildContext context,
  WidgetRef ref, {
  required bool hasAvatar,
}) async {
  final tone = GSTone.of(context);
  final surface = tone.surface;
  final inkColor = tone.ink;
  final muteColor = tone.inkMute;
  final lineColor = tone.line;

  final messenger = ScaffoldMessenger.of(context);

  Future<void> doPick(ImageSource source) async {
    try {
      await ref.read(avatarProvider.notifier).pick(source);
    } catch (e) {
      final text = e.toString().contains('MissingPluginException')
          ? 'Bild-Plugin noch nicht aktiv — bitte die App einmal komplett neu '
              'bauen (flutter clean, dann neu starten).'
          : 'Bild konnte nicht übernommen werden: $e';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: lineColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Text(
                      'Profilbild',
                      style: GSTypography.headline(color: inkColor, size: 20),
                    ),
                  ],
                ),
              ),
              _AvatarOption(
                icon: Icons.photo_library_outlined,
                label: 'Aus der Galerie wählen',
                inkColor: inkColor,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  doPick(ImageSource.gallery);
                },
              ),
              Container(height: 1, color: lineColor),
              _AvatarOption(
                icon: Icons.camera_alt_outlined,
                label: 'Foto aufnehmen',
                inkColor: inkColor,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  doPick(ImageSource.camera);
                },
              ),
              if (hasAvatar) ...[
                Container(height: 1, color: lineColor),
                _AvatarOption(
                  icon: Icons.delete_outline,
                  label: 'Bild entfernen',
                  inkColor: GSColors.accent,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    ref.read(avatarProvider.notifier).remove();
                  },
                ),
              ],
              const SizedBox(height: 6),
              _AvatarOption(
                icon: Icons.close,
                label: 'Abbrechen',
                inkColor: muteColor,
                onTap: () => Navigator.of(sheetCtx).pop(),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    },
  );
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.inkColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: inkColor, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: GSTypography.body(
                color: inkColor,
                size: 15,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
