import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:equilink_core/equilink_core.dart';
import '../core/tema.dart';
import 'comuns.dart';

/// Controla o visualizador de mídia no nível do aplicativo.
///
/// O visualizador precisa cobrir também a navegação principal (barra inferior
/// ou lateral); por isso seu estado vive na moldura da aplicação, e não dentro
/// de cada tela.
class VisualizadorController extends ChangeNotifier {
  Midia? _midia;

  Midia? get midia => _midia;
  bool get aberto => _midia != null;

  void abrir(Midia midia) {
    _midia = midia;
    notifyListeners();
  }

  void fechar() {
    if (_midia == null) return;
    _midia = null;
    notifyListeners();
  }
}

/// Disponibiliza o [VisualizadorController] para as telas.
class VisualizadorEscopo extends InheritedNotifier<VisualizadorController> {
  const VisualizadorEscopo({
    super.key,
    required VisualizadorController super.notifier,
    required super.child,
  });

  static VisualizadorController de(BuildContext context) {
    final escopo = context.dependOnInheritedWidgetOfExactType<VisualizadorEscopo>();
    assert(escopo != null, 'VisualizadorEscopo ausente na árvore de widgets.');
    return escopo!.notifier!;
  }
}

/// Visualizador em tela cheia para fotos e vídeos.
class VisualizadorMidia extends StatelessWidget {
  const VisualizadorMidia({super.key, required this.midia, required this.aoFechar});

  final Midia midia;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) {
    // Fica fora do Scaffold das telas: sem Material, os textos saem com o estilo
    // de erro do Flutter (sublinhado amarelo).
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacos.x2, vertical: Espacos.x2),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: aoFechar,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      midia.legenda.isEmpty ? 'Visualização' : midia.legenda,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (midia.tipo == TipoMidia.video)
                    Padding(
                      padding: const EdgeInsets.only(right: Espacos.x3),
                      child: Text(
                        duracaoVideo(midia.duracaoSegundos ?? 0),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: midia.tipo == TipoMidia.foto
                    ? InteractiveViewer(
                        maxScale: 5,
                        child: ImagemMidia(midia.arquivo, ajuste: BoxFit.contain),
                      )
                    : PlayerVideo(midia: midia, alturaMaxima: double.infinity),
              ),
            ),
            if (midia.local != null)
              Padding(
                padding: const EdgeInsets.all(Espacos.x4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.place_outlined, size: 15, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text(
                      midia.local!,
                      style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reprodução de vídeo empacotado no aplicativo, com controles de toque.
class PlayerVideo extends StatefulWidget {
  const PlayerVideo({super.key, required this.midia, this.alturaMaxima = 380});

  final Midia midia;
  final double alturaMaxima;

  @override
  State<PlayerVideo> createState() => _PlayerVideoState();
}

class _PlayerVideoState extends State<PlayerVideo> {
  VideoPlayerController? _controlador;
  bool _carregando = false;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _controlador?.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });
    final controlador = VideoPlayerController.asset(widget.midia.arquivo);
    try {
      await controlador.initialize();
      controlador.setLooping(true);
      await controlador.play();
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _controlador = controlador;
        _carregando = false;
      });
    } catch (_) {
      await controlador.dispose();
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlador = _controlador;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espacos.x2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Raios.medio),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.alturaMaxima),
          child: AspectRatio(
            aspectRatio: controlador?.value.aspectRatio ?? 16 / 9,
            child: controlador != null
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        controlador.value.isPlaying ? controlador.pause() : controlador.play();
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(controlador),
                        _ControlesInline(controlador: controlador, estado: () => setState(() {})),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ImagemMidia(
                        widget.midia.poster ?? MidiaPadrao.capaVideo,
                        ajuste: BoxFit.cover,
                      ),
                      ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                      Center(
                        child: _carregando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : IconButton(
                                onPressed: _iniciar,
                                icon: Icon(
                                  _erro ? Icons.error_outline : Icons.play_circle_fill,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      if (_erro)
                        const Positioned(
                          bottom: Espacos.x4,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Não foi possível reproduzir o vídeo neste dispositivo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progresso e botão de reprodução sobreposta ao vídeo.
class _ControlesInline extends StatelessWidget {
  const _ControlesInline({required this.controlador, required this.estado});

  final VideoPlayerController controlador;
  final VoidCallback estado;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controlador,
      builder: (context, valor, _) {
        return Stack(
          children: [
            if (!valor.isPlaying)
              const Center(
                child: Icon(Icons.play_circle_fill, size: 52, color: Colors.white),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controlador,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: Cores.douradoClaro,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            Positioned(
              left: Espacos.x3,
              bottom: Espacos.x5,
              child: Text(
                '${duracaoVideo(valor.position.inSeconds)} / '
                '${duracaoVideo(valor.duration.inSeconds)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
