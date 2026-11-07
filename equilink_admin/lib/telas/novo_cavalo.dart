import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:equilink_core/equilink_core.dart';

import '../core/escopo.dart';
import '../core/tema.dart';
import '../rotas.dart';
import '../widgets/comuns.dart';

/// Cadastro completo de um cavalo, em passos.
///
/// O cadastro antigo pedia só nome e registro e largava o operador no editor. Na
/// prática o animal entrava incompleto: sem genealogia, sem foto, sem baia, e a
/// ficha só era preenchida depois, em quatro diálogos separados.
///
/// Aqui cada passo é pequeno o bastante para caber numa tela, e o animal só é
/// gravado no fim — se o operador desistir no meio, nada fica pela metade no
/// acervo.
class TelaNovoCavalo extends StatefulWidget {
  const TelaNovoCavalo({super.key});

  @override
  State<TelaNovoCavalo> createState() => _TelaNovoCavaloState();
}

/// Um passo do assistente: rótulo e o que ele pede.
class _Passo {
  const _Passo(this.rotulo, this.icone, this.descricao);

  final String rotulo;
  final IconData icone;
  final String descricao;
}

const _passos = <_Passo>[
  _Passo('Identificação', Icons.badge_outlined, 'Como o animal se chama e como se reconhece.'),
  _Passo('Ascendentes', Icons.account_tree_outlined, 'Pai e mãe; os avós são opcionais.'),
  _Passo('Proprietário', Icons.handshake_outlined, 'Quem responde pelo animal e onde ele fica.'),
  _Passo('Mídia e rotina', Icons.photo_library_outlined, 'Foto de perfil, galeria e baia.'),
  _Passo('Revisão', Icons.fact_check_outlined, 'Confira antes de gravar no acervo.'),
];

class _TelaNovoCavaloState extends State<TelaNovoCavalo> {
  int _passo = 0;
  bool _salvando = false;
  String? _erro;

  // Passo 1 — identificação.
  final _nome = TextEditingController();
  final _registro = TextEditingController();
  final _pelagem = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  final _descricao = TextEditingController();
  var _sexo = Sexo.femea;
  var _nascimento = DateTime(2020, 1, 1);

  // Passo 2 — ascendentes.
  final _paiNome = TextEditingController();
  final _paiRegistro = TextEditingController();
  final _maeNome = TextEditingController();
  final _maeRegistro = TextEditingController();
  final _avoPaterno = TextEditingController();
  final _avoPaterna = TextEditingController();
  final _avoMaterno = TextEditingController();
  final _avoMaterna = TextEditingController();

  // Passo 3 — proprietário e criador.
  final _propNome = TextEditingController();
  final _propFazenda = TextEditingController();
  final _propTelefone = TextEditingController();
  final _propCidade = TextEditingController();
  final _criadorNome = TextEditingController();
  final _criadorCidade = TextEditingController();

  // Passo 4 — mídia e baia.
  String? _fotoPerfil;
  Uint8List? _fotoBytes;
  String? _fotoNome;
  String? _fotoTipo;
  String? _erroFoto;
  bool _enviandoFoto = false;
  var _criarBaia = false;
  var _statusBaia = StatusBaia.emDia;

