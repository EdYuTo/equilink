import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

import 'package:equilink_admin/main.dart';

import 'seletor_falso.dart';

/// Fonte cujo envio de mídia sempre falha.
class _FonteSemEnvio extends FonteMemoria {
  _FonteSemEnvio({super.inicial});

  @override
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async => throw const ErroFonte('O envio demorou demais.');
}

final _dataUri = 'data:image/png;base64,${base64Encode(pngMinimo)}';

bool _memoria(Widget w) => w is Image && w.image is MemoryImage;
bool _rede(Widget w) => w is Image && w.image is NetworkImage;

/// EQL-031: a miniatura mostra a foto de verdade, venha ela do R2 (`https:`)
/// ou da fonte de demonstração (`data:`), e o editor troca a foto de perfil.
void main() {
  late Acervo acervo;
  late Cavalo alvo;

  setUp(() {
    final base = FonteMemoria.acervoDeDemonstracao();
    alvo = base.cavalos.first.copiarCom(
      fotoPerfil: _dataUri,
      midias: [Midia(id: 'm-data', tipo: TipoMidia.foto, arquivo: _dataUri)],
    );
    acervo = base.copiarCom(cavalos: [
      alvo,
      base.cavalos[1].copiarCom(fotoPerfil: 'https://pub-exemplo.r2.dev/foto.jpg'),
      ...base.cavalos.skip(2),
    ]);
  });

  Future<void> abrir(WidgetTester tester, FonteMemoria fonte, String rota) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = rota;
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(PainelApp(fonte: fonte));
    await tester.pumpAndSettle();
  }

  testWidgets('lista de cavalos desenha data: e https:, e o resto fica no ícone', (tester) async {
    await abrir(tester, FonteMemoria(inicial: acervo), '/cavalos');

    expect(find.byWidgetPredicate(_memoria), findsOneWidget);
    expect(find.byWidgetPredicate(_rede), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsWidgets, reason: 'assets/img/... continua no ícone');
  });

  testWidgets('miniatura da aba Mídias desenha data:', (tester) async {
    await abrir(tester, FonteMemoria(inicial: acervo), '/cavalos/${alvo.id}');
    await tester.tap(find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Aba' && (w as dynamic).rotulo == 'Mídias',
    ));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate(_memoria), findsOneWidget);
  });

  testWidgets('Trocar foto de perfil envia a foto e grava no cavalo', (tester) async {
    final seletor = SeletorFalso.instalar(ArquivoFalso('nova.PNG', pngMinimo), addTearDown);
    final fonte = FonteMemoria(inicial: acervo);
    final semFoto = acervo.cavalos[2];
    await abrir(tester, fonte, '/cavalos/${semFoto.id}');

    await tester.tap(find.text('Trocar foto de perfil'));
    await tester.pumpAndSettle();

    expect(seletor.escolhas, 1);
    expect(find.text('Foto de perfil atualizada.'), findsOneWidget);
    final gravado = (await fonte.carregar()).cavalos.firstWhere((c) => c.id == semFoto.id);
    expect(gravado.fotoPerfil, _dataUri);
    expect(find.byWidgetPredicate(_memoria), findsOneWidget, reason: 'a ficha mostra a nova foto');
  });

  testWidgets('Trocar foto de perfil avisa a falha e não mexe no cavalo', (tester) async {
    SeletorFalso.instalar(ArquivoFalso('nova.png', pngMinimo), addTearDown);
    final fonte = _FonteSemEnvio(inicial: acervo);
    final semFoto = acervo.cavalos[2];
    await abrir(tester, fonte, '/cavalos/${semFoto.id}');

    await tester.tap(find.text('Trocar foto de perfil'));
    await tester.pumpAndSettle();

    expect(find.text('O envio demorou demais.'), findsWidgets);
    final gravado = (await fonte.carregar()).cavalos.firstWhere((c) => c.id == semFoto.id);
    expect(gravado.fotoPerfil, semFoto.fotoPerfil);
  });
}
