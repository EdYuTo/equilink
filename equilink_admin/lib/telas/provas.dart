import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:equilink_core/equilink_core.dart';

import '../core/escopo.dart';
import '../core/tema.dart';
import '../rotas.dart';
import '../widgets/comuns.dart';

/// Visão consolidada do histórico esportivo de todos os cavalos.
class TelaProvas extends StatefulWidget {
  const TelaProvas({super.key});

  @override
  State<TelaProvas> createState() => _TelaProvasState();
}

class _TelaProvasState extends State<TelaProvas> {
  String _filtroCavalo = 'todos';

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);
    final selecionados = _filtroCavalo == 'todos'
        ? rep.cavalos
        : [
            for (final c in rep.cavalos)
              if (c.id == _filtroCavalo) c,
          ];

    final linhas = <({Cavalo cavalo, dynamic prova})>[
      for (final cavalo in selecionados)
        for (final prova in cavalo.provasRecentes) (cavalo: cavalo, prova: prova),
    ];

    final totalProvas = linhas.length;
    final totalVitorias = linhas.where((l) => l.prova.vitoria as bool).length;
    final melhor = linhas.isEmpty
        ? null
        : Analise.menorValor(linhas.map((l) => l.prova.tempoSegundos as double));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CabecalhoSecao(
          titulo: 'Histórico esportivo',
          subtitulo: 'Provas de todos os animais do acervo',
          icone: Icons.emoji_events_outlined,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, restricoes) {
            final colunas = restricoes.maxWidth > 900 ? 3 : (restricoes.maxWidth > 560 ? 2 : 1);
            return GridView.count(
              crossAxisCount: colunas,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: colunas == 1 ? 4 : 2.6,
              children: [
                Indicador(
                  valor: '$totalProvas',
                  rotulo: 'Provas registradas',
                  icone: Icons.flag_outlined,
                ),
                Indicador(
                  valor: '$totalVitorias',
                  rotulo: 'Vitórias',
                  icone: Icons.emoji_events,
                  destaque: true,
                ),
                Indicador(
                  valor: melhor == null ? '—' : '${melhor.toStringAsFixed(3).replaceAll('.', ',')}s',
                  rotulo: 'Melhor tempo dos meus cavalos',
                  icone: Icons.timer_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: CabecalhoSecao(
                      titulo: 'Provas',
                      icone: Icons.list_alt_outlined,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _filtroCavalo,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: 'todos', child: Text('Todos os animais')),
                      for (final c in rep.cavalos)
                        DropdownMenuItem(value: c.id, child: Text(c.nome)),
                    ],
                    onChanged: (v) => setState(() => _filtroCavalo = v ?? 'todos'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (linhas.isEmpty)
                Vazio(
                  icone: Icons.event_busy_outlined,
                  titulo: 'Nenhuma prova registrada',
                  descricao: 'As provas são cadastradas no editor de cada animal.',
                  acao: FilledButton.icon(
                    onPressed: () => context.go(RotasAdmin.cavalos),
                    icon: const Icon(Icons.pets_outlined, size: 16),
                    label: const Text('Ir para os animais'),
                  ),
                ),
              for (final linha in linhas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _cor(linha.prova.colocacao as int).$2,
                              borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                            ),
                            child: Center(
                              child: Text(
                                linha.prova.temColocacao ? '${linha.prova.colocacao}º' : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _cor(linha.prova.colocacao as int).$1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 180,
                          child: Text(
                            linha.cavalo.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${linha.prova.nome} | ${linha.prova.categoria}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Text(
                          '${_data(linha.prova.data as DateTime)} • '
                          '${(linha.prova.tempoSegundos as double).toStringAsFixed(3).replaceAll('.', ',')}s',
                          style: const TextStyle(fontSize: 12, color: AdminCores.textoSecundario),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${linha.prova.inscritos}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: AdminCores.textoSecundario),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static (Color, Color) _cor(int colocacao) => switch (colocacao) {
    1 => (AdminCores.verde, AdminCores.verdeFundo),
    2 || 3 => (AdminCores.ambar, AdminCores.ambarFundo),
    _ => (AdminCores.textoSecundario, AdminCores.superficie),
  };

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
