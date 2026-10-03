// Prueba de widget básica para CENTINELA.
//
// El árbol principal de la app (CentinelaApp -> AuthGate) depende de Firebase,
// que no está inicializado en el entorno de pruebas. Por eso aquí probamos un
// widget aislado y sin dependencias externas: el botón de alerta.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:centinela/widgets/boton_alerta.dart';

void main() {
  testWidgets('BotonAlerta muestra su título y responde al toque', (
    WidgetTester tester,
  ) async {
    var presionado = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotonAlerta(
            color: const Color(0xFF990011),
            titulo: 'ARMA / RIESGO VITAL',
            subtitulo: 'Nivel 3 · Rojo',
            onTap: () => presionado = true,
          ),
        ),
      ),
    );

    // El texto del botón debe estar presente.
    expect(find.text('ARMA / RIESGO VITAL'), findsOneWidget);
    expect(find.text('Nivel 3 · Rojo'), findsOneWidget);

    // Al tocarlo, debe dispararse el callback.
    await tester.tap(find.byType(BotonAlerta));
    expect(presionado, isTrue);
  });
}
