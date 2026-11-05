import 'package:flutter/material.dart';

import 'package:equilink_core/equilink_core.dart';
import '../core/tema.dart';
import '../escopo.dart';
import '../servicos/compartilhar.dart';
import '../widgets/comuns.dart';
import '../widgets/marca.dart';
import '../widgets/visualizador_midia.dart';

/// Tela "Fotos e Vídeos": galeria de mídias do cavalo com abas e grade.
class TelaMidias extends StatefulWidget {
  const TelaMidias({super.key});

  @override
  State<TelaMidias> createState() => _TelaMidiasState();
}

class _TelaMidiasState extends State<TelaMidias> {
  int _aba = 0;
  int _pagina = 0;
  final _controlador = PageController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositorio = RepositorioEscopo.de(context);
    final visualizador = VisualizadorEscopo.de(context);
    final cavalo = repositorio.cavaloObrigatorio;
    final fotos = cavalo.fotos;
    final videos = cavalo.videos;
    final destaque = _aba == 0 ? fotos : videos;

    return Scaffold(
      appBar: AppBar(
        title: const LogoEquilink(),
        actions: [
          IconButton(
            tooltip: 'Compartilhar galeria',
            icon: const Icon(Icons.ios_share),
            onPressed: () =>
                CompartilhamentoPerfil.compartilhar(context, repositorio),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Espacos.x4),
        children: [
          AbasPilula(
            abas: const ['Fotos', 'Vídeos'],
            contagens: [fotos.length, videos.length],
            selecionada: _aba,
            aoSelecionar: (i) => setState(() {
              _aba = i;
              _pagina = 0;
              _controlador.jumpToPage(0);
            }),
          ),
          const SizedBox(height: Espacos.x4),
          // Mídia em destaque com contador "1/12".
          //
          // Sem nenhuma mídia da aba atual, o carrossel vazio mostrava "0/0" e
          // ocupava 210 px com nada dentro.
          if (destaque.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Cores.trilho,
                borderRadius: BorderRadius.circular(Raios.medio),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _aba == 0 ? Icons.photo_outlined : Icons.videocam_outlined,
                    size: 24,
                    color: Cores.textoSecundario,
                  ),
                  const SizedBox(height: Espacos.x2),
                  Text(
                    _aba == 0 ? 'Nenhuma foto cadastrada' : 'Nenhum vídeo cadastrado',
                    style: const TextStyle(fontSize: 12.5, color: Cores.textoSecundario),
                  ),
                ],
              ),
            ),
          if (destaque.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(Raios.medio),
            child: SizedBox(
              height: 210,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controlador,
                    itemCount: destaque.length,
                    onPageChanged: (p) => setState(() => _pagina = p),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () {
                          repositorio.analytics.registrar(
                            'midia_visualizada',
                            entidade: 'midia',
                            entidadeId: destaque[i].id,
                            propriedades: {'tipo': destaque[i].tipo.name, 'origem': 'destaque'},
                          );
                          visualizador.abrir(destaque[i]);
                        },
                      child: ImagemMidia(
                        destaque[i].tipo == TipoMidia.foto
                            ? destaque[i].arquivo
                            : destaque[i].poster ?? MidiaPadrao.capaVideo,
                        ajuste: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (destaque.isNotEmpty &&
                      destaque[_pagina].tipo == TipoMidia.video)
                    Positioned(
                      right: Espacos.x3,
                      bottom: Espacos.x3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(Raios.total),
                        ),
                        child: Text(
                          duracaoVideo(destaque[_pagina].duracaoSegundos ?? 0),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: Espacos.x3,
                    right: Espacos.x3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(Raios.total),
                      ),
                      child: Text(
                        '${destaque.isEmpty ? 0 : _pagina + 1}/${destaque.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espacos.x3),
          if (destaque.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    destaque[_pagina].legenda,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Cores.texto,
                    ),
                  ),
                ),
                if (destaque[_pagina].local != null)
                  Text(
                    destaque[_pagina].local!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Cores.textoSecundario,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Espacos.x4),
          TituloSecao(
            _aba == 0 ? 'Todas as fotos' : 'Todos os vídeos',
            subtitulo: _aba == 0
                ? 'Toque para ampliar'
                : 'Toque para reproduzir',
          ),
          const SizedBox(height: Espacos.x3),
          if (_aba == 0)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: Espacos.x2,
                crossAxisSpacing: Espacos.x2,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(Raios.pequeno),
                child: GestureDetector(
                  onTap: () {
                        repositorio.analytics.registrar(
                          'midia_visualizada',
                          entidade: 'midia',
                          entidadeId: fotos[i].id,
                          propriedades: {'tipo': 'foto', 'origem': 'grade'},
                        );
                        visualizador.abrir(fotos[i]);
                      },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImagemMidia(fotos[i].arquivo, ajuste: BoxFit.cover),
                      if (i == 0)
                        const Positioned(
                          top: 6,
                          left: 6,
                          child: Etiqueta(
                            'Capa',
                            cor: Cores.escuro,
                            fundo: Colors.white,
                            compacta: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final video in videos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espacos.x3),
                    child: GestureDetector(
                      onTap: () {
                          repositorio.analytics.registrar(
                            'midia_visualizada',
                            entidade: 'midia',
                            entidadeId: video.id,
                            propriedades: {'tipo': 'video', 'origem': 'lista'},
                          );
                          visualizador.abrir(video);
                        },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Raios.medio),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ImagemMidia(
                                video.poster ?? MidiaPadrao.capaVideo,
                                ajuste: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            ),
                            const Positioned.fill(
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              right: Espacos.x3,
                              bottom: Espacos.x3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(
                                    Raios.total,
                                  ),
                                ),
                                child: Text(
                                  duracaoVideo(video.duracaoSegundos ?? 0),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: Espacos.x3,
                              bottom: Espacos.x3,
                              child: Text(
                                video.legenda,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Espacos.x3),
          Painel(
            child: Row(
              children: [
                QrDoCavalo(
                  dados: ContextoPerfil(cavalo: cavalo).urlPublica,
                  tamanho: 74,
                  padding: 2,
                ),
                const SizedBox(width: Espacos.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Galeria vinculada ao QR Code',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${plural(fotos.length, 'foto', 'fotos')} e '
                        '${plural(videos.length, 'vídeo', 'vídeos')} '
                        'disponíveis neste perfil.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Cores.textoSecundario,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacos.x4),
          BotaoDourado(
            rotulo: 'Ver todas as fotos e vídeos',
            escuro: true,
            icone: Icons.collections_outlined,
            aoTocar: () => setState(() {
              _aba = 0;
              _pagina = 0;
              _controlador.jumpToPage(0);
            }),
          ),
        ],
      ),
    );
  }
}
