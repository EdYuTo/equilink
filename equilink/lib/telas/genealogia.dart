import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:equilink_core/equilink_core.dart';
import '../core/tema.dart';
import '../escopo.dart';
import '../rotas.dart';
import '../widgets/comuns.dart';
import '../widgets/marca.dart';

/// Azul dos machos e bege das fêmeas, como na genealogia da ABQM.
const _corMacho = Color(0xFFE3E8EF);
const _corFemea = Color(0xFFEFE7D6);

/// Tela "Genealogia": árvore lateral até os bisavós, no formato da ABQM.
///
/// Sem [raiz], mostra o cavalo em foco. Com [raiz], mostra a árvore de um
/// ancestral aberta a partir da ficha dele.
class TelaGenealogia extends StatefulWidget {
  const TelaGenealogia({super.key, this.raiz});

  final Ancestral? raiz;

  @override
  State<TelaGenealogia> createState() => _TelaGenealogiaState();
}

class _TelaGenealogiaState extends State<TelaGenealogia> {
  static const _zoomMinimo = 1.0;
  static const _zoomMaximo = 2.5;
  static const _passoZoom = 0.25;

  final _transformacao = TransformationController();
  double _zoom = _zoomMinimo;

  @override
  void dispose() {
    _transformacao.dispose();
    super.dispose();
  }

  void _definirZoom(double valor) {
    final zoom = valor.clamp(_zoomMinimo, _zoomMaximo);
    _transformacao.value = Matrix4.diagonal3Values(zoom, zoom, 1);
    setState(() => _zoom = zoom);
  }

