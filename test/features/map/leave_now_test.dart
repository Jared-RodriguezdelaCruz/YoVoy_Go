import 'package:flutter_test/flutter_test.dart';
import 'package:yovoy_go/core/models/models.dart';
import 'package:yovoy_go/features/map/application/leave_now.dart';

/// "¿Ya me voy?": los cuatro estados de `FEATURES.md` y la regla que la hace
/// confiable —sin dato en vivo no hay cuenta regresiva.
void main() {
  final DateTime now = DateTime(2026, 9, 20, 7);
  const Duration walk = Duration(minutes: 7);

  Arrival arrival({
    Duration? eta,
    EtaConfidence confidence = EtaConfidence.live,
    Duration dataAge = const Duration(seconds: 10),
  }) => Arrival(
    routeId: 'R_20N',
    routeShortName: 'R20N',
    headsign: 'Centro',
    eta: eta,
    confidence: confidence,
    dataAge: dataAge,
  );

  LeaveNowAdvice advise(Arrival a, {Arrival? following}) => LeaveNow.advise(
    stopName: 'Plaza San Marcos',
    arrival: a,
    following: following,
    walk: walk,
    now: now,
  );

  test('alcanzas con margen: "Sal en N min"', () {
    final LeaveNowAdvice advice = advise(
      arrival(eta: const Duration(minutes: 14)),
    );
    expect(advice, isA<LeaveIn>());
    // 14 de ETA − 7 a pie − 1 de holgura.
    expect(advice.headline, 'Sal en 6 min');
    expect(
      advice.detail,
      '7 min a pie a Plaza San Marcos · R20N llega en 14 min',
    );
    expect(advice.isCountdown, isTrue);
  });

  test('"Sal en" redondea hacia abajo: nunca te dice que salgas tarde', () {
    final LeaveNowAdvice advice = advise(
      arrival(eta: const Duration(minutes: 14, seconds: 50)),
    );
    expect(advice.headline, 'Sal en 6 min');
  });

  test('justo: "Sal ya"', () {
    final LeaveNowAdvice advice = advise(
      arrival(eta: const Duration(minutes: 8, seconds: 30)),
    );
    expect(advice, isA<LeaveRightNow>());
    expect(advice.headline, 'Sal ya');
  });

  test('ya no alcanzas: se dice cuál sigue', () {
    final LeaveNowAdvice advice = advise(
      arrival(eta: const Duration(minutes: 4)),
      following: arrival(eta: const Duration(minutes: 14)),
    );
    expect(advice, isA<TooLate>());
    expect(advice.headline, 'Vas tarde. El siguiente, en 14 min');
  });

  test('ya no alcanzas y no hay siguiente: no se inventa uno', () {
    final LeaveNowAdvice advice = advise(
      arrival(eta: const Duration(minutes: 4)),
    );
    expect(advice.headline, 'Vas tarde');
  });

  test('con dato vencido no hay cuenta regresiva', () {
    final LeaveNowAdvice advice = advise(
      arrival(
        eta: const Duration(minutes: 14),
        dataAge: const Duration(minutes: 4),
      ),
    );
    expect(advice, isA<NoSignal>());
    expect(advice.isCountdown, isFalse);
    expect(advice.headline, 'Sin señal de la R20N');
    expect(advice.headline, isNot(contains('Sal en')));
  });

  test('sin ETA tampoco', () {
    final LeaveNowAdvice advice = advise(
      arrival(confidence: EtaConfidence.unknown),
    );
    expect(advice, isA<NoSignal>());
  });

  test('solo con horario: hora de reloj, nunca cuenta regresiva', () {
    final LeaveNowAdvice advice = advise(
      arrival(
        eta: const Duration(minutes: 20),
        confidence: EtaConfidence.scheduled,
        dataAge: Duration.zero,
      ),
    );
    expect(advice, isA<LeaveBySchedule>());
    expect(advice.isCountdown, isFalse);
    // 7:00 + 20 − 7 − 1 = 7:12.
    expect(advice.headline, 'Sal 7:12 para el horario');
    expect(advice.detail, contains('según horario'));
  });

  test('la caminata usa 4.5 km/h con el rodeo de las calles', () {
    // 600 m en línea recta × 1.3 de rodeo ÷ 1.25 m/s = 624 s.
    expect(LeaveNow.walkTime(600), const Duration(seconds: 624));
  });

  test('los minutos a pie nunca dicen cero', () {
    expect(roundedMinutes(const Duration(seconds: 20)), 1);
    expect(roundedMinutes(const Duration(seconds: 61)), 2);
  });
}
