import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equilink/app.dart';
import 'package:equilink_core/equilink_core.dart';

/// EQL-029: o perfil mostra o registro dos pais como foi gravado.
void main() {
  testWidgets('pai com registro AQHA não aparece como ABQM', (tester) async {
    final base = FonteMemoria.acervoDeDemonstracao();
    final principal = base.principal!;
    final fonte = FonteMemoria(
      inicial: Acervo(
        cavalos: [
          for (final c in base.cavalos)
            c.id == principal.id
                ? c.copiarCom(pai: c.pai.copiarCom(nome: 'PAI IMPORTADO', registro: 'AQHA 5037395'))
                : c,
        ],
        baias: base.baias,
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EquiLinkApp(fonte: fonte));
    await tester.pumpAndSettle();

    final aba = find.descendant(of: find.byType(ListView), matching: find.text('Genealogia'));
    await tester.ensureVisible(aba);
    await tester.pumpAndSettle();
    await tester.tap(aba);
    await tester.pumpAndSettle();

    expect(find.text('PAI IMPORTADO'), findsWidgets);
    expect(find.textContaining('AQHA 5037395', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('ABQM 5037395', skipOffstage: false), findsNothing);
  });
}
