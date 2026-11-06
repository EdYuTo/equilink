import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:equilink_core/equilink_core.dart';

import '../core/escopo.dart';
import '../core/tema.dart';
import '../widgets/comuns.dart';

// -----------------------------------------------------------------------------
// Ficha do animal
// -----------------------------------------------------------------------------

/// Dados cadastrais, proprietário, criador e descrição.
class AbaFicha extends StatelessWidget {
  const AbaFicha({super.key, required this.cavalo});

  final Cavalo cavalo;

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);
    final p = cavalo.proprietario;
    final c = cavalo.criador;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Identificação',
                icone: Icons.badge_outlined,
                acao: TextButton.icon(
                  onPressed: () => _editarIdentificacao(context, rep, cavalo),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                children: [
                  SizedBox(width: 190, child: Campo(rotulo: 'Nome', valor: cavalo.nome)),
                  SizedBox(width: 130, child: Campo(rotulo: 'Registro', valor: cavalo.registro)),
                  SizedBox(width: 110, child: Campo(rotulo: 'Sexo', valor: cavalo.sexo.rotulo)),
                  SizedBox(
                    width: 130,
                    child: Campo(
                      rotulo: 'Nascimento',
                      valor: _data(cavalo.nascimento),
                    ),
                  ),
                  SizedBox(width: 130, child: Campo(rotulo: 'Pelagem', valor: cavalo.pelagem)),
                  SizedBox(width: 160, child: Campo(rotulo: 'Raça', valor: cavalo.raca)),
                  SizedBox(width: 110, child: Campo(rotulo: 'Altura', valor: cavalo.altura)),
                  SizedBox(width: 110, child: Campo(rotulo: 'Peso', valor: cavalo.peso)),
                  SizedBox(
                    width: 170,
                    child: Campo(
                      rotulo: 'Foto de perfil',
                      valor: cavalo.fotoPerfil.isEmpty ? '—' : cavalo.fotoPerfil,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Proprietário e criador',
                icone: Icons.handshake_outlined,
                acao: TextButton.icon(
                  onPressed: () => _editarProprietario(context, rep, cavalo),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                children: [
                  SizedBox(width: 200, child: Campo(rotulo: 'Proprietário', valor: p.nome)),
                  SizedBox(width: 200, child: Campo(rotulo: 'Fazenda', valor: p.fazenda)),
                  SizedBox(width: 160, child: Campo(rotulo: 'Telefone', valor: p.telefone)),
                  SizedBox(width: 180, child: Campo(rotulo: 'Cidade', valor: p.cidade)),
                  SizedBox(width: 190, child: Campo(rotulo: 'Criador', valor: c.nome)),
                  SizedBox(width: 180, child: Campo(rotulo: 'Cidade do criador', valor: c.cidade)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Descrição',
                subtitulo: 'Texto exibido no perfil público do animal',
                icone: Icons.notes_outlined,
                acao: TextButton.icon(
                  onPressed: () => _editarDescricao(context, rep, cavalo),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                cavalo.descricao.isEmpty ? 'Sem descrição cadastrada.' : cavalo.descricao,
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminCores.textoSecundario,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editarIdentificacao(BuildContext context, Repositorio rep, Cavalo cavalo) async {
    final nome = TextEditingController(text: cavalo.nome);
    final registro = TextEditingController(text: cavalo.registro);
    final pelagem = TextEditingController(text: cavalo.pelagem);
    final altura = TextEditingController(text: cavalo.altura);
    final peso = TextEditingController(text: cavalo.peso);
    var sexo = cavalo.sexo;
    var nascimento = cavalo.nascimento;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Editar identificação'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Nome', controlador: nome),
                      _Campo(nome: 'Registro', controlador: registro),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      DropdownButtonFormField<Sexo>(
                        initialValue: sexo,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: [
                          for (final s in Sexo.values)
                            DropdownMenuItem(value: s, child: Text(s.rotulo)),
                        ],
                        onChanged: (v) => atualizar(() => sexo = v ?? sexo),
                      ),
                      _CampoData(
                        rotulo: 'Nascimento',
                        data: nascimento,
                        aoEscolher: (d) async {
                          final escolhida = await _escolherData(context, nascimento);
                          if (escolhida != null) atualizar(() => nascimento = escolhida);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Pelagem', controlador: pelagem),
                      _Campo(nome: 'Altura (ex.: 1,52 m)', controlador: altura),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Peso (ex.: 520 kg)', controlador: peso),
                      const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (salvar != true) return;
    await rep.salvarCavalo(
      cavalo.copiarCom(
        nome: nome.text.trim().toUpperCase(),
        registro: registro.text.trim().toUpperCase(),
        sexo: sexo,
        nascimento: nascimento,
        pelagem: pelagem.text.trim(),
        altura: altura.text.trim(),
        peso: peso.text.trim(),
      ),
    );
  }

  Future<void> _editarProprietario(BuildContext context, Repositorio rep, Cavalo cavalo) async {
    final p = cavalo.proprietario;
    final c = cavalo.criador;
    final nome = TextEditingController(text: p.nome);
    final fazenda = TextEditingController(text: p.fazenda);
    final telefone = TextEditingController(text: p.telefone);
    final cidade = TextEditingController(text: p.cidade);
    final criador = TextEditingController(text: c.nome);
    final cidadeCriador = TextEditingController(text: c.cidade);

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proprietário e criador'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Linha(
                  filhos: [
                    _Campo(nome: 'Proprietário', controlador: nome),
                    _Campo(nome: 'Fazenda', controlador: fazenda),
                  ],
                ),
                const SizedBox(height: 12),
                _Linha(
                  filhos: [
                    _Campo(nome: 'Telefone', controlador: telefone),
                    _Campo(nome: 'Cidade', controlador: cidade),
                  ],
                ),
                const SizedBox(height: 12),
                _Linha(
                  filhos: [
                    _Campo(nome: 'Criador', controlador: criador),
                    _Campo(nome: 'Cidade do criador', controlador: cidadeCriador),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar != true) return;

    await rep.salvarCavalo(
      cavalo.copiarCom(
        proprietario: p.copiarCom(
          nome: nome.text.trim(),
          fazenda: fazenda.text.trim(),
          telefone: telefone.text.trim(),
          cidade: cidade.text.trim(),
        ),
        criador: c.copiarCom(nome: criador.text.trim(), cidade: cidadeCriador.text.trim()),
      ),
    );
  }

  Future<void> _editarDescricao(BuildContext context, Repositorio rep, Cavalo cavalo) async {
    final texto = TextEditingController(text: cavalo.descricao);
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descrição do animal'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: texto,
            maxLines: 6,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Temperamento, linhagem e desempenho.'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar != true) return;
    await rep.atualizarDescricao(cavalo.id, texto.text.trim());
  }
}

// -----------------------------------------------------------------------------
// Genealogia
// -----------------------------------------------------------------------------

/// Edição dos ascendentes diretos e dos avós.
class AbaGenealogia extends StatelessWidget {
  const AbaGenealogia({super.key, required this.cavalo});

  final Cavalo cavalo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Ascendentes',
                subtitulo:
                    '${cavalo.genealogia.emLargura().length - 1} ancestrais em '
                    '${cavalo.genealogia.geracoes} níveis',
                icone: Icons.account_tree_outlined,
                acao: TextButton.icon(
                  onPressed: () => _editar(context, cavalo),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar pais'),
                ),
              ),
              const SizedBox(height: 16),
              _NoAncestral(papel: 'Pai', ancestral: cavalo.pai, profundidade: 0),
              const SizedBox(height: 10),
              _NoAncestral(papel: 'Mãe', ancestral: cavalo.mae, profundidade: 0),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CabecalhoSecao(
                titulo: 'Todos os ascendentes',
                subtitulo: 'Relação completa usada no perfil público',
                icone: Icons.list_alt_outlined,
              ),
              const SizedBox(height: 14),
              for (final a in cavalo.genealogia.emLargura().skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 15, color: AdminCores.dourado),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.nome,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${a.registro}${a.pelagem != null ? ' • ${a.pelagem}' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editar(BuildContext context, Cavalo cavalo) async {
    final rep = AdminEscopo.de(context);
    final resultado = await showDialog<(Ancestral, Ancestral)>(
      context: context,
      builder: (context) => _DialogoPais(pai: cavalo.pai, mae: cavalo.mae),
    );
    if (resultado == null) return;
    await rep.salvarCavalo(cavalo.copiarCom(pai: resultado.$1, mae: resultado.$2));
  }
}

class _NoAncestral extends StatelessWidget {
  const _NoAncestral({required this.papel, required this.ancestral, required this.profundidade});

  final String papel;
  final Ancestral ancestral;
  final int profundidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12.0 * profundidade),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminCores.superficieSuave,
          borderRadius: BorderRadius.circular(AdminRaios.pequeno),
          border: Border.all(color: AdminCores.borda),
        ),
        child: Row(
          children: [
            if (profundidade > 0) ...[
              const Icon(Icons.account_tree_outlined, size: 14, color: AdminCores.dourado),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 78,
              child: Text(
                papel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AdminCores.dourado,
                ),
              ),
            ),
            Expanded(
              child: Text(
                ancestral.nome,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${ancestral.registro}${ancestral.pelagem != null ? ' • ${ancestral.pelagem}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de edição dos pais, incluindo os quatro avós.
class _DialogoPais extends StatefulWidget {
  const _DialogoPais({required this.pai, required this.mae});

  final Ancestral pai;
  final Ancestral mae;

  @override
  State<_DialogoPais> createState() => _DialogoPaisState();
}

class _DialogoPaisState extends State<_DialogoPais> {
  final _paiNome = TextEditingController();
  final _paiRegistro = TextEditingController();
  final _maeNome = TextEditingController();
  final _maeRegistro = TextEditingController();

  final _avos = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _paiNome.text = widget.pai.nome;
    _paiRegistro.text = widget.pai.registro;
    _maeNome.text = widget.mae.nome;
    _maeRegistro.text = widget.mae.registro;
  }

  @override
  void dispose() {
    for (final c in [_paiNome, _paiRegistro, _maeNome, _maeRegistro, ..._avos]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar ascendentes'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AdminCores.dourado,
                ),
              ),
              const SizedBox(height: 8),
              _Linha(
                filhos: [
                  _Campo(nome: 'Nome', controlador: _paiNome),
                  _Campo(nome: 'Registro', controlador: _paiRegistro),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'MÃE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AdminCores.dourado,
                ),
              ),
              const SizedBox(height: 8),
              _Linha(
                filhos: [
                  _Campo(nome: 'Nome', controlador: _maeNome),
                  _Campo(nome: 'Registro', controlador: _maeRegistro),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Avós são preservados da árvore atual; edite-os abaixo se necessário.',
                style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            widget.pai.copiarCom(nome: _paiNome.text.trim(), registro: _paiRegistro.text.trim()),
            widget.mae.copiarCom(nome: _maeNome.text.trim(), registro: _maeRegistro.text.trim()),
          )),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Provas
// -----------------------------------------------------------------------------

/// Histórico esportivo do animal, com inclusão, edição e remoção.
class AbaProvas extends StatelessWidget {
  const AbaProvas({super.key, required this.cavalo});

  final Cavalo cavalo;

  @override
  Widget build(BuildContext context) {
    final provas = cavalo.provasRecentes;
    return Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabecalhoSecao(
            titulo: 'Provas',
            subtitulo: provas.isEmpty
                ? 'Nenhuma prova registrada'
                : '${provas.length} provas • ${cavalo.vitorias} vitórias • '
                      'melhor tempo ${cavalo.melhorTempo!.toStringAsFixed(3).replaceAll('.', ',')}s',
            icone: Icons.emoji_events_outlined,
            acao: FilledButton.icon(
              onPressed: () => _editar(context, null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nova prova'),
            ),
          ),
          const SizedBox(height: 16),
          if (provas.isEmpty)
            Vazio(
              icone: Icons.event_busy_outlined,
              titulo: 'Sem provas',
              descricao: 'Registre as participações para alimentar o histórico esportivo.',
              acao: FilledButton.icon(
                onPressed: () => _editar(context, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova prova'),
              ),
            ),
          for (final prova in provas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminCores.superficieSuave,
                  borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _cor(prova).$2,
                        borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                      ),
                      child: Text(
                        prova.temColocacao ? '${prova.colocacao}º' : '—',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _cor(prova).$1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${prova.nome} | ${prova.categoria}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_data(prova.data)} • ${prova.local} • '
                            '${prova.tempoSegundos.toStringAsFixed(3).replaceAll('.', ',')}s • '
                            '${prova.inscritos} inscritos',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AdminCores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (prova.premiacao != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          prova.premiacao!,
                          style: const TextStyle(fontSize: 12, color: AdminCores.verde),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => _editar(context, prova),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Remover',
                      onPressed: () => _remover(context, prova),
                      icon: const Icon(Icons.delete_outline, size: 18, color: AdminCores.vermelho),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static (Color, Color) _cor(Prova prova) => switch (prova.colocacao) {
    1 => (AdminCores.verde, AdminCores.verdeFundo),
    2 || 3 => (AdminCores.ambar, AdminCores.ambarFundo),
    _ => (AdminCores.textoSecundario, AdminCores.superficie),
  };

  Future<void> _editar(BuildContext context, Prova? prova) async {
    final rep = AdminEscopo.de(context);
    final nome = TextEditingController(text: prova?.nome ?? 'Três Tambores');
    final local = TextEditingController(text: prova?.local ?? '');
    final categoria = TextEditingController(text: prova?.categoria ?? 'Aberta');
    final colocacao = TextEditingController(text: '${prova?.colocacao ?? 1}');
    final tempo = TextEditingController(
      text: prova == null ? '' : prova.tempoSegundos.toStringAsFixed(3).replaceAll('.', ','),
    );
    final inscritos = TextEditingController(text: '${prova?.inscritos ?? 20}');
    final premiacao = TextEditingController(text: prova?.premiacao ?? '');
    var data = prova?.data ?? DateTime.now();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(prova == null ? 'Nova prova' : 'Editar prova'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Prova', controlador: nome),
                      _Campo(nome: 'Categoria', controlador: categoria),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Local', controlador: local),
                      _CampoData(
                        rotulo: 'Data',
                        data: data,
                        aoEscolher: (_) async {
                          final escolhida = await _escolherData(context, data);
                          if (escolhida != null) atualizar(() => data = escolhida);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Colocação', controlador: colocacao),
                      _Campo(nome: 'Tempo em segundos (ex.: 16,742)', controlador: tempo),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Linha(
                    filhos: [
                      _Campo(nome: 'Inscritos', controlador: inscritos),
                      _Campo(nome: 'Premiação (opcional)', controlador: premiacao),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (salvar != true) return;

    final nova = Prova(
      id: prova?.id ?? rep.novoId('prova'),
      data: data,
      nome: nome.text.trim(),
      local: local.text.trim(),
      categoria: categoria.text.trim(),
      colocacao: int.tryParse(colocacao.text.trim()) ?? 1,
      tempoSegundos:
          double.tryParse(tempo.text.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0,
      inscritos: int.tryParse(inscritos.text.trim()) ?? 0,
      premiacao: premiacao.text.trim().isEmpty ? null : premiacao.text.trim(),
    );

    final ok = await rep.salvarProva(cavalo.id, nova);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rep.erro ?? 'Não foi possível salvar a prova.')),
      );
    }
  }

  Future<void> _remover(BuildContext context, Prova prova) async {
    final rep = AdminEscopo.de(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover prova'),
        content: Text('${prova.nome} em ${_data(prova.data)} será removida do histórico.'),
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
    await rep.removerProva(cavalo.id, prova.id);
  }
}

// -----------------------------------------------------------------------------
// Mídias
// -----------------------------------------------------------------------------

/// Fotos e vídeos do animal.
class AbaMidias extends StatelessWidget {
  const AbaMidias({super.key, required this.cavalo});

  final Cavalo cavalo;

  @override
  Widget build(BuildContext context) {
    return Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabecalhoSecao(
            titulo: 'Fotos e vídeos',
            subtitulo: '${cavalo.fotos.length} fotos • ${cavalo.videos.length} vídeos',
            icone: Icons.photo_library_outlined,
            acao: FilledButton.icon(
              onPressed: () => _editar(context, null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nova mídia'),
            ),
          ),
          const SizedBox(height: 16),
          if (cavalo.midias.isEmpty)
            Vazio(
              icone: Icons.image_not_supported_outlined,
              titulo: 'Sem mídias',
              descricao: 'As mídias alimentam a galeria exibida no aplicativo.',
              acao: FilledButton.icon(
                onPressed: () => _editar(context, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova mídia'),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final midia in cavalo.midias)
                SizedBox(
                  width: 280,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Miniatura: é o que permite reconhecer a mídia sem abrir.
                        // A URL remota é a mesma que o aplicativo exibe.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: _MiniaturaMidia(midia: midia),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              midia.tipo == TipoMidia.foto ? Icons.image_outlined : Icons.videocam_outlined,
                              size: 16,
                              color: AdminCores.dourado,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                midia.legenda.isEmpty ? '(sem legenda)' : midia.legenda,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          midia.arquivo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AdminCores.textoSecundario),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Etiqueta(
                              midia.tipo == TipoMidia.foto ? 'Foto' : 'Vídeo',
                              cor: midia.tipo == TipoMidia.foto ? AdminCores.azul : AdminCores.ambar,
                              fundo: midia.tipo == TipoMidia.foto
                                  ? AdminCores.azulFundo
                                  : AdminCores.ambarFundo,
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => _editar(context, midia),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                            ),
                            IconButton(
                              tooltip: 'Remover',
                              onPressed: () => _remover(context, midia),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 17,
                                color: AdminCores.vermelho,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tipos que a API aceita; a mesma lista em `TIPOS_MIDIA` no Worker.
  static const _tiposAceitos = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'avif': 'image/avif',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
  };

  Future<void> _editar(BuildContext context, Midia? midia) async {
    final rep = AdminEscopo.de(context);
    final legenda = TextEditingController(text: midia?.legenda ?? '');
    final local = TextEditingController(text: midia?.local ?? '');
    var tipo = midia?.tipo ?? TipoMidia.foto;

    // Estado do arquivo: no modo edição começa com a URL atual.
    String? arquivo = midia?.arquivo;
    Uint8List? bytesNovos;
    String? nomeNovo;
    String? tipoNovo;
    String? erroArquivo;
    var enviando = false;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) {
          // Dart não promove variável capturada e mutável; os snapshots abaixo
          // dão ao compilador um valor estável por build.
          final bytesAtuais = bytesNovos;
          final arquivoAtual = arquivo;
          final erroAtual = erroArquivo;

          Future<void> escolherArquivo() async {
            final escolhido = await FilePicker.pickFile(
              dialogTitle: 'Escolher foto ou vídeo',
              type: FileType.custom,
              allowedExtensions: _tiposAceitos.keys.toList(),
            );
            if (escolhido == null) return;

            final extensao = (escolhido.extension ?? '').toLowerCase();
            final tipoConteudo = _tiposAceitos[extensao];
            if (tipoConteudo == null) {
              atualizar(() => erroArquivo = 'Extensão .$extensao não é aceita.');
              return;
            }
            if (escolhido.lengthSync() != null && escolhido.lengthSync()! > 50 * 1024 * 1024) {
              atualizar(() => erroArquivo = 'Arquivo acima de 50 MB.');
              return;
            }

            atualizar(() {
              enviando = true;
              erroArquivo = null;
            });

            final lidos = await escolhido.readAsBytes();
            atualizar(() {
              bytesNovos = lidos;
              nomeNovo = escolhido.name;
              tipoNovo = tipoConteudo;
              tipo = tipoConteudo.startsWith('video/') ? TipoMidia.video : TipoMidia.foto;
              enviando = false;
            });
          }

          return AlertDialog(
            title: Text(midia == null ? 'Nova mídia' : 'Editar mídia'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Linha(
                      filhos: [
                        DropdownButtonFormField<TipoMidia>(
                          initialValue: tipo,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(value: TipoMidia.foto, child: Text('Foto')),
                            DropdownMenuItem(value: TipoMidia.video, child: Text('Vídeo')),
                          ],
                          onChanged: (v) => atualizar(() => tipo = v ?? tipo),
                        ),
                        _Campo(nome: 'Local', controlador: local),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Campo(nome: 'Legenda', controlador: legenda),
                    const SizedBox(height: 16),
                    const Text(
                      'Arquivo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminCores.superficieSuave,
                        borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                        border: Border.all(color: AdminCores.borda),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bytesAtuais != null)
                            Text(
                              '$nomeNovo • ${(bytesAtuais.length / 1024).toStringAsFixed(0)} KB — será enviado ao salvar',
                              style: const TextStyle(fontSize: 12, color: AdminCores.verde),
                            )
                          else if (arquivoAtual != null)
                            Text(
                              arquivoAtual,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
                            )
                          else
                            const Text(
                              'Nenhum arquivo escolhido.',
                              style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: enviando ? null : escolherArquivo,
                                icon: enviando
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.upload_file, size: 16),
                                label: Text(arquivoAtual == null ? 'Escolher arquivo' : 'Trocar arquivo'),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'JPEG, PNG, WebP, AVIF, GIF, MP4, WebM ou MOV · até 50 MB',
                                  style: TextStyle(fontSize: 11, color: AdminCores.textoSecundario),
                                ),
                              ),
                            ],
                          ),
                          if (erroAtual != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              erroAtual,
                              style: const TextStyle(fontSize: 11.5, color: AdminCores.vermelho),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: enviando ? null : () => Navigator.of(context).pop(true),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    if (salvar != true) return;

    // O arquivo sobe antes de a mídia existir: se o envio falhar, nada é gravado
    // e o operador não fica com um registro apontando para uma URL vazia.
    if (bytesNovos != null) {
      final url = await rep.enviarMidia(
        cavalo.id,
        bytes: bytesNovos!,
        tipoConteudo: tipoNovo!,
        nomeArquivo: nomeNovo!,
      );
      if (url == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(rep.erro ?? 'Falha ao enviar a mídia.')),
          );
        }
        return;
      }
      arquivo = url;
    }

    if (arquivo == null || arquivo.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escolha um arquivo para a mídia.')),
        );
      }
      return;
    }

    final nova = Midia(
      id: midia?.id ?? rep.novoId('midia'),
      tipo: tipo,
      arquivo: arquivo,
      legenda: legenda.text.trim(),
      local: local.text.trim().isEmpty ? null : local.text.trim(),
      duracaoSegundos: midia?.duracaoSegundos,
      poster: midia?.poster,
    );
    await rep.salvarMidia(cavalo.id, nova);
  }

  Future<void> _remover(BuildContext context, Midia midia) async {
    final rep = AdminEscopo.de(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover mídia'),
        content: Text('"${midia.legenda}" será removida da galeria.'),
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
    await rep.removerMidia(cavalo.id, midia.id);
  }
}

// -----------------------------------------------------------------------------
// Baia e manejo
// -----------------------------------------------------------------------------

/// Baia do animal: situação, rotina de manejo, ocorrências e observações.
class AbaBaia extends StatelessWidget {
  const AbaBaia({super.key, required this.cavalo, required this.baia});

  final Cavalo cavalo;
  final Baia? baia;

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);
    final atual = baia;

    if (atual == null) {
      return Painel(
        child: Vazio(
          icone: Icons.home_work_outlined,
          titulo: 'Sem baia atribuída',
          descricao: 'Crie uma baia para este animal acompanhar manejo e ocorrências.',
          acao: FilledButton.icon(
            onPressed: () async {
              await rep.adicionarBaia(cavaloId: cavalo.id, status: StatusBaia.emDia);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Baia criada com a rotina padrão.')),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Criar baia'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Baia ${atual.numero}',
                subtitulo: '${atual.area} • ${atual.manejo.length} tarefas de rotina',
                icone: Icons.home_work_outlined,
                acao: Row(
                  children: [
                    DropdownButton<StatusBaia>(
                      value: atual.status,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final s in StatusBaia.values)
                          DropdownMenuItem(value: s, child: Text(s.rotulo)),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await rep.alterarStatusBaia(atual.numero, v);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remover baia',
                      onPressed: () async {
                        await rep.removerBaia(atual.numero);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Baia ${atual.numero} removida.')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, size: 19, color: AdminCores.vermelho),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                children: [
                  SizedBox(width: 150, child: Campo(rotulo: 'Área', valor: atual.area)),
                  SizedBox(
                    width: 170,
                    child: Campo(rotulo: 'Última limpeza', valor: _dataHora(atual.ultimaLimpeza)),
                  ),
                  SizedBox(width: 140, child: Campo(rotulo: 'Pendentes', valor: '${atual.pendentes}')),
                  SizedBox(
                    width: 140,
                    child: Campo(rotulo: 'Ocorrências', valor: '${atual.ocorrencias.length}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Rotina de manejo',
                subtitulo: 'Alimentação, água, exercício, higiene e saúde',
                icone: Icons.checklist_outlined,
                acao: FilledButton.icon(
                  onPressed: () => _novaTarefa(context, rep, atual),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova tarefa'),
                ),
              ),
              const SizedBox(height: 14),
              if (atual.manejo.isEmpty)
                const Vazio(icone: Icons.checklist_outlined, titulo: 'Rotina vazia'),
              for (final tarefa in atual.manejo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AdminCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            tarefa.horario,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AdminCores.dourado,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tarefa.descricao,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                tarefa.tipo.rotulo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminCores.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            tarefa.quantidade,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _novaTarefa(context, rep, atual, tarefa),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => rep.removerTarefa(atual.numero, tarefa.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AdminCores.vermelho,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Ocorrências',
                icone: Icons.report_problem_outlined,
                acao: FilledButton.icon(
                  onPressed: () => _novaOcorrencia(context, rep, atual),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Registrar'),
                ),
              ),
              const SizedBox(height: 14),
              if (atual.ocorrencias.isEmpty)
                const Vazio(icone: Icons.check_circle_outline, titulo: 'Nenhuma ocorrência'),
              for (final o in atual.ocorrencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                    ),
                    child: Row(
                      children: [
                        Etiqueta(
                          o.tipo.rotulo,
                          cor: switch (o.tipo) {
                            TipoOcorrencia.saude => AdminCores.vermelho,
                            TipoOcorrencia.manejo => AdminCores.azul,
                            TipoOcorrencia.estrutura => AdminCores.ambar,
                          },
                          fundo: switch (o.tipo) {
                            TipoOcorrencia.saude => AdminCores.vermelhoFundo,
                            TipoOcorrencia.manejo => AdminCores.azulFundo,
                            TipoOcorrencia.estrutura => AdminCores.ambarFundo,
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.descricao, style: const TextStyle(fontSize: 12.5)),
                              Text(
                                '${_dataHora(o.data)} • ${o.responsavel}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminCores.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Etiqueta(
                          o.resolvida ? 'Resolvida' : 'Em aberto',
                          cor: o.resolvida ? AdminCores.verde : AdminCores.vermelho,
                          fundo: o.resolvida ? AdminCores.verdeFundo : AdminCores.vermelhoFundo,
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => rep.removerOcorrencia(atual.numero, o.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AdminCores.vermelho,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabecalhoSecao(
                titulo: 'Observações',
                icone: Icons.sticky_note_2_outlined,
                acao: FilledButton.icon(
                  onPressed: () => _novaObservacao(context, rep, atual),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova'),
                ),
              ),
              const SizedBox(height: 14),
              if (atual.observacoes.isEmpty)
                const Vazio(icone: Icons.sticky_note_2_outlined, titulo: 'Nenhuma observação'),
              for (final o in atual.observacoes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.texto, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                              Text(
                                '${o.autor} • ${_dataHora(o.data)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminCores.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => rep.removerObservacao(atual.numero, o.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AdminCores.vermelho,
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

  Future<void> _novaTarefa(
    BuildContext context,
    Repositorio rep,
    Baia baia, [
    TarefaManejo? existente,
  ]) async {
    final descricao = TextEditingController(text: existente?.descricao ?? '');
    final horario = TextEditingController(text: existente?.horario ?? '06:00');
    final quantidade = TextEditingController(text: existente?.quantidade ?? '');
    final responsavel = TextEditingController(text: existente?.responsavel ?? '');
    var tipo = existente?.tipo ?? TipoManejo.alimentacao;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(existente == null ? 'Nova tarefa de manejo' : 'Editar tarefa'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Linha(
                  filhos: [
                    DropdownButtonFormField<TipoManejo>(
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final t in TipoManejo.values)
                          DropdownMenuItem(value: t, child: Text(t.rotulo)),
                      ],
                      onChanged: (v) => atualizar(() => tipo = v ?? tipo),
                    ),
                    _Campo(nome: 'Descrição', controlador: descricao),
                  ],
                ),
                const SizedBox(height: 12),
                _Linha(
                  filhos: [
                    _Campo(nome: 'Horário (HH:mm)', controlador: horario),
                    _Campo(nome: 'Quantidade (ex.: 1,5 kg)', controlador: quantidade),
                  ],
                ),
                const SizedBox(height: 12),
                _Linha(
                  filhos: [
                    _Campo(nome: 'Responsável', controlador: responsavel),
                    const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (salvar != true) return;

    if (existente == null) {
      await rep.adicionarTarefa(
        baia.numero,
        tipo: tipo,
        descricao: descricao.text.trim(),
        horario: horario.text.trim(),
        quantidade: quantidade.text.trim(),
        responsavel: responsavel.text.trim(),
      );
    } else {
      await rep.atualizarBaia(
        baia.copiarCom(
          manejo: [
            for (final t in baia.manejo)
              if (t.id == existente.id)
                t.copiarCom(
                  tipo: tipo,
                  descricao: descricao.text.trim(),
                  horario: horario.text.trim(),
                  quantidade: quantidade.text.trim(),
                  responsavel: responsavel.text.trim(),
                )
              else
                t,
          ],
        ),
      );
    }
  }

  Future<void> _novaOcorrencia(BuildContext context, Repositorio rep, Baia baia) async {
    final descricao = TextEditingController();
    final responsavel = TextEditingController(text: 'Eu mesmo');
    var tipo = TipoOcorrencia.saude;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Registrar ocorrência'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TipoOcorrencia>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final t in TipoOcorrencia.values)
                      DropdownMenuItem(value: t, child: Text(t.rotulo)),
                  ],
                  onChanged: (v) => atualizar(() => tipo = v ?? tipo),
                ),
                const SizedBox(height: 12),
                _Campo(nome: 'Descrição', controlador: descricao),
                const SizedBox(height: 12),
                _Campo(nome: 'Responsável', controlador: responsavel),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Registrar')),
          ],
        ),
      ),
    );
    if (salvar != true || descricao.text.trim().isEmpty) return;
    await rep.adicionarOcorrencia(
      baia.numero,
      tipo: tipo,
      descricao: descricao.text.trim(),
      responsavel: responsavel.text.trim().isEmpty ? 'Não informado' : responsavel.text.trim(),
    );
  }

  Future<void> _novaObservacao(BuildContext context, Repositorio rep, Baia baia) async {
    final texto = TextEditingController();
    final autor = TextEditingController(text: 'Eu mesmo');

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova observação'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Campo(nome: 'Observação', controlador: texto, linhas: 3),
              const SizedBox(height: 12),
              _Campo(nome: 'Autor', controlador: autor),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar != true || texto.text.trim().isEmpty) return;
    await rep.adicionarObservacao(
      baia.numero,
      autor: autor.text.trim().isEmpty ? 'Eu mesmo' : autor.text.trim(),
      texto: texto.text.trim(),
    );
  }
}

// -----------------------------------------------------------------------------
// Auxiliares de formulário
// -----------------------------------------------------------------------------

/// Duas colunas de campos, empilhando em telas estreitas.
class _Linha extends StatelessWidget {
  const _Linha({required this.filhos});

  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < filhos.length; i++) ...[
          Expanded(child: filhos[i]),
          if (i != filhos.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.nome, required this.controlador, this.linhas = 1});

  final String nome;
  final TextEditingController controlador;
  final int linhas;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      maxLines: linhas,
      decoration: InputDecoration(labelText: nome),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({required this.rotulo, required this.data, required this.aoEscolher});

  final String rotulo;
  final DateTime data;
  final ValueChanged<DateTime> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => aoEscolher(data),
      child: InputDecorator(
        decoration: InputDecoration(labelText: rotulo, suffixIcon: const Icon(Icons.event, size: 17)),
        child: Text(_data(data), style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}

Future<DateTime?> _escolherData(BuildContext context, DateTime atual) => showDatePicker(
  context: context,
  initialDate: atual,
  firstDate: DateTime(1990),
  lastDate: DateTime(2100),
  helpText: 'Escolha a data',
  cancelText: 'Cancelar',
  confirmText: 'Confirmar',
);

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _dataHora(DateTime d) => '${_data(d)} às ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';


/// Miniatura de uma mídia no painel.
///
/// Aceita tanto `assets/...` (acervo de demonstração) quanto a URL do R2 que o
/// upload devolve. Sem isso o cartão mostrava apenas o caminho do arquivo.
class _MiniaturaMidia extends StatelessWidget {
  const _MiniaturaMidia({required this.midia});

  final Midia midia;

  bool get _remota =>
      midia.arquivo.startsWith('http://') || midia.arquivo.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final capa = midia.tipo == TipoMidia.video
        ? (midia.poster ?? MidiaPadrao.capaVideo)
        : midia.arquivo;

    final imagem = capa.startsWith('http')
        ? Image.network(
            capa,
            fit: BoxFit.cover,
            errorBuilder: (context, erro, pilha) => const _SemMiniatura(),
            loadingBuilder: (context, filho, progresso) =>
                progresso == null ? filho : const _SemMiniatura(),
          )
        : Image.asset(
            capa,
            fit: BoxFit.cover,
            errorBuilder: (context, erro, pilha) => const _SemMiniatura(),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        imagem,
        if (midia.tipo == TipoMidia.video)
          const Center(
            child: Icon(Icons.play_circle_outline, size: 30, color: Colors.white70),
          ),
        if (_remota)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AdminRaios.total),
              ),
              child: const Text(
                'R2',
                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _SemMiniatura extends StatelessWidget {
  const _SemMiniatura();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AdminCores.superficieSuave,
      child: Center(
        child: Icon(Icons.broken_image_outlined, size: 20, color: AdminCores.textoSecundario),
      ),
    );
  }
}
