import 'package:flutter/material.dart';

/// Die verfügbaren Posen des Maskottchens "Löffeli".
enum MascotPose {
  waving, // Begrüßung (Onboarding)
  sleeping, // Leerer Vorrat — nichts zu tun
  searching, // Keine Rezepte gefunden
  celebrating, // Erfolg (Item verbraucht)
  confused, // Fehler-States
}

extension _MascotAsset on MascotPose {
  String get asset {
    switch (this) {
      case MascotPose.waving:
        return 'assets/mascot/mascot-waving.png';
      case MascotPose.sleeping:
        return 'assets/mascot/mascot-sleeping.png';
      case MascotPose.searching:
        return 'assets/mascot/mascot-searching.png';
      case MascotPose.celebrating:
        return 'assets/mascot/mascot-celebrating.png';
      case MascotPose.confused:
        return 'assets/mascot/mascot-confused.png';
    }
  }
}

/// Zeigt das Maskottchen in einer bestimmten Pose.
/// Standardgröße ist 140px, anpassbar über [size].
class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    required this.pose,
    this.size = 140,
  });

  final MascotPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      pose.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Falls ein Asset mal fehlt, fällt's nicht hart aus
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
      ),
    );
  }
}