  @override
  void dispose() {
    for (final c in [
      _nome, _registro, _pelagem, _altura, _peso, _descricao,
      _paiNome, _paiRegistro, _maeNome, _maeRegistro,
      _avoPaterno, _avoPaterna, _avoMaterno, _avoMaterna,
      _propNome, _propFazenda, _propTelefone, _propCidade,
      _criadorNome, _criadorCidade,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _identificacaoValida =>
      _nome.text.trim().isNotEmpty && _registro.text.trim().isNotEmpty;

  /// Tipos aceitos pela API; a mesma lista vive em `TIPOS_MIDIA` no Worker.
  static const _tiposAceitos = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'avif': 'image/avif',
    'gif': 'image/gif',
  };

  Future<void> _escolherFoto() async {
    final escolhido = await FilePicker.pickFile(
      dialogTitle: 'Escolher foto de perfil',
      type: FileType.custom,
      allowedExtensions: _tiposAceitos.keys.toList(),
    );
    if (escolhido == null) return;

    final extensao = (escolhido.extension ?? '').toLowerCase();
    final tipo = _tiposAceitos[extensao];
    if (tipo == null) {
      setState(() => _erroFoto = 'Extensão .$extensao não é aceita.');
      return;
    }

    setState(() {
      _enviandoFoto = true;
      _erroFoto = null;
    });
    final bytes = await escolhido.readAsBytes();
    if (!mounted) return;
    setState(() {
      _fotoBytes = bytes;
      _fotoNome = escolhido.name;
      _fotoTipo = tipo;
      _enviandoFoto = false;
    });
  }

  void _avancar() {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);
    if (_passo == 0 && !_identificacaoValida) {
      setState(() => _erro = 'Informe nome e registro para continuar.');
      return;
    }
    if (_passo == 0) {
      final repetido = _animalRepetido();
      if (repetido != null) {
        setState(() => _erro = repetido);
        return;
      }
    }
    if (_passo < _passos.length - 1) setState(() => _passo += 1);
  }

  /// O id vem do nome: repetir o nome sobrescreveria o animal já cadastrado, e
  /// repetir o registro seria recusado pelo banco com um erro genérico.
  String? _animalRepetido() {
    final id = _idDoNome(_nome.text);
    final registro = _registro.text.trim().toUpperCase();
    for (final c in AdminEscopo.de(context).cavalos) {
      if (c.id == id) return 'Já existe um animal com esse nome: ${c.nome}. Use a lista de cavalos para editá-lo.';
      if (c.registro.trim().toUpperCase() == registro) {
        return 'Já existe um animal com esse registro: ${c.nome}. Use a lista de cavalos para editá-lo.';
      }
    }
    return null;
  }

  void _voltar() {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);
    if (_passo == 0) {
      context.pop();
    } else {
      setState(() => _passo -= 1);
    }
  }

