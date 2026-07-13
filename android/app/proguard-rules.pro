# ML Kit Text Recognition: das Flutter-Plugin referenziert alle Sprach-
# Erkenner, gebundelt ist aber nur Latin (mehr braucht der MHD-Scan nicht).
# Die restlichen Sprachpakete sind absichtlich nicht dabei — R8 soll ihre
# Abwesenheit ignorieren statt den Build abzubrechen.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
