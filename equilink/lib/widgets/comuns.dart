import 'package:flutter/material.dart';

import 'package:equilink_ui/equilink_ui.dart';

import '../core/tema.dart';

/// Barra de abas em pílula, no estilo do guia visual: a aba ativa recebe
/// fundo verde-petróleo e texto claro; as demais ficam sobre fundo neutro.
class AbasPilula extends StatelessWidget {
  const AbasPilula({
    super.key,
    required this.abas,
    required this.selecionada,
    required this.aoSelecionar,
    this.contagens,
  });

  final List<String> abas;
  final int selecionada;
  final ValueChanged<int> aoSelecionar;

  /// Contadores opcionais exibidos ao lado do rótulo (ex.: Fotos 12).
  final List<int?>? contagens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Cores.trilho,
        borderRadius: BorderRadius.circular(Raios.pequeno),
      ),
      child: Row(
        children: [
          for (var i = 0; i < abas.length; i++)
            Expanded(
              child: _Aba(
                rotulo: abas[i],
                // Em telas estreitas o rótulo longo vira reticências
                // ("Geneal…"), que não informam nada. Aí só a inicial ajuda.
                rotuloCurto: _curto(abas[i]),
                contagem: contagens != null && i < contagens!.length ? contagens![i] : null,
                ativa: i == selecionada,
                aoTocar: () => aoSelecionar(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.rotulo,
    required this.ativa,
    required this.aoTocar,
    required this.rotuloCurto,
    this.contagem,
  });

  final String rotulo;

  /// Rótulo de uma ou duas letras para larguras muito estreitas.
  final String rotuloCurto;
  final bool ativa;
  final VoidCallback aoTocar;
  final int? contagem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: ativa,
      label: rotulo,
      child: Material(
        color: ativa ? Cores.escuro : Colors.transparent,
        borderRadius: BorderRadius.circular(Raios.pequeno - 2),
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(Raios.pequeno - 2),
          child: Padding(
            // 10+10 com texto de 13 px dava 39 px de altura: abaixo do mínimo
            // de 44 para toque em celular.
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
            // FittedBox reduzia a linha inteira: em 320 px o rótulo quebrava
            // no meio ("Genealogi/a"). O texto agora encolhe sozinho, com
            // reticências quando não couber.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    // Abaixo de 340 px de largura total, o nome completo não
                    // cabe em nenhuma das quatro abas.
                    MediaQuery.sizeOf(context).width < 360 ? rotuloCurto : rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: ativa ? FontWeight.w600 : FontWeight.w500,
                      color: ativa ? Colors.white : Cores.textoSecundario,
                    ),
                  ),
                ),
                if (contagem != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$contagem',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: ativa ? FontWeight.w600 : FontWeight.w500,
                      color: ativa ? Colors.white : Cores.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abreviação estável de um rótulo de aba para telas estreitas.
String _curto(String rotulo) {
  const mapa = {
    'Fotos': 'F',
    'Vídeos': 'V',
    'Genealogia': 'G',
    'Histórico': 'H',
    'Baias': 'B',
    'Manejo': 'M',
    'Relatórios': 'R',
    'Árvore': 'Á',
    'Lista': 'L',
    'Ancestrais': 'A',
    'Provas': 'P',
  };
  return mapa[rotulo] ?? rotulo.characters.first.toUpperCase();
}

/// Etiqueta de situação (baia em dia, em manutenção, gravidade etc.).
class Etiqueta extends StatelessWidget {
  const Etiqueta(
    this.texto, {
    super.key,
    this.cor = Cores.verde,
    this.fundo = Cores.verdeFundo,
    this.icone,
    this.compacta = false,
  });

  final String texto;
  final Color cor;
  final Color fundo;
  final IconData? icone;
  final bool compacta;

  factory Etiqueta.status(String status) => switch (status) {
    'Em dia' => const Etiqueta('Em dia', cor: Cores.verde, fundo: Cores.verdeFundo, icone: Icons.check_circle),
    'Manutenção' => const Etiqueta(
      'Manutenção',
      cor: Cores.ambar,
      fundo: Cores.ambarFundo,
      icone: Icons.build_circle,
    ),
    _ => const Etiqueta('Atenção', cor: Cores.vermelho, fundo: Cores.vermelhoFundo, icone: Icons.error),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacta ? 8 : 10, vertical: compacta ? 3 : 5),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(Raios.total)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: compacta ? 11 : 13, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: compacta ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selo circular com iniciais, usado nas listas onde não há foto.
class SeloIniciais extends StatelessWidget {
  const SeloIniciais(this.iniciais, {super.key, this.tamanho = 46, this.cor});

  final String iniciais;
  final double tamanho;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor ?? Cores.dourado.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Cores.dourado.withValues(alpha: 0.45)),
      ),
      child: Text(
        iniciais,
        style: TextStyle(
          fontSize: tamanho * 0.34,
          fontWeight: FontWeight.w700,
          color: cor != null ? Cores.escuro : Cores.dourado,
        ),
      ),
    );
  }
}

/// Bloco de informação com rótulo em caixa alta e valor.
class CampoInfo extends StatelessWidget {
  const CampoInfo({
    super.key,
    required this.rotulo,
    required this.valor,
    this.icone,
    this.corValor,
  });

  final String rotulo;
  final String valor;
  final IconData? icone;
  final Color? corValor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icone != null) ...[
              Icon(icone, size: 13, color: Cores.textoSecundario),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                rotulo.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Cores.textoSecundario,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: corValor ?? Cores.texto,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Cartão branco padrão das listas (estrutura compartilhada em [PainelUi]).
class Painel extends StatelessWidget {
  const Painel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Espacos.x4),
    this.cor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? cor;

  @override
  Widget build(BuildContext context) => PainelUi(padding: padding, cor: cor, child: child);
}

