import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:equilink_core/equilink_core.dart';

import '../core/escopo.dart';
import '../core/tema.dart';
import '../rotas.dart';
import '../widgets/comuns.dart';
import '../widgets/imagem.dart';

/// Lista de animais do acervo, com busca e ações de criar, duplicar e remover.
class TelaCavalos extends StatefulWidget {
  const TelaCavalos({super.key});

  @override
  State<TelaCavalos> createState() => _TelaCavalosState();
}

class _TelaCavalosState extends State<TelaCavalos> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);
    final termo = _busca.trim().toLowerCase();
    final lista = termo.isEmpty
        ? rep.cavalos
        : [
            for (final c in rep.cavalos)
              if (c.nome.toLowerCase().contains(termo) ||
                  c.registro.toLowerCase().contains(termo) ||
                  c.pelagem.toLowerCase().contains(termo))
                c,
          ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CabecalhoSecao(
          titulo: 'Cavalos',
          subtitulo: plural(rep.cavalos.length, 'animal cadastrado', 'animais cadastrados'),
          icone: Icons.pets_outlined,
          acao: FilledButton.icon(
            onPressed: () => _novo(context, rep),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Novo cavalo'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => _busca = v),
          decoration: const InputDecoration(
            hintText: 'Buscar por nome, registro ou pelagem',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(height: 16),
        if (lista.isEmpty)
          Painel(
            child: Vazio(
              icone: Icons.search_off,
              titulo: termo.isEmpty ? 'Nenhum animal cadastrado' : 'Nada encontrado',
              descricao: termo.isEmpty
                  ? 'Cadastre o primeiro cavalo para começar a preencher o acervo.'
                  : 'Nenhum animal corresponde a "$_busca".',
              acao: termo.isEmpty
                  ? FilledButton.icon(
                      onPressed: () => _novo(context, rep),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Novo cavalo'),
                    )
                  : null,
            ),
          ),
        for (final cavalo in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CartaoCavalo(cavalo: cavalo),
          ),
      ],
    );
  }

  /// Abre o assistente de cadastro.
  ///
  /// Antes, esta ação pedia nome e registro num diálogo e largava o operador no
  /// editor com o resto da ficha vazia. O animal entrava incompleto e dependia
  /// de quatro diálogos depois para ficar apresentável.
  void _novo(BuildContext context, Repositorio rep) => context.push(RotasAdmin.novoCavalo);
}

class _CartaoCavalo extends StatelessWidget {
  const _CartaoCavalo({required this.cavalo});

  final Cavalo cavalo;

  /// Copia o animal com um registro novo.
  ///
  /// O registro ABQM é único por conta no banco, e a cópia antiga mantinha o
  /// mesmo. A gravação falhava e o erro não aparecia: a cópia surgia na lista
  /// otimista e sumia no próximo carregamento. Agora o registro recebe sufixo
  /// e o operador é avisado se ainda assim falhar.
  Future<void> _duplicar(BuildContext context, Repositorio rep, Cavalo cavalo) async {
    final copia = cavalo.copiarCom(
      id: rep.novoId('copia'),
      nome: '${cavalo.nome} (CÓPIA)',
      registro: '${cavalo.registro}-COPIA',
      principal: false,
      provas: const [],
      midias: const [],
    );
    final ok = await rep.salvarCavalo(copia);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Cópia de ${cavalo.nome} criada com o registro ${copia.registro}.'
              : rep.erro ?? 'Não foi possível duplicar ${cavalo.nome}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);
    final baia = rep.baias.where((b) => b.cavaloId == cavalo.id).firstOrNull;

    return Painel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminRaios.pequeno),
            child: SizedBox(
              width: 52,
              height: 52,
              child: ImagemAcervo(
                cavalo.fotoPerfil,
                semImagem: const ColoredBox(
                  color: AdminCores.superficieSuave,
                  child: Icon(Icons.pets, color: AdminCores.textoSecundario),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cavalo.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (cavalo.principal) ...[
                      const SizedBox(width: 8),
                      const Etiqueta(
                        'Em destaque no app',
                        cor: AdminCores.verde,
                        fundo: AdminCores.verdeFundo,
                        icone: Icons.star,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${cavalo.registro} • ${cavalo.sexo.rotulo} • ${cavalo.pelagem} • '
                  '${cavalo.provas.length} provas • ${cavalo.midias.length} mídias',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Etiqueta(
                      baia == null ? 'Sem baia' : 'Baia ${baia.numero}',
                      cor: baia == null ? AdminCores.textoSecundario : AdminCores.azul,
                      fundo: baia == null ? AdminCores.superficieSuave : AdminCores.azulFundo,
                    ),
                    if (baia != null) ...[
                      const SizedBox(width: 6),
                      Etiqueta.status(baia.status.rotulo),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!cavalo.principal)
            IconButton(
              tooltip: 'Definir como destaque do app',
              onPressed: () async {
                final ok = await rep.definirPrincipal(cavalo.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '${cavalo.nome} agora é o destaque do aplicativo.'
                          : rep.erro ?? 'Não foi possível destacar ${cavalo.nome}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.star_border, size: 19),
            ),
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.go(RotasAdmin.cavalo(cavalo.id)),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          IconButton(
            tooltip: 'Duplicar',
            onPressed: () => _duplicar(context, rep, cavalo),
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
          IconButton(
            tooltip: 'Remover',
            onPressed: () => _remover(context, rep),
            icon: const Icon(Icons.delete_outline, size: 19, color: AdminCores.vermelho),
          ),
        ],
      ),
    );
  }

  Future<void> _remover(BuildContext context, Repositorio rep) async {
    final baia = rep.baias.where((b) => b.cavaloId == cavalo.id).firstOrNull;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover cavalo'),
        content: Text(
          '${cavalo.nome} será removido do acervo'
          '${baia != null ? ', junto com a baia ${baia.numero} que o abriga' : ''}. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AdminCores.vermelho),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final ok = await rep.removerCavalo(cavalo.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${cavalo.nome} removido.' : rep.erro ?? 'Não foi possível remover ${cavalo.nome}.'),
      ),
    );
  }
}
