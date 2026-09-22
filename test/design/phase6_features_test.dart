import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/core/transit/reliability.dart';
import 'package:yovoy_go/design/components/components.dart';

import 'components_test.dart' show pumpComponent;

/// Las piezas de las features de la fase 6: frecuencia, ocupación y
/// confiabilidad.
void main() {
  group('FrequencyCopy', () {
    test('redondea a 5 minutos, como lo dice el poste', () {
      // 1199 s es lo que trae el feed: se dice "cada 20", no "cada 19.98".
      expect(FrequencyCopy.label(const Duration(seconds: 1199)), 'cada 20 min');
      expect(FrequencyCopy.label(const Duration(minutes: 10)), 'cada 10 min');
    });

    test('lejos de un múltiplo de 5 da el rango, no un número falso', () {
      expect(
        FrequencyCopy.label(const Duration(minutes: 17)),
        'cada 15–20 min',
      );
      expect(
        FrequencyCopy.spoken(const Duration(minutes: 17)),
        'cada 15 a 20 minutos',
      );
    });

    test('abajo de 5 minutos se da exacto', () {
      expect(FrequencyCopy.label(const Duration(minutes: 3)), 'cada 3 min');
      expect(FrequencyCopy.spoken(const Duration(minutes: 1)), 'cada 1 minuto');
    });
  });

  group('EtaChip con frecuencia', () {
    testWidgets('un horario no se pinta como minuto exacto', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 10),
          confidence: EtaConfidence.scheduled,
          dataAge: Duration.zero,
          headway: Duration(minutes: 20),
        ),
      );

      expect(find.text('cada 20 min'), findsOneWidget);
      expect(find.text('según horario'), findsOneWidget);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('un número en vivo le gana a la frecuencia', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: Duration(minutes: 4),
          confidence: EtaConfidence.live,
          dataAge: Duration(seconds: 10),
          headway: Duration(minutes: 20),
        ),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('cada 20 min'), findsNothing);
    });

    testWidgets('sin señal, la frecuencia sustituye al "no sé"', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const EtaChip(
          eta: null,
          confidence: EtaConfidence.unknown,
          dataAge: Duration(minutes: 5),
          headway: Duration(minutes: 20),
        ),
      );

      expect(find.text('cada 20 min'), findsOneWidget);
    });

    test('el lector de pantalla lo dice completo', () {
      expect(
        EtaChip.describe(
          eta: const Duration(minutes: 10),
          confidence: EtaConfidence.scheduled,
          dataAge: Duration.zero,
          headway: const Duration(minutes: 20),
        ),
        'pasa cada 20 minutos, según horario',
      );
      expect(
        EtaChip.describe(
          eta: null,
          confidence: EtaConfidence.unknown,
          dataAge: const Duration(minutes: 5),
          headway: const Duration(minutes: 20),
        ),
        'sin señal de este camión; pasa cada 20 minutos, según horario',
      );
    });
  });

  group('OccupancyIndicator', () {
    test('los seis valores caben en tres grados', () {
      expect(OccupancyLevel.of(OccupancyStatus.empty), OccupancyLevel.empty);
      expect(
        OccupancyLevel.of(OccupancyStatus.manySeatsAvailable),
        OccupancyLevel.empty,
      );
      expect(
        OccupancyLevel.of(OccupancyStatus.fewSeatsAvailable),
        OccupancyLevel.filling,
      );
      expect(
        OccupancyLevel.of(OccupancyStatus.standingRoomOnly),
        OccupancyLevel.filling,
      );
      expect(
        OccupancyLevel.of(OccupancyStatus.crushedStandingRoomOnly),
        OccupancyLevel.full,
      );
      expect(OccupancyLevel.of(OccupancyStatus.full), OccupancyLevel.full);
    });

    testWidgets('la palabra siempre acompaña a las figuras', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const OccupancyIndicator(status: OccupancyStatus.standingRoomOnly),
      );

      expect(find.textContaining('va llenándose'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNWidgets(2));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('sin dato no pinta nada', (WidgetTester tester) async {
      await pumpComponent(tester, const OccupancyIndicator(status: null));

      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    test('el anuncio de la fila lo incluye', () {
      const Arrival lleno = Arrival(
        routeId: 'R_03',
        routeShortName: 'R03',
        headsign: 'UAA Sur',
        eta: Duration(minutes: 4),
        confidence: EtaConfidence.live,
        dataAge: Duration(seconds: 10),
        occupancyStatus: OccupancyStatus.full,
      );

      expect(arrivalAnnouncement(lleno), endsWith(', va lleno'));
      expect(
        arrivalAnnouncement(lleno.copyWith(occupancyStatus: null)),
        isNot(contains('va ')),
      );
    });
  });

  group('ReliabilityCopy', () {
    ReliabilityStat stat({
      int observations = 14,
      int median = 3,
      int p10 = 1,
      int p90 = 5,
    }) => ReliabilityStat(
      observations: observations,
      medianDelay: Duration(minutes: median),
      p10: Duration(minutes: p10),
      p90: Duration(minutes: p90),
    );

    test('con pocas observaciones calla', () {
      expect(ReliabilityCopy.describe(null), isNull);
      expect(ReliabilityCopy.describe(stat(observations: 4)), isNull);
    });

    test('con varianza baja da el número y de dónde sale', () {
      expect(
        ReliabilityCopy.describe(stat()),
        'suele llegar 3 min tarde · según 14 observaciones tuyas',
      );
    });

    test('a tiempo y antes también se dicen', () {
      expect(
        ReliabilityCopy.describe(stat(median: 0, p10: -1, p90: 2)),
        startsWith('suele llegar a tiempo'),
      );
      expect(
        ReliabilityCopy.describe(stat(median: -2, p10: -3, p90: 0)),
        startsWith('suele llegar 2 min antes'),
      );
    });

    test('con varianza alta admite que es irregular', () {
      expect(
        ReliabilityCopy.describe(stat(p10: 2, p90: 11)),
        'irregular, entre 2 y 11 min tarde · según 14 observaciones tuyas',
      );
      expect(
        ReliabilityCopy.describe(stat(median: 2, p10: -2, p90: 9)),
        startsWith('irregular, entre 2 min antes y 9 min tarde'),
      );
    });

    testWidgets('la nota sin texto no ocupa lugar', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, const ReliabilityNote(text: null));

      expect(find.byIcon(Icons.history), findsNothing);
    });
  });
}
