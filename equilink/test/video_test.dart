import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:equilink/app.dart';
import 'package:equilink/widgets/visualizador_midia.dart';
import 'package:equilink_core/equilink_core.dart';

/// Plataforma de vídeo falsa: guarda a origem pedida e informa a duração.
class _PlataformaFalsa extends VideoPlayerPlatform {
  final origens = <DataSource>[];
  final _eventos = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    origens.add(options.dataSource);
    final id = origens.length;
    _eventos[id] = StreamController<VideoEvent>();
    _eventos[id]!.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 42),
        size: const Size(1280, 720),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _eventos[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => _eventos.remove(playerId)?.close();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();
}

/// EQL-023: vídeo enviado pelo painel (URL do bucket, sem duração nem capa).
void main() {
  late _PlataformaFalsa plataforma;

  setUp(() => VideoPlayerPlatform.instance = plataforma = _PlataformaFalsa());

  const enviado = Midia(
    id: 'v-enviado',
    tipo: TipoMidia.video,
    arquivo: 'https://midia.exemplo.com/videos/treino.mp4',
    legenda: 'Treino enviado',
  );

  Future<void> abrirVisualizador(WidgetTester tester, Midia midia) async {
    await tester.pumpWidget(MaterialApp(home: VisualizadorMidia(midia: midia, aoFechar: () {})));
    await tester.pumpAndSettle();
  }

  /// Desmonta o player para cancelar o temporizador de posição do vídeo.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('vídeo remoto é carregado pela rede', (tester) async {
    await abrirVisualizador(tester, enviado);
    expect(plataforma.origens.single.sourceType, DataSourceType.network);
    expect(plataforma.origens.single.uri, enviado.arquivo);
    await fechar(tester);
  });

  testWidgets('vídeo empacotado continua sendo um asset', (tester) async {
    await abrirVisualizador(tester, enviado.copiarCom(arquivo: 'assets/video/treino.mp4'));
    expect(plataforma.origens.single.sourceType, DataSourceType.asset);
    await fechar(tester);
  });

  testWidgets('sem duração cadastrada, o cabeçalho mostra a do vídeo carregado', (tester) async {
    await abrirVisualizador(tester, enviado);
    final cabecalho = find.descendant(of: find.byType(Row), matching: find.text('0:42'));
    expect(cabecalho, findsOneWidget);
    expect(find.text('0:00'), findsNothing);
    await fechar(tester);
  });

  testWidgets('sem capa, o vídeo não usa a foto de outro cavalo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = FonteMemoria.acervoDeDemonstracao();
    final principal = base.principal!;
    final fonte = FonteMemoria(
      inicial: Acervo(
        cavalos: [
          for (final c in base.cavalos)
            c.id == principal.id
                ? c.copiarCom(midias: [...c.midias.where((m) => m.tipo == TipoMidia.foto), enviado])
                : c,
        ],
        baias: base.baias,
      ),
    );
    await tester.pumpWidget(EquiLinkApp(fonte: fonte));
    await tester.pumpAndSettle();

    final aba = find.descendant(of: find.byType(ListView), matching: find.text('Vídeos'));
    await tester.ensureVisible(aba);
    await tester.pumpAndSettle();
    await tester.tap(aba);
    await tester.pumpAndSettle();

    expect(find.text('Treino enviado'), findsOneWidget);
    expect(find.text('0:00'), findsNothing, reason: 'duração desconhecida não vira 0:00');
    final capas = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName);
    expect(capas, isNot(contains(MidiaPadrao.capaVideo)));
  });
}
