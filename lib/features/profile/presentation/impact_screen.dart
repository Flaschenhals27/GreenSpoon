import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../../pantry/domain/user_stats.dart';
import '../domain/co2_equivalents.dart';
import '../providers/profile_providers.dart';

/// Detailseite zur „Dein Impact"-Kachel: übersetzt CO₂ in Alltags-Vergleiche
/// und zeigt die ehrliche Wegwerf-/Verwertungs-Bilanz.
class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});

  // Bundesschnitt vermeidbarer + unvermeidbarer Lebensmittelabfall:
  // ~75 kg/Person/Jahr (Statistisches Bundesamt) ≈ 1,5 kg/Woche.
  static const _avgWastePerWeekKg = 1.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final async = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Tooltip(
                message: 'Zurück',
                child: Material(
                  color: surfaceColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: lineColor),
                      ),
                      child:
                          Icon(Icons.chevron_left, color: inkColor, size: 22),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEIN IMPACT',
                    style: GSTypography.label(color: muteColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Was du bewirkst',
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: GSColors.primary),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Stats konnten nicht geladen werden.',
                      style: GSTypography.body(color: muteColor, size: 14),
                    ),
                  ),
                ),
                data: (s) => _body(context, s, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, UserStats s, bool isDark) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final equivalents = Co2Equivalents.forKg(s.co2SavedKg);
    final flightShare = Co2Equivalents.flightShare(s.co2SavedKg);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
      children: [
        // ── 1. Die Wegwerf-Bilanz zuerst: das ist die ehrliche, nicht
        // „gamebare" Kennzahl (misst das Outcome direkt, keine
        // Kontrafaktik). CO₂ folgt bewusst erst danach als Schätzung.
        Text('DEINE BILANZ', style: GSTypography.label(color: muteColor)),
        const SizedBox(height: 12),
        _BalanceCard(stats: s, isDark: isDark, avgWeek: _avgWastePerWeekKg),

        const SizedBox(height: 16),

        // Buzzer-Saves
        _BuzzerCard(saves: s.buzzerSaves, isDark: isDark),

        const SizedBox(height: 26),

        // ── 2. CO₂ — kompakter als früher und klar als Schätzung
        // gerahmt, damit die Zahl nicht zum Highscore wird.
        Text(
          'CO₂ VERMIEDEN · SCHÄTZUNG',
          style: GSTypography.label(color: muteColor),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: GSColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmtKg(s.co2SavedKg)} kg',
                style: GSTypography.headline(
                  color: GSColors.cream,
                  size: 34,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'in Lebensmitteln, die du kurz vor der Tonne noch gerettet hast',
                    style: GSTypography.body(
                      color: GSColors.cream.withValues(alpha: 0.85),
                      size: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Äquivalente
        Text(
          'DAS ENTSPRICHT UNGEFÄHR',
          style: GSTypography.label(color: muteColor),
        ),
        const SizedBox(height: 12),
        if (equivalents.isEmpty)
          Text(
            'Sobald du etwas kurz vor dem MHD rettest, rechnen wir es hier in Alltags-Dinge um.',
            style: GSTypography.body(color: muteColor, size: 13.5, height: 1.4),
          )
        else ...[
          ...equivalents.map((e) => _EquivalentRow(e: e, isDark: isDark)),
          const SizedBox(height: 6),
          Text(
            flightShare >= 0.01
                ? '… oder ${(flightShare * 100).round()} % eines Flugs München–Berlin.'
                : 'Ein Flug München–Berlin wären übrigens ~140 kg.',
            style: GSTypography.italicCaption(color: muteColor)
                .copyWith(fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Grobe Richtwerte — gedacht zum Veranschaulichen, nicht als exakte Messung.',
          style: GSTypography.body(color: muteColor, size: 11.5, height: 1.4),
        ),

        const SizedBox(height: 26),

        // ── 3. Methodik — macht die Zahlen erklärbar und angreifbar-sicher.
        Text('SO RECHNEN WIR', style: GSTypography.label(color: muteColor)),
        const SizedBox(height: 12),
        _MethodologyCard(isDark: isDark),

        const SizedBox(height: 16),

        // €
        if (s.eurSaved > 0)
          Text(
            'Geschätzt ${s.eurSaved.toStringAsFixed(0)} € an Lebensmitteln nicht in die Tonne — über die ganze Zeit.',
            style: GSTypography.body(color: inkColor, size: 13.5, height: 1.4),
          ),
      ],
    );
  }

  String _fmtKg(double kg) {
    if (kg >= 10) return kg.toStringAsFixed(0);
    return kg.toStringAsFixed(1);
  }
}

/// Erklärt die Kontrafaktik hinter „CO₂ vermieden" in drei Schritten —
/// bewusst transparent, damit die Zahl nicht nach Greenwashing aussieht.
class _MethodologyCard extends StatelessWidget {
  const _MethodologyCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    const steps = [
      (
        emoji: '⏳',
        text:
            'Nur Rettungen zählen: Lebensmittel, die du in den letzten 3 Tagen vor dem MHD (oder danach) noch verwertet hast.',
      ),
      (
        emoji: '🗑️',
        text:
            'Ohne dich wären sie wahrscheinlich im Müll gelandet — ihr Produktions-CO₂ wäre umsonst gewesen und du hättest Ersatz gekauft.',
      ),
      (
        emoji: '🧮',
        text:
            'Das CO₂ kommt aus Produktdaten oder einer Kategorie-Schätzung. Normal gegessene Lebensmittel zählen bewusst nicht — die vermeiden nichts.',
      ),
      (
        emoji: '🍽️',
        text:
            'Und: Extra warten lohnt sich nicht. Frisch gegessen ist genauso gerettet — nur sicherer. Die Zahl ist ein Anhaltspunkt, kein Highscore.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          for (final (i, step) in steps.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.text,
                    style: GSTypography.body(
                      color: i == 0 ? inkColor : muteColor,
                      size: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EquivalentRow extends StatelessWidget {
  const _EquivalentRow({required this.e, required this.isDark});
  final Co2Equivalent e;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: [
          Text(e.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              e.label,
              style: GSTypography.body(
                color: inkColor,
                size: 14.5,
                weight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            e.value,
            style: GSTypography.body(
              color: muteColor,
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.stats,
    required this.isDark,
    required this.avgWeek,
  });
  final UserStats stats;
  final bool isDark;
  final double avgWeek;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final ratePct = (stats.useRate * 100).round();
    final thisM = stats.wastedKgThisMonth;
    final lastM = stats.wastedKgLastMonth;
    final improved = thisM < lastM;
    final hasTrend = lastM > 0 || thisM > 0;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats.hasHistory) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$ratePct %',
                  style: GSTypography.headline(
                    color: GSColors.primary,
                    size: 40,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'verwertet statt\nweggeworfen',
                    style: GSTypography.body(
                      color: muteColor,
                      size: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stats.useRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: GSColors.accent.withValues(alpha: 0.25),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(GSColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${stats.consumedTotal} verwertet · ${stats.wastedTotal} weggeworfen',
              style: GSTypography.body(color: muteColor, size: 12.5),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              'Noch keine Bilanz',
              style: GSTypography.headline(color: inkColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Wisch im Vorrat ein Item nach rechts (verbraucht) oder links (weggeworfen) — dann füllt sich deine Bilanz.',
              style:
                  GSTypography.body(color: muteColor, size: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          if (hasTrend) ...[
            Row(
              children: [
                Icon(
                  improved ? Icons.trending_down : Icons.trending_up,
                  color: improved ? GSColors.primary : GSColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diesen Monat ${_fmt(thisM)} kg weggeworfen '
                    '(${_fmt(lastM)} kg im Vormonat).',
                    style: GSTypography.body(
                      color: inkColor,
                      size: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Zum Einordnen: Im Schnitt wirft eine Person in Deutschland '
            '~${avgWeek.toStringAsFixed(1)} kg pro Woche weg (~75 kg/Jahr). '
            'Grobe Schätzung, dein Wert zählt nur, was du hier erfasst.',
            style: GSTypography.body(color: muteColor, size: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(1);
}

class _BuzzerCard extends StatelessWidget {
  const _BuzzerCard({required this.saves, required this.isDark});
  final int saves;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Mascot(pose: MascotPose.celebrating, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$saves× auf den letzten Drücker gerettet',
                  style: GSTypography.body(
                    color: inkColor,
                    size: 15.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'So oft hast du etwas noch in den letzten 3 Tagen vor dem MHD verwertet — sonst wär\'s wohl in der Tonne gelandet.',
                  style: GSTypography.body(
                    color: muteColor,
                    size: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
