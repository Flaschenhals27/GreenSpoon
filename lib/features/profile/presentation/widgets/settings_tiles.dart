import 'package:flutter/material.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';

/// Gemeinsame Bausteine der Profil-/Einstellungs-Sektionen.

/// Abschnitts-Überschrift („MEINE REZEPTE", „DARSTELLUNG", …).
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 10),
      child: Text(text, style: GSTypography.label(color: tone.inkMute)),
    );
  }
}

/// Abgerundete Karte, die mehrere Zeilen (Tiles) gruppiert.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Container(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

/// Haarlinie zwischen zwei Tiles einer [SettingsCard].
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: GSTone.of(context).line);
  }
}

/// Navigations-Zeile: Icon, Titel, Untertitel, Chevron.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: tone.inkMute, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GSTypography.body(
                      color: tone.ink,
                      size: 14.5,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GSTypography.body(color: tone.inkMute, size: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tone.inkMute, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Statistik-Zeile: Label links, große Zahl rechts.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GSTypography.body(color: tone.ink, size: 14),
            ),
          ),
          Text(
            value,
            style: GSTypography.headline(
              color: tone.ink,
              size: 22,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