/// Título de seção com ação opcional à direita.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.titulo, {super.key, this.acao, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Cores.texto),
              ),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitulo!,
                    style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
                  ),
                ),
            ],
          ),
        ),
        ?acao,
      ],
    );
  }
}

/// Cabeçalho de tabela com fundo neutro.
class CabecalhoTabela extends StatelessWidget {
  const CabecalhoTabela({super.key, required this.colunas, this.flex = const [3, 2, 2]});

  final List<String> colunas;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espacos.x4, vertical: 10),
      decoration: BoxDecoration(
        color: Cores.superficieSuave,
        borderRadius: BorderRadius.circular(Raios.pequeno),
      ),
      child: Row(
        children: [
          for (var i = 0; i < colunas.length; i++)
            Expanded(
              flex: i < flex.length ? flex[i] : 2,
              child: Text(
                colunas[i].toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Cores.textoSecundario,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mensagem exibida quando uma lista está vazia (estrutura em [VazioUi]).
class Vazio extends StatelessWidget {
  const Vazio({super.key, required this.icone, required this.titulo, this.descricao});

  final IconData icone;
  final String titulo;
  final String? descricao;

  @override
  Widget build(BuildContext context) =>
      VazioUi(icone: icone, titulo: titulo, descricao: descricao);
}

/// Barra horizontal de proporção (usada nos relatórios).
class BarraProporcao extends StatelessWidget {
  const BarraProporcao({
    super.key,
    required this.valor,
    this.cor = Cores.dourado,
    this.altura = 8,
    this.fundo = Cores.trilho,
  });

  final double valor;
  final Color cor;
  final double altura;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Raios.total),
      child: SizedBox(
        height: altura,
        child: Row(
          children: [
            Expanded(
              flex: (valor.clamp(0.0, 1.0) * 1000).round().clamp(1, 1000),
              child: ColoredBox(color: cor),
            ),
            Expanded(
              flex: 1000 - (valor.clamp(0.0, 1.0) * 1000).round().clamp(1, 1000),
              child: ColoredBox(color: fundo),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caixa decorativa em pílula, usada no resumo do histórico esportivo.
class ResumoItem extends StatelessWidget {
  const ResumoItem({
    super.key,
    required this.valor,
    required this.rotulo,
    this.icone,
    this.destaque = false,
  });

  final String valor;
  final String rotulo;
  final IconData? icone;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: destaque ? Cores.escuro : Cores.superficieSuave,
        borderRadius: BorderRadius.circular(Raios.medio),
        border: Border.all(color: destaque ? Cores.escuro : Cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Icon(
                icone,
                size: 16,
                color: destaque ? Cores.douradoClaro : Cores.dourado,
              ),
            ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: destaque ? Colors.white : Cores.texto,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 11.5,
              color: destaque ? Colors.white70 : Cores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explicação curta exibida ao pé dos painéis.
class NotaRodape extends StatelessWidget {
  const NotaRodape(this.texto, {super.key, this.icone = Icons.info_outline});

  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: Cores.textoSecundario),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 12, color: Cores.textoSecundario, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Botão dourado de largura total, conforme o guia visual.
class BotaoDourado extends StatelessWidget {
  const BotaoDourado({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.icone,
    this.escuro = false,
  });

  final String rotulo;
  final VoidCallback aoTocar;
  final IconData? icone;
  final bool escuro;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: escuro ? Cores.escuro : Cores.dourado,
        borderRadius: BorderRadius.circular(Raios.pequeno),
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(Raios.pequeno),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 18, color: escuro ? Colors.white : Cores.escuro),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: escuro ? Colors.white : Cores.escuro,
                    ),
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

/// Imagem de uma mídia, seja asset empacotado ou arquivo no armazenamento.
///
/// O acervo de demonstração aponta para `assets/...`; o que o painel envia vai
/// para o R2 e chega como URL `https`. Decidir isso em cada tela espalhava a
/// mesma condição por seis lugares.
class ImagemMidia extends StatelessWidget {
  const ImagemMidia(
    this.arquivo, {
    super.key,
    this.ajuste = BoxFit.cover,
    this.largura,
    this.altura,
    this.placeholder,
  });

  final String arquivo;
  final BoxFit ajuste;
  final double? largura;
  final double? altura;

  /// Mostrado enquanto a imagem remota carrega ou se ela falhar.
  final Widget? placeholder;

  bool get _remota => arquivo.startsWith('http://') || arquivo.startsWith('https://') || arquivo.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    // Animal ainda sem foto: mostra o aviso em vez de falhar ao carregar.
    if (arquivo.trim().isEmpty) return placeholder ?? const _MidiaIndisponivel();
    if (!_remota) {
      return Image.asset(arquivo, fit: ajuste, width: largura, height: altura);
    }
    return Image.network(
      arquivo,
      fit: ajuste,
      width: largura,
      height: altura,
      // O bucket é imutável (nome único), então o cache do navegador pode reter.
      loadingBuilder: (context, filho, progresso) {
        if (progresso == null) return filho;
        return placeholder ?? const _MidiaCarregando();
      },
      errorBuilder: (context, erro, pilha) => placeholder ?? const _MidiaIndisponivel(),
    );
  }
}

class _MidiaCarregando extends StatelessWidget {
  const _MidiaCarregando();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Cores.trilho,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _MidiaIndisponivel extends StatelessWidget {
  const _MidiaIndisponivel();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Cores.trilho,
      child: Center(
        child: Icon(Icons.broken_image_outlined, size: 22, color: Cores.textoSecundario),
      ),
    );
  }
}
