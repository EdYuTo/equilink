import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

import 'package:equilink_admin/main.dart';

import 'seletor_falso.dart';

/// Fonte cujo envio de mídia sempre falha, como um upload que estourou o prazo.
class _FonteSemEnvio extends FonteMemoria {
  @override
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async => throw const ErroFonte('O envio demorou demais.');
}

/// EQL-035: a foto que não subiu no cadastro não pode ser anunciada como sucesso.
void main() {
  testWidgets('cadastro avisa quando a foto de perfil não foi enviada', (tester) async {
    SeletorFalso.instalar(ArquivoFalso('foto.png', pngMinimo), addTearDown);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/cavalos/novo';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final fonte = _FonteSemEnvio();
    await tester.pumpWidget(PainelApp(fonte: fonte));
    await tester.pumpAndSettle();

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Foto Perdida');
    await tester.enterText(campos.at(1), 'P900002');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Passo 4 de 5'), findsOneWidget);
    await tester.tap(find.text('Escolher foto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('será enviada ao concluir'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(
      find.text('FOTO PERDIDA cadastrado, mas a foto não foi enviada: O envio demorou demais.'),
      findsOneWidget,
    );
    expect(find.text('FOTO PERDIDA cadastrado.'), findsNothing);
    final gravado = await fonte.carregar();
    expect(gravado.cavalos.any((c) => c.registro == 'P900002'), isTrue);
  });
}
