import 'package:flutter/foundation.dart';

@immutable
class Co2Equivalent {
  const Co2Equivalent({
    required this.emoji,
    required this.label,
    required this.value,
  });
  final String emoji;
  final String label;
  final String value;
}

/// Übersetzt eine CO₂e-Menge (kg) in greifbare Alltags-Vergleiche.
///
/// ⚠️ Grobe Richtwerte — bewusst illustrativ, nicht exakt: der zugrunde
/// liegende CO₂-Wert ist selbst schon eine Kategorie-Schätzung, hier kommt
/// also Schätzung auf Schätzung. Im UI als „ungefähr" rahmen.
class Co2Equivalents {
  Co2Equivalents._();

  // kg CO₂e pro Einheit (Richtwerte)
  static const _carKgPerKm = 0.15; // Benziner, real
  static const _busKgPerKm = 0.08; // Linienbus, pro Person
  static const _phoneChargeKg = 0.008; // eine Smartphone-Ladung
  static const _showerKg = 0.45; // eine warme Dusche
  static const _treeKgPerYear = 10.0; // Baum bindet grob ~10 kg/Jahr

  /// ~Einfacher Kurzstreckenflug München–Berlin (inkl. Höheneffekt).
  static const referenceFlightKg = 140.0;

  static List<Co2Equivalent> forKg(double kg) {
    if (kg <= 0) return const [];
    return [
      Co2Equivalent(
          emoji: '🚗',
          label: 'Autofahrt',
          value: '≈ ${_fmt(kg / _carKgPerKm)} km',),
      Co2Equivalent(
          emoji: '🚌',
          label: 'Busfahrt',
          value: '≈ ${_fmt(kg / _busKgPerKm)} km',),
      Co2Equivalent(
          emoji: '📱',
          label: 'Handy laden',
          value: '≈ ${_fmt(kg / _phoneChargeKg)}×',),
      Co2Equivalent(
          emoji: '🚿',
          label: 'Warm duschen',
          value: '≈ ${_fmt(kg / _showerKg)}×',),
      Co2Equivalent(
          emoji: '🌳',
          label: 'Baum-Arbeit',
          value: '≈ ${_fmt(kg / (_treeKgPerYear / 365))} Tage',),
    ];
  }

  /// Anteil an einem Kurzstreckenflug (0..1+).
  static double flightShare(double kg) => kg / referenceFlightKg;

  static String _fmt(double v) {
    if (v >= 10) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}