  /// Monta o cavalo a partir do preenchido, sem gravar.
  Cavalo _montarCavalo(String id, String fotoPerfil) {
    Ancestral no(String nome, String registro, {Ancestral? pai, Ancestral? mae}) => Ancestral(
      nome: nome.trim().isEmpty ? '—' : nome.trim().toUpperCase(),
      registro: registro.trim().isEmpty ? '—' : registro.trim().toUpperCase(),
      pai: pai,
      mae: mae,
    );

    final avoP = _avoPaterno.text.trim().isEmpty ? null : no(_avoPaterno.text, '');
    final avoPa = _avoPaterna.text.trim().isEmpty ? null : no(_avoPaterna.text, '');
    final avoM = _avoMaterno.text.trim().isEmpty ? null : no(_avoMaterno.text, '');
    final avoMa = _avoMaterna.text.trim().isEmpty ? null : no(_avoMaterna.text, '');

    return Cavalo(
      id: id,
      nome: _recolherRepeticao(_nome.text).toUpperCase(),
      registro: _registro.text.trim().toUpperCase(),
      sexo: _sexo,
      nascimento: _nascimento,
      pelagem: _pelagem.text.trim(),
      raca: 'Quarto de Milha',
      altura: _altura.text.trim(),
      peso: _peso.text.trim(),
      descricao: _descricao.text.trim(),
      proprietario: Proprietario(
        nome: _propNome.text.trim(),
        fazenda: _propFazenda.text.trim(),
        telefone: _propTelefone.text.trim(),
        cidade: _propCidade.text.trim(),
      ),
      criador: Criador(nome: _criadorNome.text.trim(), cidade: _criadorCidade.text.trim()),
      pai: no(_paiNome.text, _paiRegistro.text, pai: avoP, mae: avoPa),
      mae: no(_maeNome.text, _maeRegistro.text, pai: avoM, mae: avoMa),
      fotoPerfil: fotoPerfil,
      midias: const [],
      provas: const [],
      principal: false,
    );
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final rep = AdminEscopo.de(context);

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final base = DateTime.now().microsecondsSinceEpoch;
    var foto = _fotoPerfil ?? MidiaPadrao.imagem;

    // O arquivo sobe antes de o cavalo existir: o id do cavalo é derivado do
    // nome, e a API exige um cavalo já gravado para aceitar a mídia. Por isso o
    // envio acontece depois da primeira gravação, num segundo passo curto.
    final id = _idDoNome(_nome.text);
    final idFinal = id.isEmpty ? 'cavalo-$base' : id;

    final novo = _montarCavalo(idFinal, foto);
    final ok = await rep.salvarCavalo(novo);
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = rep.erro ?? 'Não foi possível gravar o animal.';
      });
      return;
    }

    // Foto: envia com o cavalo já gravado, para a API aceitar o upload.
    if (_fotoBytes != null) {
      final url = await rep.enviarMidia(
        idFinal,
        bytes: _fotoBytes!,
        tipoConteudo: _fotoTipo!,
        nomeArquivo: _fotoNome!,
      );
      if (url != null) {
        foto = url;
        await rep.salvarCavalo(novo.copiarCom(fotoPerfil: url));
      }
    }

    if (_criarBaia) {
      await rep.adicionarBaia(cavaloId: idFinal, status: _statusBaia);
    }

    if (!mounted) return;
    context.go(RotasAdmin.cavalo(idFinal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${novo.nome} cadastrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passo = _passos[_passo];

    return Scaffold(
      backgroundColor: AdminCores.fundo,
      appBar: AppBar(
        title: const Text('Novo cavalo'),
        leading: IconButton(
          tooltip: _passo == 0 ? 'Voltar' : 'Passo anterior',
          icon: const Icon(Icons.arrow_back),
          onPressed: _salvando ? null : _voltar,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              _TrilhaPassos(atual: _passo, passos: _passos),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Painel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(passo.icone, size: 18, color: AdminCores.dourado),
                                const SizedBox(width: 8),
                                Text(
                                  passo.rotulo,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AdminCores.texto,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              passo.descricao,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminCores.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ..._conteudoPasso(),
                          ],
                        ),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminCores.vermelhoFundo,
                            borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                          ),
                          child: Text(
                            _erro!,
                            style: const TextStyle(fontSize: 12, color: AdminCores.vermelho),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _BarraAcoes(
                passo: _passo,
                total: _passos.length,
                salvando: _salvando,
                aoVoltar: _voltar,
                aoAvancar: _avancar,
                aoSalvar: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudoPasso() => switch (_passo) {
    0 => _passoIdentificacao(),
    1 => _passoAscendentes(),
    2 => _passoProprietario(),
    3 => _passoMidiaEBaia(),
    _ => _passoRevisao(),
  };

  // ---------------------------------------------------------------------------
  // Passo 1
  // ---------------------------------------------------------------------------

  List<Widget> _passoIdentificacao() => [
    _Linha(filhos: [
      _Campo(nome: 'Nome', controlador: _nome, obrigatorio: true),
      _Campo(nome: 'Registro ABQM', controlador: _registro, obrigatorio: true),
    ]),
    const SizedBox(height: 12),
    _Linha(filhos: [
      DropdownButtonFormField<Sexo>(
        initialValue: _sexo,
        decoration: const InputDecoration(labelText: 'Sexo'),
        items: [
          for (final s in Sexo.values)
            DropdownMenuItem(value: s, child: Text(s.rotulo)),
        ],
        onChanged: (v) => setState(() => _sexo = v ?? _sexo),
      ),
      _CampoData(
        rotulo: 'Nascimento',
        data: _nascimento,
        aoEscolher: (_) async {
          final escolhida = await showDatePicker(
            context: context,
            initialDate: _nascimento,
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
            helpText: 'Data de nascimento',
          );
          if (escolhida != null) setState(() => _nascimento = escolhida);
        },
      ),
    ]),
    const SizedBox(height: 12),
    _Linha(filhos: [
      _Campo(nome: 'Pelagem', controlador: _pelagem),
      _Campo(nome: 'Altura (ex.: 1,52 m)', controlador: _altura),
      _Campo(nome: 'Peso (ex.: 520 kg)', controlador: _peso),
    ]),
    const SizedBox(height: 12),
    _Campo(nome: 'Descrição para o perfil público', controlador: _descricao, linhas: 3),
  ];

  // ---------------------------------------------------------------------------
  // Passo 2
  // ---------------------------------------------------------------------------

  List<Widget> _passoAscendentes() => [
    const _RotuloSecao('PAI'),
    const SizedBox(height: 8),
    _Linha(filhos: [
      _Campo(nome: 'Nome do pai', controlador: _paiNome),
      _Campo(nome: 'Registro', controlador: _paiRegistro),
    ]),
    const SizedBox(height: 10),
    _Linha(filhos: [
      _Campo(nome: 'Avô paterno', controlador: _avoPaterno),
      _Campo(nome: 'Avó paterna', controlador: _avoPaterna),
    ]),
    const SizedBox(height: 20),
    const _RotuloSecao('MÃE'),
    const SizedBox(height: 8),
    _Linha(filhos: [
      _Campo(nome: 'Nome da mãe', controlador: _maeNome),
      _Campo(nome: 'Registro', controlador: _maeRegistro),
    ]),
    const SizedBox(height: 10),
    _Linha(filhos: [
      _Campo(nome: 'Avô materno', controlador: _avoMaterno),
      _Campo(nome: 'Avó materna', controlador: _avoMaterna),
    ]),
    const SizedBox(height: 14),
    const Text(
      'Os avós são opcionais. Sem eles, a genealogia exibe apenas pai e mãe.',
      style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario, height: 1.4),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Passo 3
  // ---------------------------------------------------------------------------

  List<Widget> _passoProprietario() => [
    const _RotuloSecao('PROPRIETÁRIO'),
    const SizedBox(height: 8),
    _Linha(filhos: [
      _Campo(nome: 'Nome', controlador: _propNome),
      _Campo(nome: 'Fazenda', controlador: _propFazenda),
    ]),
    const SizedBox(height: 12),
    _Linha(filhos: [
      _Campo(nome: 'Telefone', controlador: _propTelefone),
      _Campo(nome: 'Cidade', controlador: _propCidade),
    ]),
    const SizedBox(height: 20),
    const _RotuloSecao('CRIADOR'),
    const SizedBox(height: 8),
    _Linha(filhos: [
      _Campo(nome: 'Nome do criadouro', controlador: _criadorNome),
      _Campo(nome: 'Cidade', controlador: _criadorCidade),
    ]),
    const SizedBox(height: 14),
    const Text(
      'O telefone do proprietário é privado: aparece só para quem tem acesso ao '
      'sua conta, nunca no perfil público.',
      style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario, height: 1.4),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Passo 4
  // ---------------------------------------------------------------------------

  List<Widget> _passoMidiaEBaia() {
    final bytes = _fotoBytes;
    return [
      const _RotuloSecao('FOTO DE PERFIL'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminCores.superficieSuave,
          borderRadius: BorderRadius.circular(AdminRaios.pequeno),
          border: Border.all(color: AdminCores.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bytes != null
                  ? '$_fotoNome • ${(bytes.length / 1024).toStringAsFixed(0)} KB — será enviada ao concluir'
                  : 'Sem foto: o perfil usa a imagem padrão.',
              style: TextStyle(
                fontSize: 12,
                color: bytes != null ? AdminCores.verde : AdminCores.textoSecundario,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _enviandoFoto ? null : _escolherFoto,
              icon: _enviandoFoto
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 16),
              label: Text(bytes == null ? 'Escolher foto' : 'Trocar foto'),
            ),
            if (_erroFoto != null) ...[
              const SizedBox(height: 8),
              Text(
                _erroFoto!,
                style: const TextStyle(fontSize: 11.5, color: AdminCores.vermelho),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
      const _RotuloSecao('BAIA'),
      const SizedBox(height: 8),
      // Material próprio: o ListTile pinta fundo e ripple no Material mais
      // próximo, e o Painel acima tem DecoratedBox com cor — sem isto o ripple
      // ficaria invisível (e o framework acusa em modo de depuração).
      Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _criarBaia,
          onChanged: (v) => setState(() => _criarBaia = v),
          title: const Text('Criar baia para este animal', style: TextStyle(fontSize: 13.5)),
          subtitle: const Text(
            'A baia nasce com a rotina padrão de manejo.',
            style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
          ),
        ),
      ),
      if (_criarBaia)
        DropdownButtonFormField<StatusBaia>(
          initialValue: _statusBaia,
          decoration: const InputDecoration(labelText: 'Situação inicial da baia'),
          items: [
            for (final s in StatusBaia.values)
              DropdownMenuItem(value: s, child: Text(s.rotulo)),
          ],
          onChanged: (v) => setState(() => _statusBaia = v ?? _statusBaia),
        ),
      const SizedBox(height: 14),
      const Text(
        'Provas e demais mídias podem ser adicionadas depois, na ficha do animal.',
        style: TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario, height: 1.4),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Passo 5
  // ---------------------------------------------------------------------------

  List<Widget> _passoRevisao() {
    String ou(String valor, String padrao) => valor.trim().isEmpty ? padrao : valor.trim();

    final itens = <(String, String)>[
      ('Nome', ou(_nome.text, '—')),
      ('Registro', ou(_registro.text, '—')),
      ('Sexo', _sexo.rotulo),
      ('Nascimento', _formatarData(_nascimento)),
      ('Pelagem', ou(_pelagem.text, '—')),
      ('Altura', ou(_altura.text, '—')),
      ('Peso', ou(_peso.text, '—')),
      ('Pai', ou(_paiNome.text, 'não informado')),
      ('Mãe', ou(_maeNome.text, 'não informado')),
      ('Proprietário', ou(_propNome.text, 'não informado')),
      ('Fazenda', ou(_propFazenda.text, '—')),
      ('Criador', ou(_criadorNome.text, 'não informado')),
      ('Foto de perfil', _fotoBytes != null ? 'será enviada' : 'imagem padrão'),
      ('Baia', _criarBaia ? 'criada (${_statusBaia.rotulo})' : 'sem baia'),
    ];

    return [
      for (final (rotulo, valor) in itens)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  rotulo,
                  style: const TextStyle(fontSize: 12, color: AdminCores.textoSecundario),
                ),
              ),
              Expanded(
                child: Text(
                  valor,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminCores.azulFundo,
          borderRadius: BorderRadius.circular(AdminRaios.pequeno),
        ),
        child: const Text(
          'Ao concluir, o animal entra no acervo e abre na ficha completa. '
          'Provas, galeria e ocorrências ficam disponíveis lá.',
          style: TextStyle(fontSize: 11.5, color: AdminCores.texto, height: 1.4),
        ),
      ),
    ];
  }
}

/// Remove repetição exata do texto, mantendo o conteúdo real.
///
/// O editor do Flutter Web mantém um `<input>` espelho do campo focado; em
/// automação e em colagem agressiva o texto pode chegar duplicado
/// ("ESTRELA DO VALEESTRELA DO VALE"). Gravar isso criaria um id absurdo e
/// poluiria o acervo.
String _recolherRepeticao(String bruto) {
  final s = bruto.trim();
  if (s.length.isEven) {
    final metade = s.length ~/ 2;
    final a = s.substring(0, metade);
    final b = s.substring(metade);
    if (a == b) return a.trim();
  }
  return s;
}

/// Id estável a partir do nome: minúsculas, sem acento, hífens no lugar do resto.
String _idDoNome(String bruto) {
  final base = _recolherRepeticao(bruto)
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return base;
}

String _formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Trilha de passos no topo: mostra onde o operador está e o que falta.
class _TrilhaPassos extends StatelessWidget {
  const _TrilhaPassos({required this.atual, required this.passos});

  final int atual;
  final List<_Passo> passos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < passos.length; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= atual ? AdminCores.dourado : AdminCores.borda,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    passos[i].rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == atual ? FontWeight.w700 : FontWeight.w400,
                      color: i <= atual ? AdminCores.texto : AdminCores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            if (i != passos.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _BarraAcoes extends StatelessWidget {
  const _BarraAcoes({
    required this.passo,
    required this.total,
    required this.salvando,
    required this.aoVoltar,
    required this.aoAvancar,
    required this.aoSalvar,
  });

  final int passo;
  final int total;
  final bool salvando;
  final VoidCallback aoVoltar;
  final VoidCallback aoAvancar;
  final VoidCallback aoSalvar;

  @override
  Widget build(BuildContext context) {
    final ultimo = passo == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminCores.borda)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Passo ${passo + 1} de $total',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
            ),
          ),
          if (passo > 0)
            OutlinedButton.icon(
              onPressed: salvando ? null : aoVoltar,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Voltar'),
            ),
          const SizedBox(width: 8),
          // Largura fixa: o texto muda entre "Continuar" e "Concluir cadastro",
          // e o botão dançava de posição entre os passos.
          SizedBox(
            width: 128,
            child: FilledButton(
              onPressed: salvando ? null : (ultimo ? aoSalvar : aoAvancar),
              child: salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(ultimo ? 'Concluir' : 'Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotuloSecao extends StatelessWidget {
  const _RotuloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AdminCores.dourado,
      ),
    );
  }
}

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
  const _Campo({
    required this.nome,
    required this.controlador,
    this.linhas = 1,
    this.obrigatorio = false,
  });

  final String nome;
  final TextEditingController controlador;
  final int linhas;
  final bool obrigatorio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      maxLines: linhas,
      decoration: InputDecoration(
        labelText: obrigatorio ? '$nome *' : nome,
      ),
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
        decoration: InputDecoration(
          labelText: rotulo,
          suffixIcon: const Icon(Icons.event, size: 17),
        ),
        child: Text(_formatarData(data), style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}
