import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

import 'package:equilink/app.dart';

/// Prova que o aplicativo instrumenta a jornada do usuário de ponta a ponta:
/// navegação, abertura de mídia, compartilhamento e geração de placa.
void main() {
  Future<ColetorMemoria> abrir(WidgetTester tester, {bool baias = false}) async {
    final coletor = ColetorMemoria();
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      EquiLinkApp(fonte: FonteMemoria(), analytics: Analytics(coletor), baias: baias),
    );
    await tester.pumpAndSettle();
    return coletor;
  }

  Future<void> irPara(WidgetTester tester, String rotulo) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(rotulo)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('registra o carregamento do acervo com a origem dos dados', (tester) async {
    final coletor = await abrir(tester);

    final carregamento = coletor.eventos.firstWhere((e) => e.nome == 'acervo_carregado');
    expect(carregamento.texto('fonte'), contains('memória'));
    expect(carregamento.numero('cavalos'), 5);
    expect(carregamento.numero('baias'), 5);
    expect(carregamento.numero('duracaoMs'), isNotNull);
  });

  testWidgets('registra a jornada de navegação pelas telas', (tester) async {
    final coletor = await abrir(tester, baias: true);

    await irPara(tester, 'Genealogia');
    await irPara(tester, 'Histórico');
    await irPara(tester, 'Baias');

    final visitas = coletor.eventos.where((e) => e.nome == 'tela_visualizada').toList();
    expect(visitas, isNotEmpty, reason: 'navegar precisa gerar eventos de tela');
    final rotas = visitas.map((e) => e.texto('rota')).toSet();
    expect(rotas, contains('/genealogia'));
    expect(rotas, contains('/historico'));
    expect(rotas, contains('/baias'));
  });

  testWidgets('registra abertura de mídia com tipo e origem', (tester) async {
    final coletor = await abrir(tester);

    await irPara(tester, 'Fotos');
    await tester.tap(find.text('Capa'));
    await tester.pumpAndSettle();

    final midia = coletor.eventos.firstWhere((e) => e.nome == 'midia_visualizada');
    expect(midia.entidade, 'midia');
    expect(midia.texto('tipo'), 'foto');
    expect(midia.texto('origem'), 'grade');
  });

  testWidgets('registra mudança de aba com o nome da aba', (tester) async {
    final coletor = await abrir(tester);

    await tester.tap(find.text('Vídeos'));
    await tester.pumpAndSettle();

    final aba = coletor.eventos.firstWhere((e) => e.nome == 'aba_alterada');
    expect(aba.texto('tela'), '/perfil');
    expect(aba.texto('aba'), 'Vídeos');
  });

  testWidgets('concluir manejo gera evento com a tarefa e o estado final', (tester) async {
    final coletor = await abrir(tester, baias: true);

    await irPara(tester, 'Baias');
    await tester.tap(find.text('Manejo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final manejo = coletor.eventos.firstWhere(
      (e) => e.nome == 'manejo_alternado',
      orElse: () => throw StateError('manejo não instrumentado'),
    );
    expect(manejo.entidade, 'baia');
    expect(manejo.booleano('concluida'), isNotNull);
    expect(manejo.texto('tarefa'), isNotNull);
  });

  testWidgets('toda a telemetria carrega sessão e a tela corrente', (tester) async {
    final coletor = await abrir(tester, baias: true);
    await irPara(tester, 'Baias');

    expect(coletor.eventos, isNotEmpty);
    final sessoes = coletor.eventos.map((e) => e.sessao).toSet();
    expect(sessoes.length, 1, reason: 'uma sessão por execução');

    final comTela = coletor.eventos.where((e) => e.tela != null);
    expect(comTela, isNotEmpty);
    expect(comTela.map((e) => e.tela), contains('/baias'));
  });
}
