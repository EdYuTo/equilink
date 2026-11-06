import 'package:flutter/material.dart';

import 'package:equilink_core/equilink_core.dart';
import '../core/tema.dart';
import '../escopo.dart';
import '../widgets/comuns.dart';
import '../widgets/marca.dart';

/// Tela "Histórico Esportivo": provas disputadas, resultados detalhados e
/// estatísticas de desempenho.
class TelaHistorico extends StatefulWidget {
  const TelaHistorico({super.key});

  @override
  State<TelaHistorico> createState() => _TelaHistoricoState();
}

class _TelaHistoricoState extends State<TelaHistorico> {
  int _aba = 0;
  int? _anoSelecionado;

  @override
  Widget build(BuildContext context) {
    final repositorio = RepositorioEscopo.de(context);
    final cavalo = repositorio.cavaloObrigatorio;
    final provas = cavalo.provasRecentes;
    final anos = provas.map((p) => p.data.year).toSet().toList()..sort((a, b) => b - a);
    final anoAtivo = _anoSelecionado ?? (anos.isNotEmpty ? anos.first : null);
    final filtradas = anoAtivo == null
        ? provas
        : provas.where((p) => p.data.year == anoAtivo).toList();

    return Scaffold(
      appBar: AppBar(
        title: const LogoEquilink(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Espacos.x4),
        children: [
          Painel(
            cor: Cores.superficieSuave,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SeloIniciais('HE', tamanho: 42),
                    const SizedBox(width: Espacos.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cavalo.nome,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${plural(cavalo.provas.length, 'prova', 'provas')} registradas • '
                            '${cavalo.vitorias} vitórias',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Cores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacos.x4),
                AbasPilula(
                  abas: const ['Provas', 'Resultados', 'Estatísticas'],
                  selecionada: _aba,
                  aoSelecionar: (i) => setState(() => _aba = i),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacos.x3),
          if (_aba != 2) _FiltroAnos(anos: anos, selecionado: anoAtivo, aoSelecionar: (a) => setState(() => _anoSelecionado = a)),
          const SizedBox(height: Espacos.x3),
          switch (_aba) {
            0 => _ListaProvas(provas: filtradas),
            1 => _ListaResultados(provas: filtradas),
            _ => _Estatisticas(cavalo: cavalo, repositorio: repositorio),
          },
          if (fontesDasProvas(cavalo.provas).isNotEmpty) ...[
            const SizedBox(height: Espacos.x2),
            Text(
              'Resultados: ${fontesDasProvas(cavalo.provas).join(', ')}',
              style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
            ),
          ],
          const SizedBox(height: Espacos.x4),
          Painel(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ResumoItem(
                        valor: '${cavalo.provas.length}',
                        rotulo: 'Total de provas',
                        icone: Icons.flag_outlined,
                      ),
                    ),
                    const SizedBox(width: Espacos.x2),
                    Expanded(
                      child: ResumoItem(
                        valor: '${cavalo.vitorias}',
                        rotulo: 'Vitórias',
                        icone: Icons.emoji_events,
                        destaque: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacos.x2),
                Row(
                  children: [
                    Expanded(
                      child: ResumoItem(
                        valor: cavalo.melhorTempo == null
                            ? '—'
                            : tempoProvaCompacto(cavalo.melhorTempo!),
                        rotulo: 'Melhor tempo',
                        icone: Icons.timer_outlined,
                      ),
                    ),
                    const SizedBox(width: Espacos.x2),
                    Expanded(
                      child: ResumoItem(
                        valor: cavalo.tempoMedio == null
                            ? '—'
                            : tempoProvaCompacto(cavalo.tempoMedio!),
                        rotulo: 'Tempo médio',
                        icone: Icons.speed_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seletor de ano usado para filtrar as provas.
class _FiltroAnos extends StatelessWidget {
  const _FiltroAnos({required this.anos, required this.selecionado, required this.aoSelecionar});

  final List<int> anos;
  final int? selecionado;
  final ValueChanged<int?> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            rotulo: 'Todos',
            ativo: selecionado == null,
            aoTocar: () => aoSelecionar(null),
          ),
          for (final ano in anos)
            _Chip(
              rotulo: '$ano',
              ativo: selecionado == ano,
              aoTocar: () => aoSelecionar(ano),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.rotulo, required this.ativo, required this.aoTocar});

  final String rotulo;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Espacos.x2),
      child: Material(
        color: ativo ? Cores.escuro : Cores.superficie,
        borderRadius: BorderRadius.circular(Raios.total),
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(Raios.total),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Raios.total),
              border: Border.all(color: ativo ? Cores.escuro : Cores.borda),
            ),
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ativo ? Colors.white : Cores.textoSecundario,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aba "Provas": cartões com data, local, categoria, colocação e tempo.
class _ListaProvas extends StatelessWidget {
  const _ListaProvas({required this.provas});

  final List<Prova> provas;

  @override
  Widget build(BuildContext context) {
    if (provas.isEmpty) {
      return const Painel(
        child: Vazio(
          icone: Icons.event_busy_outlined,
          titulo: 'Nenhuma prova neste ano',
          descricao: 'Selecione outro ano para consultar o histórico do animal.',
        ),
      );
    }
    return Column(
      children: [
        for (final prova in provas)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacos.x3),
            child: Painel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _corColocacao(prova).fundo,
                          borderRadius: BorderRadius.circular(Raios.pequeno),
                        ),
                        child: Text(
                          colocacao(prova.colocacao),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _corColocacao(prova).texto,
                          ),
                        ),
                      ),
                      const SizedBox(width: Espacos.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${prova.nome}  |  ${prova.categoria}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [if (prova.local.trim().isNotEmpty) prova.local, dataMedia(prova.data)].join(' • '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Cores.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espacos.x3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espacos.x3,
                      vertical: Espacos.x2,
                    ),
                    decoration: BoxDecoration(
                      color: Cores.superficieSuave,
                      borderRadius: BorderRadius.circular(Raios.pequeno),
                    ),
                    child: Row(
                      children: [
                        _Metrica(rotulo: 'Tempo', valor: tempoProvaCompacto(prova.tempoSegundos)),
                        const _Separador(),
                        _Metrica(rotulo: 'Inscritos', valor: prova.inscritos > 0 ? '${prova.inscritos}' : '—'),
                        const _Separador(),
                        _Metrica(
                          rotulo: 'Premiação',
                          valor: prova.premiacao ?? 'Não premiada',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Fontes externas dos resultados, para citar de onde vieram os dados.
List<String> fontesDasProvas(List<Prova> provas) => {
  for (final p in provas)
    if (p.fonte?.trim().isNotEmpty ?? false) p.fonte!.trim(),
}.toList();

/// Aba "Resultados": tabela compacta com todas as provas.
class _ListaResultados extends StatelessWidget {
  const _ListaResultados({required this.provas});

  final List<Prova> provas;

  @override
  Widget build(BuildContext context) {
    if (provas.isEmpty) {
      return const Painel(
        child: Vazio(
          icone: Icons.table_rows_outlined,
          titulo: 'Sem resultados para o filtro',
          descricao: 'Ajuste o ano selecionado para ver a tabela de resultados.',
        ),
      );
    }
    return Painel(
      padding: const EdgeInsets.all(Espacos.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabecalhoTabela(
            colunas: ['Data', 'Prova', 'Local', 'Colocação', 'Tempo'],
            flex: [3, 4, 4, 3, 3],
          ),
          const SizedBox(height: Espacos.x2),
          for (var i = 0; i < provas.length; i++) ...[
            _LinhaResultado(prova: provas[i]),
            if (i != provas.length - 1) const Divider(height: Espacos.x3),
          ],
        ],
      ),
    );
  }
}

class _LinhaResultado extends StatelessWidget {
  const _LinhaResultado({required this.prova});

  final Prova prova;

  @override
  Widget build(BuildContext context) {
    final cor = _corColocacao(prova);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacos.x2, horizontal: Espacos.x2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              dataCurta(prova.data),
              style: const TextStyle(fontSize: 12.5, color: Cores.textoSecundario),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              prova.nome,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              prova.local.replaceAll(RegExp(r'\s*-\s*[A-Z]{2}$'), ''),
              style: const TextStyle(fontSize: 12.5, color: Cores.textoSecundario),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Etiqueta(
                colocacao(prova.colocacao),
                cor: cor.texto,
                fundo: cor.fundo,
                compacta: true,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tempoProvaCompacto(prova.tempoSegundos),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Cores.dourado,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aba "Estatísticas": indicadores, evolução mensal e distribuição de colocações.
class _Estatisticas extends StatelessWidget {
  const _Estatisticas({required this.cavalo, required this.repositorio});

  final Cavalo cavalo;
  final Repositorio repositorio;

  @override
  Widget build(BuildContext context) {
    final provas = cavalo.provas;
    final total = provas.length;
    final taxaVitoria = total == 0 ? 0.0 : cavalo.vitorias / total;
    final taxaPodio = total == 0 ? 0.0 : cavalo.podios / total;
    final mensal = repositorio.desempenhoPorMes();
    final distribuicao = repositorio.distribuicaoColocacoes;
    final melhorMensal = mensal.isEmpty
        ? 0.0
        : Analise.maiorValor(mensal.map((m) => m.melhorTempo));

    return Column(
      children: [
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecao('Indicadores gerais'),
              const SizedBox(height: Espacos.x4),
              _Indicador(
                rotulo: 'Taxa de vitórias',
                valor: percentual(taxaVitoria),
                fracao: taxaVitoria,
                cor: Cores.verde,
              ),
              const SizedBox(height: Espacos.x3),
              _Indicador(
                rotulo: 'Taxa de pódio (até 3º)',
                valor: percentual(taxaPodio),
                fracao: taxaPodio,
                cor: Cores.dourado,
              ),
              const SizedBox(height: Espacos.x4),
              Wrap(
                spacing: Espacos.x4,
                runSpacing: Espacos.x4,
                children: [
                  SizedBox(
                    width: 150,
                    child: CampoInfo(
                      rotulo: 'Melhor tempo',
                      valor: cavalo.melhorTempo == null
                          ? '—'
                          : tempoProvaCompacto(cavalo.melhorTempo!),
                      icone: Icons.timer_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: CampoInfo(
                      rotulo: 'Tempo médio',
                      valor: cavalo.tempoMedio == null
                          ? '—'
                          : tempoProvaCompacto(cavalo.tempoMedio!),
                      icone: Icons.speed_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: CampoInfo(
                      rotulo: 'Média (5 últimas)',
                      valor: cavalo.tempoMedioRecente == null
                          ? '—'
                          : tempoProvaCompacto(cavalo.tempoMedioRecente!),
                      icone: Icons.trending_flat_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: CampoInfo(
                      rotulo: 'Pódios',
                      valor: '${cavalo.podios}',
                      icone: Icons.workspace_premium_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacos.x3),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecao(
                'Evolução mensal',
                subtitulo: 'Melhor tempo registrado em cada mês',
              ),
              const SizedBox(height: Espacos.x4),
              _GraficoEvolucao(dados: mensal, piorTempo: melhorMensal),
            ],
          ),
        ),
        const SizedBox(height: Espacos.x3),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecao('Distribuição de colocações'),
              const SizedBox(height: Espacos.x4),
              for (final entrada in _ordenar(distribuicao))
                Padding(
                  padding: const EdgeInsets.only(bottom: Espacos.x3),
                  child: _BarraColocacao(
                    rotulo: entrada.key,
                    quantidade: entrada.value,
                    total: total,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, int>> _ordenar(Map<String, int> mapa) {
    final lista = mapa.entries.toList()
      ..sort((a, b) => _peso(a.key).compareTo(_peso(b.key)));
    return lista;
  }

  int _peso(String chave) => chave == '6º+' ? 6 : int.tryParse(chave.replaceAll('º', '')) ?? 9;
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.rotulo,
    required this.valor,
    required this.fracao,
    required this.cor,
  });

  final String rotulo;
  final String valor;
  final double fracao;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              valor,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cor),
            ),
          ],
        ),
        const SizedBox(height: Espacos.x2),
        BarraProporcao(valor: fracao, cor: cor),
      ],
    );
  }
}

/// Gráfico de colunas do melhor tempo por mês.
class _GraficoEvolucao extends StatelessWidget {
  const _GraficoEvolucao({required this.dados, required this.piorTempo});

  final List<({String rotulo, int provas, int vitorias, double melhorTempo})> dados;
  final double piorTempo;

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) {
      return const Vazio(
        icone: Icons.bar_chart_outlined,
        titulo: 'Sem dados de desempenho',
      );
    }
    final menor = Analise.menorValor(dados.map((d) => d.melhorTempo));
    final base = piorTempo == 0 ? 1.0 : piorTempo;
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in dados)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.melhorTempo.toStringAsFixed(1).replaceAll('.', ','),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Cores.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (d.melhorTempo / base).clamp(0.15, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: d.melhorTempo == menor ? Cores.verde : Cores.dourado,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                                bottom: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.rotulo,
                      style: const TextStyle(fontSize: 10, color: Cores.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraColocacao extends StatelessWidget {
  const _BarraColocacao({required this.rotulo, required this.quantidade, required this.total});

  final String rotulo;
  final int quantidade;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fracao = total == 0 ? 0.0 : quantidade / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                rotulo,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: BarraProporcao(
                valor: fracao,
                cor: int.tryParse(rotulo.replaceAll('º', '')) == 1
                    ? Cores.verde
                    : Cores.dourado.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: Espacos.x3),
            Text(
              '$quantidade (${percentual(fracao, casas: 0)})',
              style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Cores.textoSecundario,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: Espacos.x3),
      color: Cores.borda,
    );
  }
}

({Color texto, Color fundo}) _corColocacao(Prova prova) => switch (prova.colocacao) {
  1 => (texto: Cores.verde, fundo: Cores.verdeFundo),
  2 || 3 => (texto: Cores.ambar, fundo: Cores.ambarFundo),
  _ => (texto: Cores.textoSecundario, fundo: Cores.trilho),
};
