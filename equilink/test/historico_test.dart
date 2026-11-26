import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equilink/app.dart';
import 'package:equilink_core/equilink_core.dart';

/// EQL-026: filtro "Todos" e gráfico de evolução mensal do histórico.
void main() {
  Prova prova(String id, String nome, DateTime data, double tempo) => Prova(
    id: id,
    data: data,
    nome: nome,
    local: '',
    categoria: 'Três Tambores',
    colocacao: 2,
    tempoSegundos: tempo,
    inscritos: 0,
  );

  /// Acervo de demonstração com as provas do destaque trocadas por [provas].
  FonteMemoria fonteCom(List<Prova> provas) {
    final base = FonteMemoria.acervoDeDemonstracao();
    final principal = base.principal!;
    return FonteMemoria(
      inicial: Acervo(
        cavalos: [
          for (final c in base.cavalos) c.id == principal.id ? c.copiarCom(provas: provas) : c,
        ],
        baias: base.baias,
      ),
    );
  }

  Future<void> abrirHistorico(WidgetTester tester, FonteMemoria fonte) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EquiLinkApp(fonte: fonte));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Histórico')),
    );
    await tester.pumpAndSettle();
  }

  Finder textoProva(String nome) => find.textContaining(nome, skipOffstage: false);

  testWidgets('o chip Todos mostra as provas de todos os anos', (tester) async {
    await abrirHistorico(
      tester,
      fonteCom([
        prova('a', 'PROVA NOVA', DateTime(2026, 9, 6), 17.1),
        prova('b', 'PROVA ANTIGA', DateTime(2025, 9, 28), 17.5),
      ]),
    );

    // Começa no ano mais recente.
    expect(textoProva('PROVA NOVA'), findsOneWidget);
    expect(textoProva('PROVA ANTIGA'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(textoProva('PROVA NOVA'), findsOneWidget);
    expect(textoProva('PROVA ANTIGA'), findsOneWidget);

    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    expect(textoProva('PROVA NOVA'), findsNothing);
    expect(textoProva('PROVA ANTIGA'), findsOneWidget);
  });

  testWidgets('no gráfico mensal, o mês mais rápido tem a barra mais alta', (tester) async {
    await abrirHistorico(
      tester,
      fonteCom([
        prova('a', 'LENTA', DateTime(2026, 1, 10), 20),
        prova('b', 'RAPIDA', DateTime(2026, 2, 10), 16),
      ]),
    );
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();

    final barras = tester
        .widgetList<FractionallySizedBox>(
          find.byWidgetPredicate(
            (w) => w is FractionallySizedBox && w.heightFactor != null,
            skipOffstage: false,
          ),
        )
        .map((b) => b.heightFactor!)
        .toList();
    expect(barras, hasLength(2));
    expect(barras[1], greaterThan(barras[0]), reason: 'fevereiro (16 s) foi mais rápido que janeiro (20 s)');
  });
}
