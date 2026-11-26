import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

import 'package:equilink_admin/main.dart';

/// O login é desenhado acima do roteador, fora de qualquer `Navigator`. Sem uma
/// camada de sobreposição própria, focar o campo (o "Usuário" tem autofoco) ou
/// tocar nele quebrava ao mostrar as alças de seleção: EQL-042.
void main() {
  Future<void> abrirLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sem servidor, a consulta da sessão falha e o painel pede login.
    await tester.pumpWidget(
      PainelApp(fonte: FonteMemoria(), sessaoApi: SessaoApi(base: 'http://127.0.0.1:9')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Painel administrativo'), findsOneWidget);
  }

  testWidgets(
    'tocar e segurar os campos do login não quebra',
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    (tester) async {
      await abrirLogin(tester);

      final usuario = find.widgetWithText(TextField, 'Usuário');
      await tester.enterText(usuario, 'igor');
      await tester.tap(usuario);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.longPress(usuario);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.longPress(find.byTooltip('Mostrar senha'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
