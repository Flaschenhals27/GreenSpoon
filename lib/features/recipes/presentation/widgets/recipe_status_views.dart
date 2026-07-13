import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../shell/shell_providers.dart';
import '../../providers/recipe_cooldown_provider.dart';
import '../../providers/recipe_providers.dart';

/// Ladezustand, während Löffeli Rezepte generiert.
class RecipesLoadingView extends StatelessWidget {
  const RecipesLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          const Mascot(pose: MascotPose.searching, size: 140),
          const SizedBox(height: 16),
          Text(
            'Löffeli sucht passende Rezepte …',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: tone.inkMute, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Das kann ein paar Sekunden dauern — wir\nbauen die Vorschläge aus deinem Vorrat.',
            textAlign: TextAlign.center,
            style:
                GSTypography.body(color: tone.inkMute, size: 13, height: 1.45),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }
}

/// Gemeinsamer Status-Screen (Fehler/leer/keine Vorschläge): Pose, Texte,
/// eine Aktion, optionale Details. [cooldownGated] koppelt den Button an
/// den Reload-Cooldown.
class RecipeStatusView extends StatefulWidget {
  const RecipeStatusView({
    super.key,
    required this.pose,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.details,
    this.cooldownGated = false,
  });

  final MascotPose pose;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? details;
  final bool cooldownGated;

  @override
  State<RecipeStatusView> createState() => _RecipeStatusViewState();
}

class _RecipeStatusViewState extends State<RecipeStatusView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Mascot(pose: widget.pose, size: 150),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: tone.ink, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: tone.inkMute,
              size: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.cooldownGated)
            Consumer(
              builder: (context, ref, _) {
                final cooldown = ref.watch(recipeCooldownProvider);
                final onCooldown = cooldown > 0;
                return _ActionButton(
                  label: onCooldown
                      ? 'Bitte warten … ${cooldown}s'
                      : widget.actionLabel,
                  onPressed: onCooldown ? null : widget.onAction,
                );
              },
            )
          else
            _ActionButton(label: widget.actionLabel, onPressed: widget.onAction),
          if (widget.details != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: tone.inkMute,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Technische Details',
                    style: GSTypography.body(color: tone.inkMute, size: 12),
                  ),
                ],
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Text(
                widget.details!,
                textAlign: TextAlign.center,
                style: GSTypography.body(
                  color: tone.inkMute,
                  size: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
      child: Text(label),
    );
  }
}

/// Wenn der User keinen Vorrat hat — schickt ihn dezent zum Vorrat-Tab.
class PantryEmptyView extends ConsumerWidget {
  const PantryEmptyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RecipeStatusView(
      pose: MascotPose.sleeping,
      title: 'Noch nichts zum Kochen',
      message:
          'Füge ein paar Lebensmittel zum Vorrat hinzu, dann\nschlägt dir Löffeli passende Rezepte vor.',
      actionLabel: 'Zum Vorrat',
      onAction: () =>
          ref.read(shellTabProvider.notifier).open(ShellTab.pantry),
    );
  }
}

/// Footer unter der Rezeptliste: Löffeli + Button, der ALLE Rezepte neu
/// vorschlägt. Nutzt denselben Cooldown wie die Retry-Buttons.
class RefreshFooter extends ConsumerWidget {
  const RefreshFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);
    final cooldown = ref.watch(recipeCooldownProvider);
    final onCooldown = cooldown > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Column(
        children: [
          const Mascot(pose: MascotPose.waving, size: 96),
          const SizedBox(height: 8),
          Text(
            onCooldown ? 'Einen Moment noch …' : 'Neue Rezepte gewünscht?',
            textAlign: TextAlign.center,
            style: GSTypography.headline(color: tone.ink, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Tipp: Halte eine Karte gedrückt, um nur\ndiese Mahlzeit neu vorzuschlagen.',
            textAlign: TextAlign.center,
            style:
                GSTypography.body(color: tone.inkMute, size: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCooldown
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    refreshRecipesIfAllowed(ref);
                  },
            icon: Icon(
              onCooldown ? Icons.hourglass_bottom : Icons.refresh,
              size: 18,
            ),
            label: Text(
              onCooldown
                  ? 'Bitte warten … ${cooldown}s'
                  : 'Alle neu vorschlagen',
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(220, 50)),
          ),
        ],
      ),
    );
  }
}