  @override
  Widget build(BuildContext context) {
    final repositorio = RepositorioEscopo.de(context);
    final cavalo = repositorio.cavaloObrigatorio;
    final raiz = widget.raiz ?? cavalo.genealogia;
    final slots = montarSlots(raiz);
    final conhecidos = slots.where((s) => s.ancestral != null).toList();
    final geracoes = conhecidos.fold<int>(0, (m, s) => s.geracao > m ? s.geracao : m);

    final subtitulo = widget.raiz != null
        ? 'Registro ${_textoOuPadrao(raiz.registro)}'
        : 'Registro ${cavalo.registro} · ${cavalo.sexo.rotulo} · ${cavalo.pelagem}';

    return Scaffold(
      appBar: AppBar(title: const LogoEquilink()),
      body: ListView(
        // Com zoom, o arraste move a árvore; sem zoom, rola a página.
        physics: _zoom > _zoomMinimo ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(Espacos.x4),
        children: [
          Painel(
            child: Row(
              children: [
                if (widget.raiz == null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Raios.pequeno),
                    child: ImagemMidia(
                      cavalo.fotoPerfil,
                      largura: 56,
                      altura: 56,
                      ajuste: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: Espacos.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raiz.nome,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Cores.texto,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plural(conhecidos.length, 'ancestral', 'ancestrais')} · '
                        '${plural(geracoes, 'geração', 'gerações')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Cores.dourado,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacos.x3),
          Painel(
            padding: const EdgeInsets.fromLTRB(Espacos.x3, Espacos.x3, Espacos.x3, Espacos.x3),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 15, color: Cores.textoSecundario),
                    const SizedBox(width: Espacos.x1),
                    const Expanded(
                      child: Text(
                        'Toque num ancestral para ver os detalhes',
                        style: TextStyle(fontSize: 11, color: Cores.textoSecundario),
                      ),
                    ),
                    _ControleZoom(
                      zoom: _zoom,
                      aoDiminuir: _zoom > _zoomMinimo ? () => _definirZoom(_zoom - _passoZoom) : null,
                      aoAumentar: _zoom < _zoomMaximo ? () => _definirZoom(_zoom + _passoZoom) : null,
                    ),
                  ],
                ),
                const SizedBox(height: Espacos.x3),
                ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformacao,
                    minScale: _zoomMinimo,
                    maxScale: _zoomMaximo,
                    // Sem zoom, nenhum gesto é capturado e a página rola normalmente.
                    panEnabled: _zoom > _zoomMinimo,
                    scaleEnabled: _zoom > _zoomMinimo,
                    onInteractionEnd: (_) {
                      final zoom = _transformacao.value.getMaxScaleOnAxis();
                      if (zoom != _zoom) setState(() => _zoom = zoom);
                    },
                    child: ArvoreGenealogica(
                      slots: slots,
                      aoTocar: (slot) => _abrirFicha(context, slot),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFicha(BuildContext context, SlotGenealogia slot) async {
    final ancestral = slot.ancestral!;
    final repositorio = RepositorioEscopo.de(context);
    repositorio.analytics.registrar(
      'ancestral_visualizado',
      entidade: 'ancestral',
      entidadeId: ancestral.registro,
      propriedades: {'papel': slot.papel},
    );
    final registro = ancestral.registro.trim().toLowerCase();
    final cadastrado = registro.isNotEmpty &&
        repositorio.cavalos.any((c) => c.registro.trim().toLowerCase() == registro);

    final acao = await showModalBottomSheet<_AcaoFicha>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Cores.superficie,
      builder: (_) => _FichaAncestral(slot: slot, cadastrado: cadastrado),
    );
    if (!context.mounted) return;
    switch (acao) {
      case _AcaoFicha.genealogia:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TelaGenealogia(raiz: ancestral)),
        );
      case _AcaoFicha.perfil:
        context.go(Rotas.cavaloPorRegistro(ancestral.registro));
      case null:
        break;
    }
  }
}

String _textoOuPadrao(String? valor) {
  final texto = valor?.trim() ?? '';
  return texto.isEmpty ? 'não informado' : texto;
}

/// Uma posição da árvore: quem ocupa, ou `null` quando o ancestral não é conhecido.
class SlotGenealogia {
  const SlotGenealogia({
    required this.papel,
    required this.geracao,
    required this.macho,
    required this.indice,
    this.ancestral,
  });

  final String papel;

  /// 1 = pais, 2 = avós, 3 = bisavós.
  final int geracao;

  /// O sexo vem da posição: pai é sempre macho, mãe é sempre fêmea.
  final bool macho;

  /// Posição dentro da geração, de cima para baixo.
  final int indice;
  final Ancestral? ancestral;
}

/// Os 14 slots da árvore. Ancestrais sem nome contam como não informados,
/// porque `Ancestral.fromJson({})` devolve um nó vazio em vez de `null`.
List<SlotGenealogia> montarSlots(Ancestral raiz) {
  Ancestral? valido(Ancestral? a) => a == null || a.nome.trim().isEmpty ? null : a;

  final slots = <SlotGenealogia>[];
  void visitar(Ancestral? atual, int geracao, int indice, bool macho, String lado) {
    final conhecido = valido(atual);
    final base = macho ? const ['Pai', 'Avô', 'Bisavô'] : const ['Mãe', 'Avó', 'Bisavó'];
    final complemento = geracao == 1
        ? ''
        : lado == 'paterno'
            ? (macho ? ' paterno' : ' paterna')
            : (macho ? ' materno' : ' materna');
    slots.add(
      SlotGenealogia(
        papel: '${base[geracao - 1]}$complemento',
        geracao: geracao,
        macho: macho,
        indice: indice,
        ancestral: conhecido,
      ),
    );
    if (geracao == 3) return;
    visitar(conhecido?.pai, geracao + 1, indice * 2, true, lado);
    visitar(conhecido?.mae, geracao + 1, indice * 2 + 1, false, lado);
  }

  visitar(raiz.pai, 1, 0, true, 'paterno');
  visitar(raiz.mae, 1, 1, false, 'materno');
  return slots;
}

/// Árvore lateral: pais à esquerda, avós no meio e bisavós à direita.
class ArvoreGenealogica extends StatelessWidget {
  const ArvoreGenealogica({super.key, required this.slots, required this.aoTocar});

  /// Altura reservada a cada bisavô; as outras colunas se centralizam nela.
  static const _alturaLinha = 68.0;
  static const _alturaTitulos = 24.0;
  static const _vaoColunas = 12.0;

  final List<SlotGenealogia> slots;
  final ValueChanged<SlotGenealogia> aoTocar;

  /// Os pais têm mais espaço e uma linha a mais, com o papel de cada um.
  static double _alturaCaixa(int geracao) => geracao == 1 ? 80 : 62;

  /// Centro vertical de um slot, medido em linhas de bisavós.
  static double _centro(int geracao, int indice) {
    final linhas = switch (geracao) {
      1 => 4.0,
      2 => 2.0,
      _ => 1.0,
    };
    return _alturaTitulos + (indice + 0.5) * linhas * _alturaLinha;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final largura = restricoes.maxWidth;
        final coluna = (largura - 2 * _vaoColunas) / 3;
        double esquerda(int geracao) => (geracao - 1) * (coluna + _vaoColunas);

        return SizedBox(
          width: largura,
          height: _alturaTitulos + 8 * _alturaLinha,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PinturaLigacoes(
                    coluna: coluna,
                    vao: _vaoColunas,
                    centro: _centro,
                  ),
                ),
              ),
              for (final (i, titulo) in const ['PAIS', 'AVÓS', 'BISAVÓS'].indexed)
                Positioned(
                  left: esquerda(i + 1),
                  top: 0,
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Cores.textoSecundario,
                    ),
                  ),
                ),
              for (final slot in slots)
                Positioned(
                  left: esquerda(slot.geracao),
                  top: _centro(slot.geracao, slot.indice) - _alturaCaixa(slot.geracao) / 2,
                  width: coluna,
                  height: _alturaCaixa(slot.geracao),
                  child: _CaixaAncestral(slot: slot, aoTocar: () => aoTocar(slot)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CaixaAncestral extends StatelessWidget {
  const _CaixaAncestral({required this.slot, required this.aoTocar});

  final SlotGenealogia slot;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final ancestral = slot.ancestral;
    final raio = BorderRadius.circular(Raios.pequeno - 2);

    if (ancestral == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Cores.superficieSuave,
          borderRadius: raio,
          border: Border.all(color: Cores.borda),
        ),
        child: const Text(
          'Não informado',
          maxLines: 2,
          style: TextStyle(fontSize: 10, color: Cores.textoSecundario),
        ),
      );
    }

    final detalhes = [
      if (ancestral.registro.trim().isNotEmpty) ancestral.registro.trim(),
      if (ancestral.pelagem?.trim().isNotEmpty ?? false) ancestral.pelagem!.trim(),
    ];

    return Material(
      color: slot.macho ? _corMacho : _corFemea,
      borderRadius: raio,
      child: InkWell(
        borderRadius: raio,
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slot.geracao == 1)
                Text(
                  slot.papel,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: Cores.dourado,
                  ),
                ),
              Text(
                ancestral.nome.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: Cores.texto,
                ),
              ),
              for (final detalhe in detalhes)
                Text(
                  detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.25,
                    color: Cores.textoSecundario,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linhas que ligam cada animal aos seus dois pais, na coluna seguinte.
class _PinturaLigacoes extends CustomPainter {
  const _PinturaLigacoes({required this.coluna, required this.vao, required this.centro});

  final double coluna;
  final double vao;
  final double Function(int geracao, int indice) centro;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = const Color(0xFFBDB6A6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final (geracao, quantidade) in const [(1, 2), (2, 4)]) {
      final saida = geracao * coluna + (geracao - 1) * vao;
      final meio = saida + vao / 2;
      final entrada = saida + vao;
      for (var i = 0; i < quantidade; i++) {
        final y = centro(geracao, i);
        final acima = centro(geracao + 1, i * 2);
        final abaixo = centro(geracao + 1, i * 2 + 1);
        canvas.drawLine(Offset(saida, y), Offset(meio, y), pincel);
        canvas.drawLine(Offset(meio, acima), Offset(meio, abaixo), pincel);
        canvas.drawLine(Offset(meio, acima), Offset(entrada, acima), pincel);
        canvas.drawLine(Offset(meio, abaixo), Offset(entrada, abaixo), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PinturaLigacoes antiga) =>
      antiga.coluna != coluna || antiga.vao != vao;
}

class _ControleZoom extends StatelessWidget {
  const _ControleZoom({required this.zoom, this.aoDiminuir, this.aoAumentar});

  final double zoom;
  final VoidCallback? aoDiminuir;
  final VoidCallback? aoAumentar;

  @override
  Widget build(BuildContext context) {
    Widget botao(IconData icone, String dica, VoidCallback? acao) => IconButton(
      tooltip: dica,
      onPressed: acao,
      icon: Icon(icone, size: 16),
      color: Cores.texto,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Cores.borda),
        borderRadius: BorderRadius.circular(Raios.total),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          botao(Icons.remove, 'Diminuir zoom', aoDiminuir),
          Text(
            '${(zoom * 100).round()}%',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          botao(Icons.add, 'Aumentar zoom', aoAumentar),
        ],
      ),
    );
  }
}

enum _AcaoFicha { genealogia, perfil }

/// Folha com os dados que temos do ancestral tocado.
class _FichaAncestral extends StatelessWidget {
  const _FichaAncestral({required this.slot, required this.cadastrado});

  final SlotGenealogia slot;
  final bool cadastrado;

  @override
  Widget build(BuildContext context) {
    final ancestral = slot.ancestral!;
    final temPais = montarSlots(ancestral).any((s) => s.ancestral != null);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacos.x5, 0, Espacos.x5, Espacos.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.papel.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Cores.textoSecundario,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ancestral.nome.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Cores.texto),
            ),
            const SizedBox(height: Espacos.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CampoInfo(rotulo: 'Registro', valor: _textoOuPadrao(ancestral.registro))),
                Expanded(child: CampoInfo(rotulo: 'Sexo', valor: slot.macho ? 'Macho' : 'Fêmea')),
              ],
            ),
            const SizedBox(height: Espacos.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CampoInfo(rotulo: 'Pelagem', valor: _textoOuPadrao(ancestral.pelagem))),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: Espacos.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CampoInfo(rotulo: 'Pai', valor: _textoOuPadrao(ancestral.pai?.nome))),
                Expanded(child: CampoInfo(rotulo: 'Mãe', valor: _textoOuPadrao(ancestral.mae?.nome))),
              ],
            ),
            if (temPais) ...[
              const SizedBox(height: Espacos.x4),
              BotaoDourado(
                rotulo: 'Ver a genealogia de ${ancestral.nome}',
                icone: Icons.account_tree_outlined,
                escuro: true,
                aoTocar: () => Navigator.of(context).pop(_AcaoFicha.genealogia),
              ),
            ],
            if (cadastrado) ...[
              const SizedBox(height: Espacos.x3),
              BotaoDourado(
                rotulo: 'Ver o perfil completo',
                icone: Icons.badge_outlined,
                aoTocar: () => Navigator.of(context).pop(_AcaoFicha.perfil),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
