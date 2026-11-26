import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

import 'package:equilink_admin/main.dart';

/// EQL-033: o diálogo de prova não pode transformar texto ilegível em 0 s ou
/// em vitória, nem vir preenchido com uma prova de exemplo.
void main() {
  late FonteMemoria fonte;

  Finder campo(String rotulo) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, rotulo));

  String texto(String rotulo) => (campo(rotulo).evaluate().single.widget as TextField).controller!.text;

  Future<void> abrirNovaProva(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fonte = FonteMemoria();
    await tester.pumpWidget(PainelApp(fonte: fonte));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cavalos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Aba' && (w as dynamic).rotulo == 'Provas',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova prova').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  Future<List<Prova>> provasGravadas() async => [
    for (final c in (await fonte.carregar()).cavalos) ...c.provas,
  ];

  Future<void> salvar(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Salvar')));
    await tester.pumpAndSettle();
  }

  testWidgets('nova prova começa vazia, sem a prova de exemplo', (tester) async {
    await abrirNovaProva(tester);
    expect(texto('Prova'), isEmpty);
    expect(texto('Categoria'), isEmpty);
    expect(texto('Colocação'), isEmpty);
    expect(texto('Inscritos'), isEmpty);
  });

  testWidgets('recusa nome vazio, tempo e colocação ilegíveis e fica aberto', (tester) async {
    await abrirNovaProva(tester);
    final antes = (await provasGravadas()).length;

    await tester.enterText(campo('Colocação'), '1º');
    await tester.enterText(campo('Tempo em segundos (ex.: 16,742)'), 'abc');
    await tester.enterText(campo('Inscritos'), 'vinte');
    await salvar(tester);

    expect(find.byType(AlertDialog), findsOneWidget, reason: 'o diálogo continua aberto');
    expect(find.text('Informe o nome da prova.'), findsOneWidget);
    expect(find.text('Use um número inteiro, como 1 ou 2 (0 = sem colocação).'), findsOneWidget);
    expect(find.text('Use só números, como 16,742 ou 16.742.'), findsOneWidget);
    expect(find.text('Use um número inteiro, como 20.'), findsOneWidget);
    expect((await provasGravadas()).length, antes, reason: 'nada foi gravado');
  });

  testWidgets('aceita tempo com ponto e colocação 0 (sem colocação)', (tester) async {
    await abrirNovaProva(tester);

    await tester.enterText(campo('Prova'), 'Seis Balizas');
    await tester.enterText(campo('Colocação'), '0');
    await tester.enterText(campo('Tempo em segundos (ex.: 16,742)'), '16.742');
    await salvar(tester);

    expect(find.byType(AlertDialog), findsNothing);
    final gravada = (await provasGravadas()).firstWhere((p) => p.nome == 'Seis Balizas');
    expect(gravada.tempoSegundos, 16.742);
    expect(gravada.colocacao, 0);
    expect(gravada.vitoria, isFalse);
    expect(gravada.inscritos, 0);
  });

  testWidgets('aceita tempo com vírgula', (tester) async {
    await abrirNovaProva(tester);

    await tester.enterText(campo('Prova'), 'Tambor');
    await tester.enterText(campo('Colocação'), '2');
    await tester.enterText(campo('Tempo em segundos (ex.: 16,742)'), '16,742');
    await tester.enterText(campo('Inscritos'), '31');
    await salvar(tester);

    final gravada = (await provasGravadas()).firstWhere((p) => p.nome == 'Tambor');
    expect(gravada.tempoSegundos, 16.742);
    expect(gravada.colocacao, 2);
    expect(gravada.inscritos, 31);
  });
}
