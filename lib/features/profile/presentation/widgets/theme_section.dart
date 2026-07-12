import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../settings/theme_providers.dart';
import 'settings_tiles.dart';

/// „Darstellung"-Karte: Auswahl zwischen System / Hell / Dunkel.
class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    void select(ThemeMode m) =>
        ref.read(themeModeProvider.notifier).setMode(m);

    return SettingsCard(
      children: [
        _ThemeOption(
          mode: ThemeMode.system,
          current: current,
          icon: Icons.brightness_auto,
          label: 'System',
          sub: 'Folgt der Geräte-Einstellung',
          onSelect: select,
          isFirst: true,
        ),
        _ThemeOption(
          mode: ThemeMode.light,
          current: current,
          icon: Icons.light_mode_outlined,
          label: 'Hell',
          sub: 'Warmes Cream',
          onSelect: select,
        ),
        _ThemeOption(
          mode: ThemeMode.dark,
          current: current,
          icon: Icons.dark_mode_outlined,
          label: 'Dunkel',
          sub: 'Tiefes Tannengrün',
          onSelect: select,
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.current,
    required this.icon,
    required this.label,
    required this.sub,
    required this.onSelect,
    this.isFirst = false,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String label;
  final String sub;
  final ValueChanged<ThemeMode> onSelect;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final selected = mode == current;
    return Column(
      children: [
        if (!isFirst) const SettingsDivider(),
        InkWell(
          onTap: () => onSelect(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? tone.primary : tone.inkMute,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GSTypography.body(
                          color: tone.ink,
                          size: 14.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        sub,
                        style:
                            GSTypography.body(color: tone.inkMute, size: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: tone.primary, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
