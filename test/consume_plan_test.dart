import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/pantry/domain/consume_plan.dart';

void main() {
  group('planPieceConsumption', () {
    test('Teil-Verbrauch verkleinert die Stückzahl und teilt CO₂ anteilig', () {
      final plan = planPieceConsumption(
        quantity: '10 Stück',
        pieces: 3,
        totalCo2: 5.0,
      );
      expect(plan, isNotNull);
      expect(plan!.consumesWhole, isFalse);
      expect(plan.remainingQuantity, '7 Stück');
      expect(plan.consumedQuantity, '3 Stück');
      expect(plan.remainingCo2, closeTo(3.5, 1e-9));
      expect(plan.consumedCo2, closeTo(1.5, 1e-9));
    });

    test('ganze Menge gewählt → consumesWhole (Item archivieren)', () {
      final plan = planPieceConsumption(quantity: '3 Stück', pieces: 3);
      expect(plan!.consumesWhole, isTrue);
      expect(plan.remainingQuantity, isNull);
    });

    test('mehr als vorhanden → ebenfalls consumesWhole', () {
      final plan = planPieceConsumption(quantity: '2 Stück', pieces: 5);
      expect(plan!.consumesWhole, isTrue);
    });

    test('Stückzahl ohne Einheit bleibt einheitenlos', () {
      final plan = planPieceConsumption(quantity: '6', pieces: 2);
      expect(plan!.remainingQuantity, '4');
      expect(plan.consumedQuantity, '2');
    });

    test('wiegbare Menge ist nicht stückweise verbuchbar → null', () {
      expect(planPieceConsumption(quantity: '500 g', pieces: 1), isNull);
      expect(planPieceConsumption(quantity: '1,5 kg', pieces: 1), isNull);
    });

    test('unsinnige Stückzahl → null', () {
      expect(planPieceConsumption(quantity: '10 Stück', pieces: 0), isNull);
      expect(planPieceConsumption(quantity: '10 Stück', pieces: -2), isNull);
    });

    test('ohne CO₂-Wert bleiben die CO₂-Felder null', () {
      final plan = planPieceConsumption(quantity: '10 Stück', pieces: 4);
      expect(plan!.remainingCo2, isNull);
      expect(plan.consumedCo2, isNull);
    });
  });

  group('planAmountConsumption', () {
    test('gleiche Einheit: zieht den Betrag ab und teilt CO₂ anteilig', () {
      final plan = planAmountConsumption(
        quantity: '500 g',
        needed: '200 g',
        totalCo2: 1.0,
      );
      expect(plan!.consumesWhole, isFalse);
      expect(plan.remainingQuantity, '300 g');
      expect(plan.consumedQuantity, '200 g');
      expect(plan.consumedCo2, closeTo(0.4, 1e-9));
      expect(plan.remainingCo2, closeTo(0.6, 1e-9));
    });

    test('rechnet innerhalb der Familie um (kg ↔ g)', () {
      final plan = planAmountConsumption(quantity: '1,5 kg', needed: '200 g');
      expect(plan!.remainingQuantity, '1,3 kg');
      expect(plan.consumedQuantity, '0,2 kg');
    });

    test('Volumen: L ↔ ml, ohne Rundungsverlust', () {
      final plan = planAmountConsumption(quantity: '1 L', needed: '250 ml');
      expect(plan!.remainingQuantity, '0,75 L');
      expect(plan.consumedQuantity, '0,25 L');
    });

    test('Bedarf ≥ Bestand → consumesWhole', () {
      expect(
        planAmountConsumption(quantity: '200 g', needed: '200 g')!
            .consumesWhole,
        isTrue,
      );
      expect(
        planAmountConsumption(quantity: '200 g', needed: '300 g')!
            .consumesWhole,
        isTrue,
      );
    });

    test('inkompatible Einheiten → null', () {
      expect(planAmountConsumption(quantity: '500 g', needed: '1 EL'), isNull);
      expect(planAmountConsumption(quantity: '1 L', needed: '100 g'), isNull);
      expect(
        planAmountConsumption(quantity: '5 Stück', needed: '200 g'),
        isNull,
      );
    });
  });
}
