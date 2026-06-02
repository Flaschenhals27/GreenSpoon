import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/gs_colors.dart';
import '../theme/gs_typography.dart';

/// Zeigt ein Bottom-Sheet mit drei scrollbaren Wheels (Tag, Monat, Jahr).
/// Liefert das gewählte Datum oder `null`, wenn abgebrochen wurde.
///
/// `initial`: Vollständiges Start-Datum (default: heute + 7 Tage).
/// `initialDay`/`initialMonth`/`initialYear`: einzeln vorbelegen, falls
/// nur Teile bekannt sind (z.B. aus partieller OCR-Erkennung).
Future<DateTime?> showGSDateSheet(
  BuildContext context, {
  DateTime? initial,
  int? initialDay,
  int? initialMonth,
  int? initialYear,
}) {
  final now = DateTime.now();
  final base = initial ?? now.add(const Duration(days: 7));

  final startDay = initialDay ?? base.day;
  final startMonth = initialMonth ?? base.month;
  final startYear = initialYear ?? base.year;

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GSDateSheet(
      initialDay: startDay,
      initialMonth: startMonth,
      initialYear: startYear,
    ),
  );
}

class _GSDateSheet extends StatefulWidget {
  const _GSDateSheet({
    required this.initialDay,
    required this.initialMonth,
    required this.initialYear,
  });

  final int initialDay;
  final int initialMonth;
  final int initialYear;

  @override
  State<_GSDateSheet> createState() => _GSDateSheetState();
}

class _GSDateSheetState extends State<_GSDateSheet> {
  late int _day;
  late int _month;
  late int _year;

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  static const _monthNames = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    final nowYear = DateTime.now().year;
    // Jahr-Range: aktuelles Jahr bis +6 (typisches MHD-Fenster)
    _years = List.generate(7, (i) => nowYear + i);

    _day = widget.initialDay.clamp(1, 31);
    _month = widget.initialMonth.clamp(1, 12);
    _year = _years.contains(widget.initialYear) ? widget.initialYear : nowYear;

    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl = FixedExtentScrollController(
      initialItem: _years.indexOf(_year),
    );
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  /// Tage im aktuell gewählten Monat (Schaltjahr-bewusst).
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  /// Wenn Tag > Tage im Monat, korrigieren (z.B. 31 → 30 bei Monatswechsel).
  void _adjustDayIfNeeded() {
    final max = _daysInMonth;
    if (_day > max) {
      setState(() => _day = max);
      _dayCtrl.animateToItem(
        _day - 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _confirm() {
    Navigator.of(context).pop(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GSColors.cardDark : GSColors.cardLight;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    final fmt = DateFormat('EEEE, d. MMMM y', 'de_DE');
    final preview =
        fmt.format(DateTime(_year, _month, _day.clamp(1, _daysInMonth)));

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag-Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: subtleColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Mindesthaltbar',
            style: GSTypography.label(color: subtleColor),
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            style: GSTypography.headline(color: textColor, size: 22),
          ),
          const SizedBox(height: 12),

          // Drei Wheels
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Tag
                Expanded(
                  flex: 2,
                  child: _WheelPicker(
                    controller: _dayCtrl,
                    itemCount: _daysInMonth,
                    builder: (i) => Text(
                      (i + 1).toString(),
                      style: GSTypography.body(
                        color: textColor,
                        size: 20,
                        weight: FontWeight.w500,
                      ),
                    ),
                    onChanged: (i) => setState(() => _day = i + 1),
                  ),
                ),
                // Monat
                Expanded(
                  flex: 4,
                  child: _WheelPicker(
                    controller: _monthCtrl,
                    itemCount: 12,
                    builder: (i) => Text(
                      _monthNames[i],
                      style: GSTypography.body(
                        color: textColor,
                        size: 18,
                        weight: FontWeight.w500,
                      ),
                    ),
                    onChanged: (i) {
                      setState(() => _month = i + 1);
                      _adjustDayIfNeeded();
                    },
                  ),
                ),
                // Jahr
                Expanded(
                  flex: 3,
                  child: _WheelPicker(
                    controller: _yearCtrl,
                    itemCount: _years.length,
                    builder: (i) => Text(
                      _years[i].toString(),
                      style: GSTypography.body(
                        color: textColor,
                        size: 20,
                        weight: FontWeight.w500,
                      ),
                    ),
                    onChanged: (i) {
                      setState(() => _year = _years[i]);
                      _adjustDayIfNeeded();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Abbrechen',
                    style: TextStyle(color: subtleColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _confirm,
                  child: const Text('Übernehmen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  const _WheelPicker({
    required this.controller,
    required this.itemCount,
    required this.builder,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final Widget Function(int index) builder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      onSelectedItemChanged: onChanged,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: GSColors.primary.withValues(alpha: 0.12),
      ),
      children: [
        for (var i = 0; i < itemCount; i++) Center(child: builder(i)),
      ],
    );
  }
}
