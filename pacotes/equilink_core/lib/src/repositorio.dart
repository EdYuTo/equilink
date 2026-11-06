import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analytics/analytics.dart';
import 'analytics/coletor.dart';
import 'fonte_dados.dart';
import 'modelos.dart';

/// Estado de carregamento do acervo.
enum EstadoCarga { inicial, carregando, pronto, erro }

/// Fachada única entre a interface e qualquer fonte de dados.
///
/// As telas leem daqui e nunca falam com a fonte diretamente. Toda escrita
/// atualiza o estado local na hora (resposta imediata) e depois persiste na
/// fonte; se a gravação falhar, [erro] é preenchido e o painel administrativo
/// mostra a mensagem.
class Repositorio extends ChangeNotifier {
  Repositorio(this.fonte, {Analytics? analytics}) : analytics = analytics ?? Analytics(ColetorNulo());

  final FonteDeDados fonte;

  /// Telemetria do aplicativo. Toda escrita relevante gera um evento aqui,
  /// sem que as telas precisem instrumentar nada manualmente.
  final Analytics analytics;

  Acervo _acervo = const Acervo(cavalos: [], baias: []);
  EstadoCarga _estado = EstadoCarga.inicial;
  String? _erro;
  int _sequencia = 0;

  /// Cavalo escolhido por link direto (`/cavalo/:registro`), quando houver.
  ///
  /// O QR Code da placa aponta para o perfil de um animal específico; sem isto o
  /// app sempre abria o destaque do haras e o link levava ao cavalo errado.
  String? _idEmFoco;
  String? _erroFoco;

  /// Data de referência dos cálculos de idade (mantém os testes determinísticos).
  final DateTime hoje = DateTime(2026, 10, 14);

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------

  Acervo get acervo => _acervo;
  EstadoCarga get estado => _estado;
  String? get erro => _erro;
  bool get carregando => _estado == EstadoCarga.carregando;
  bool get pronto => _estado == EstadoCarga.pronto;
  bool get permiteEscrita => fonte.permiteEscrita && _estado == EstadoCarga.pronto;

  List<Cavalo> get cavalos => _acervo.cavalos;
  List<Baia> get baias => _acervo.baias;

  /// Cavalo exibido no aplicativo do usuário.
  ///
  /// Prioriza o animal escolhido por link direto; sem link, o destaque do haras.
  Cavalo? get cavalo {
    final foco = _idEmFoco;
    if (foco != null) {
      final alvo = _acervo.cavaloPorId(foco);
      if (alvo != null) return alvo;
    }
    return _acervo.principal;
  }

  /// Registro pedido pela URL atual, se houver.
  String? get registroEmFoco {
    final foco = _idEmFoco;
    return foco == null ? null : _acervo.cavaloPorId(foco)?.registro;
  }

  /// Mensagem quando o registro da URL não existe no acervo.
  String? get erroFoco => _erroFoco;

  /// Aponta o aplicativo para o animal de um link (`/cavalo/:registro`).
  ///
  /// Devolve `false` quando não há animal com aquele registro; a tela mostra o
  /// motivo em vez de exibir silenciosamente outro cavalo.
  bool focarRegistro(String registro) {
    final alvo = _acervo.cavalos
        .where((c) => c.registro.toLowerCase() == registro.trim().toLowerCase())
        .firstOrNull;
    if (alvo == null) {
      _idEmFoco = null;
      _erroFoco = 'Nenhum animal cadastrado com o registro "$registro".';
      notifyListeners();
      return false;
    }
    _idEmFoco = alvo.id;
    _erroFoco = null;
    notifyListeners();
    return true;
  }

  /// Volta a exibir o destaque do haras.
  void limparFoco() {
    if (_idEmFoco == null && _erroFoco == null) return;
    _idEmFoco = null;
    _erroFoco = null;
    notifyListeners();
  }

  /// Lança se o acervo ainda não foi carregado — usado só onde o dado é
  /// obrigatório (telas do usuário, que só montam após o carregamento).
  Cavalo get cavaloObrigatorio {
    final atual = cavalo;
    if (atual == null) throw StateError('Acervo vazio: nenhum cavalo cadastrado.');
    return atual;
  }

  Future<void> carregar() async {
    _estado = EstadoCarga.carregando;
    _erro = null;
    notifyListeners();
    final inicio = DateTime.now();
    try {
      _acervo = await fonte.carregar();
      _estado = EstadoCarga.pronto;
      analytics.registrar(
        'acervo_carregado',
        propriedades: {
          'fonte': fonte.descricao,
          'cavalos': _acervo.cavalos.length,
          'baias': _acervo.baias.length,
          'duracaoMs': DateTime.now().difference(inicio).inMilliseconds,
        },
      );
    } on ErroFonte catch (e) {
      _erro = e.mensagem;
      _estado = EstadoCarga.erro;
      analytics.erro('carregar_acervo', e.mensagem, propriedades: {'fonte': fonte.descricao});
    } catch (e) {
      _erro = 'Falha inesperada ao carregar os dados: $e';
      _estado = EstadoCarga.erro;
      analytics.erro('carregar_acervo', '$e', propriedades: {'fonte': fonte.descricao});
    }
    notifyListeners();
  }

  /// Aplica uma transformação local e persiste na fonte.
  ///
  /// [evento] descreve o que aconteceu: é registrado somente quando a gravação
  /// é bem-sucedida, para a telemetria refletir o estado real.
  /// Aplica uma transformação local e persiste.
  ///
  /// [gravar] recebe o acervo já transformado e executa apenas a escrita da
  /// entidade afetada. Quando ausente, cai em `fonte.salvar(acervo)` — o que
  /// só é seguro para substituição total.
  Future<bool> _aplicar(
    Acervo Function(Acervo) transformacao, {
    String? evento,
    Map<String, Object?> propriedades = const {},
    num? valor,
    String? entidade,
    String? entidadeId,
    Future<void> Function(Acervo acervo)? gravar,
  }) async {
    if (!permiteEscrita) {
      _erro = 'A fonte de dados atual é somente leitura.';
      notifyListeners();
      analytics.erro('gravacao_recusada', _erro!, propriedades: {'evento': evento ?? '—'});
      return false;
    }
    _acervo = transformacao(_acervo);
    _erro = null;
    notifyListeners();
    try {
      if (gravar != null) {
        await gravar(_acervo);
      } else {
        _acervo = await fonte.salvar(_acervo);
      }
      if (evento != null) {
        analytics.registrar(
          evento,
          propriedades: {...propriedades, 'fonte': fonte.descricao},
          valor: valor,
          entidade: entidade,
          entidadeId: entidadeId,
        );
      }
      notifyListeners();
      return true;
    } on ErroFonte catch (e) {
      _erro = e.mensagem;
      analytics.erro('gravar_acervo', e.mensagem, propriedades: {'evento': evento ?? '—'});
      notifyListeners();
      return false;
    } catch (e) {
      _erro = 'Falha inesperada ao gravar: $e';
      analytics.erro('gravar_acervo', '$e', propriedades: {'evento': evento ?? '—'});
      notifyListeners();
      return false;
    }
  }

  void limparErro() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  /// Troca o acervo inteiro e grava na fonte.
  ///
  /// Usado na migração entre backends: exporta o JSON de uma fonte e importa
  /// na outra.
  Future<bool> substituirAcervo(Acervo novo) => _aplicar(
    (_) => novo,
    evento: 'acervo_substituido',
    propriedades: {'cavalos': novo.cavalos.length, 'baias': novo.baias.length},
  );

  String novoId(String prefixo) => '$prefixo-${++_sequencia}-${DateTime.now().microsecondsSinceEpoch}';

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  Baia? baia(String numero) => _acervo.baia(numero);

  Cavalo? cavaloPorId(String id) => _acervo.cavaloPorId(id);

  String nomeCavalo(String id) =>
      cavaloPorId(id)?.nome ?? 'Baia livre';

  /// Baia cujo animal saiu do acervo (cavalo removido, baia esquecida).
  ///
  /// Antes o app mostrava o cavalo como "Sem identificação" e o painel contava
  /// a baia como ocupada — o operador via 5 baias ocupadas com 5 animais, mas
  /// uma delas não tinha ninguém.
  bool baiaOrfa(String? cavaloId) =>
      cavaloId == null || cavaloId.isEmpty || cavaloPorId(cavaloId) == null;

  /// Registro ABQM do animal, com traço quando não cadastrado.
  String registroCavalo(String id) => cavaloPorId(id)?.registro ?? '—';

  String pelagemCavalo(String id) => cavaloPorId(id)?.pelagem ?? '—';

  /// Foto de perfil do animal, com a imagem de capa como reserva.
  String fotoCavalo(String id) {
    final foto = cavaloPorId(id)?.fotoPerfil;
    if (foto != null && foto.isNotEmpty) return foto;
    return MidiaPadrao.imagem;
  }

  List<Baia> get baiasOrdenadas =>
      [..._acervo.baias]..sort((a, b) => a.numero.compareTo(b.numero));

  int get manejoPendenteTotal => _acervo.baias.fold(0, (t, b) => t + b.pendentes);

  int get tarefasConcluidasTotal =>
      _acervo.baias.fold(0, (t, b) => t + b.manejo.where((m) => m.concluida).length);

  int get ocorrenciasAbertasTotal =>
      _acervo.baias.fold(0, (t, b) => t + b.ocorrencias.where((o) => !o.resolvida).length);

  int get baiasEmManutencao => _acervo.baias.where((b) => b.status == StatusBaia.manutencao).length;

  /// Animais sem baia atribuída.
  List<Cavalo> get cavalosSemBaia {
    final ocupados = _acervo.baias.map((b) => b.cavaloId).toSet();
    return [for (final c in _acervo.cavalos) if (!ocupados.contains(c.id)) c];
  }

  /// Consumo diário estimado de ração e volumoso, para o relatório de gestão.
  List<({String insumo, double quilos, int tarefas})> get consumoDiario {
    final mapa = <String, ({double quilos, int tarefas})>{};
    for (final b in _acervo.baias) {
      for (final t in b.manejo) {
        final insumo = switch (t.tipo) {
          TipoManejo.alimentacao => t.descricao.toLowerCase().contains('feno') ? 'Feno' : 'Ração',
          TipoManejo.saude => 'Suplemento',
          _ => null,
        };
        if (insumo == null) continue;
        final valor = quantidadeParaQuilos(t.quantidade);
        final atual = mapa[insumo] ?? (quilos: 0.0, tarefas: 0);
        mapa[insumo] = (quilos: atual.quilos + valor, tarefas: atual.tarefas + 1);
      }
    }
    return [
      for (final e in mapa.entries)
        (insumo: e.key, quilos: e.value.quilos, tarefas: e.value.tarefas),
    ]..sort((a, b) => b.quilos.compareTo(a.quilos));
  }

  /// Converte rótulos como `1,5 kg`, `30 g` e `40 L` em quilos/litros.
  static double quantidadeParaQuilos(String quantidade) {
    final match = RegExp(r'([\d.,]+)\s*(kg|g|L|ml|min|un\.?)?').firstMatch(quantidade);
    if (match == null) return 0;
    final numero = double.tryParse(match.group(1)!.replaceAll('.', '').replaceAll(',', '.'));
    if (numero == null) return 0;
    return switch (match.group(2)) {
      'g' => numero / 1000,
      'ml' => numero / 1000,
      'kg' || 'L' => numero,
      _ => 0,
    };
  }

  /// Desempenho agrupado por mês (gráfico do histórico esportivo).
  List<({String rotulo, int provas, int vitorias, double melhorTempo})> desempenhoPorMes() {
    final alvo = cavalo;
    if (alvo == null) return const [];
    final mapa = <String, List<Prova>>{};
    for (final p in alvo.provas) {
      mapa.putIfAbsent('${p.data.year}-${p.data.month.toString().padLeft(2, '0')}', () => []).add(p);
    }
    final chaves = mapa.keys.toList()..sort();
    return [
      for (final k in chaves)
        (
          rotulo: _mesAbreviado(int.parse(k.split('-')[1])),
          provas: mapa[k]!.length,
          vitorias: mapa[k]!.where((p) => p.vitoria).length,
          melhorTempo: mapa[k]!.map((p) => p.tempoSegundos).reduce(min),
        ),
    ];
  }

  String _mesAbreviado(int mes) => const [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ][mes - 1];

  /// Distribuição de colocações (1º ao 6º+) para o relatório esportivo.
  Map<String, int> get distribuicaoColocacoes {
    final mapa = <String, int>{};
    for (final p in cavalo?.provas ?? const <Prova>[]) {
      if (!p.temColocacao) continue;
      final chave = p.colocacao <= 5 ? '${p.colocacao}º' : '6º+';
      mapa[chave] = (mapa[chave] ?? 0) + 1;
    }
    return mapa;
  }

  // ---------------------------------------------------------------------------
  // Cavalos
  // ---------------------------------------------------------------------------

  Future<bool> salvarCavalo(Cavalo cavalo) {
    final existe = _acervo.cavalos.any((c) => c.id == cavalo.id);
    return _aplicar(
      (a) => a.copiarCom(
        cavalos: existe
            ? [for (final c in a.cavalos) if (c.id == cavalo.id) cavalo else c]
            : [...a.cavalos, cavalo],
      ),
      evento: existe ? 'cavalo_editado' : 'cavalo_criado',
      entidade: 'cavalo',
      entidadeId: cavalo.id,
      gravar: (_) => fonte.salvarCavalo(cavalo),
      propriedades: {'registro': cavalo.registro, 'provas': cavalo.provas.length},
    );
  }

  Future<bool> removerCavalo(String id) => _aplicar(
    (a) => a.copiarCom(
      cavalos: [for (final c in a.cavalos) if (c.id != id) c],
      // Uma baia não pode ficar apontando para um animal removido.
      baias: [for (final b in a.baias) if (b.cavaloId != id) b],
    ),
    evento: 'cavalo_removido',
    entidade: 'cavalo',
    entidadeId: id,
    gravar: (_) => fonte.removerCavalo(id),
  );

  /// Define qual cavalo aparece no aplicativo do usuário.
  Future<bool> definirPrincipal(String id) => _aplicar(
    (a) => a.copiarCom(
      cavalos: [for (final c in a.cavalos) c.copiarCom(principal: c.id == id)],
    ),
    evento: 'cavalo_destacado',
    entidade: 'cavalo',
    entidadeId: id,
    gravar: (_) => fonte.definirPrincipal(id),
  );

  Future<bool> atualizarDescricao(String id, String texto) => _aplicar(
    (a) => a.copiarCom(
      cavalos: [for (final c in a.cavalos) if (c.id == id) c.copiarCom(descricao: texto) else c],
    ),
    evento: 'descricao_editada',
    entidade: 'cavalo',
    entidadeId: id,
    propriedades: {'caracteres': texto.length},
  );

  // ---------------------------------------------------------------------------
  // Provas
  // ---------------------------------------------------------------------------

  Future<bool> salvarProva(String cavaloId, Prova prova) {
    final existe = _acervo.cavaloPorId(cavaloId)?.provas.any((p) => p.id == prova.id) ?? false;
    return _aplicar(
      (a) {
        final alvo = a.cavaloPorId(cavaloId);
        if (alvo == null) return a;
        return a.copiarCom(
          cavalos: [
            for (final c in a.cavalos)
              if (c.id == cavaloId)
                c.copiarCom(
                  provas: existe
                      ? [for (final p in c.provas) if (p.id == prova.id) prova else p]
                      : [...c.provas, prova],
                )
              else
                c,
          ],
        );
      },
      evento: existe ? 'prova_editada' : 'prova_registrada',
      entidade: 'prova',
      entidadeId: prova.id,
      gravar: (_) => fonte.salvarProva(cavaloId, prova),
      valor: prova.tempoSegundos,
      propriedades: {
        'cavaloId': cavaloId,
        'colocacao': prova.colocacao,
        'nome': prova.nome,
        'categoria': prova.categoria,
        'vitoria': prova.vitoria,
      },
    );
  }

  Future<bool> removerProva(String cavaloId, String provaId) => _aplicar(
    evento: 'prova_removida',
    entidade: 'prova',
    entidadeId: provaId,
    propriedades: {'cavaloId': cavaloId},
    (a) => a.copiarCom(
      cavalos: [
        for (final c in a.cavalos)
          if (c.id == cavaloId)
            c.copiarCom(provas: [for (final p in c.provas) if (p.id != provaId) p])
          else
            c,
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Mídias
  // ---------------------------------------------------------------------------

  /// Envia o arquivo e devolve a URL pública, ou o erro em [ultimoErro].
  ///
  /// Não mexe no acervo: quem chama usa a URL para criar a [Midia] e gravar.
  Future<String?> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async {
    try {
      final url = await fonte.enviarMidia(
        cavaloId,
        bytes: bytes,
        tipoConteudo: tipoConteudo,
        nomeArquivo: nomeArquivo,
      );
      analytics.registrar(
        'midia_enviada',
        entidade: 'midia',
        entidadeId: cavaloId,
        valor: bytes.length,
        propriedades: {'tipoConteudo': tipoConteudo},
      );
      return url;
    } on ErroFonte catch (e) {
      _erro = e.mensagem;
      notifyListeners();
      return null;
    } catch (e) {
      _erro = 'Falha ao enviar a mídia: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> salvarMidia(String cavaloId, Midia midia) {
    final existe = _acervo.cavaloPorId(cavaloId)?.midias.any((m) => m.id == midia.id) ?? false;
    return _aplicar(
      (a) => a.copiarCom(
        cavalos: [
          for (final c in a.cavalos)
            if (c.id == cavaloId)
              c.copiarCom(
                midias: existe
                    ? [for (final m in c.midias) if (m.id == midia.id) midia else m]
                    : [...c.midias, midia],
              )
            else
              c,
        ],
      ),
      evento: existe ? 'midia_editada' : 'midia_adicionada',
      entidade: 'midia',
      entidadeId: midia.id,
      gravar: (_) => fonte.salvarMidia(cavaloId, midia),
      propriedades: {'cavaloId': cavaloId, 'tipo': midia.tipo.name},
    );
  }

  Future<bool> removerMidia(String cavaloId, String midiaId) => _aplicar(
    evento: 'midia_removida',
    entidade: 'midia',
    entidadeId: midiaId,
    propriedades: {'cavaloId': cavaloId},
    (a) => a.copiarCom(
      cavalos: [
        for (final c in a.cavalos)
          if (c.id == cavaloId)
            c.copiarCom(midias: [for (final m in c.midias) if (m.id != midiaId) m])
          else
            c,
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Baias
  // ---------------------------------------------------------------------------

  Future<bool> adicionarBaia({
    required String cavaloId,
    required StatusBaia status,
    String? numero,
    String area = 'Haras principal',
    List<TarefaManejo>? rotinaModelo,
  }) {
    final proximo = numero ?? _proximoNumeroBaia(_acervo.baias);
    final modelo = rotinaModelo ?? rotinaPadrao();
    return _aplicar(
      (a) => a.copiarCom(
        baias: [
          ...a.baias,
          Baia(
            numero: proximo,
            cavaloId: cavaloId,
            status: status,
            ultimaLimpeza: DateTime(hoje.year, hoje.month, hoje.day, 7),
            manejo: [
              for (final t in modelo) t.copiarCom(id: '${t.id}-$proximo', concluida: false),
            ],
            ocorrencias: const [],
            observacoes: const [],
            area: area,
          ),
        ],
      ),
      evento: 'baia_criada',
      entidade: 'baia',
      entidadeId: proximo,
      gravar: (a) {
        final nova = a.baia(proximo);
        return nova == null ? Future<void>.value() : fonte.salvarBaia(nova);
      },
      propriedades: {
        'cavaloId': cavaloId,
        'status': status.name,
        'tarefas': modelo.length,
      },
    );
  }

  static String _proximoNumeroBaia(List<Baia> baias) {
    var maior = 0;
    for (final b in baias) {
      final n = int.tryParse(b.numero);
      if (n != null && n > maior) maior = n;
    }
    return (maior + 1).toString().padLeft(2, '0');
  }

  /// Rotina de manejo padrão, usada como modelo ao criar uma baia.
  List<TarefaManejo> rotinaPadrao() {
    if (_acervo.baias.isNotEmpty && _acervo.baias.first.manejo.isNotEmpty) {
      return _acervo.baias.first.manejo;
    }
    const base = [
      ('rm1', TipoManejo.alimentacao, 'Ração da manhã', '06:00', '1,5 kg', 'Carlos'),
      ('rm2', TipoManejo.alimentacao, 'Feno', '08:00', '2,0 kg', 'Carlos'),
      ('rm3', TipoManejo.alimentacao, 'Ração da tarde', '12:00', '1,5 kg', 'Marina'),
      ('rm4', TipoManejo.agua, 'Troca da água', '14:00', '40 L', 'Marina'),
      ('rm5', TipoManejo.exercicio, 'Exercício na guia', '15:30', '30 min', 'João'),
      ('rm6', TipoManejo.higiene, 'Limpeza da baia', '17:00', '1 un.', 'Carlos'),
      ('rm7', TipoManejo.alimentacao, 'Ração da noite', '18:00', '1,5 kg', 'Marina'),
      ('rm8', TipoManejo.saude, 'Suplemento mineral', '19:00', '30 g', 'João'),
    ];
    return [
      for (final (id, tipo, descricao, horario, quantidade, responsavel) in base)
        TarefaManejo(
          id: id,
          tipo: tipo,
          descricao: descricao,
          horario: horario,
          quantidade: quantidade,
          responsavel: responsavel,
        ),
    ];
  }

  Future<bool> removerBaia(String numero) => _aplicar(
    (a) => a.copiarCom(baias: [for (final b in a.baias) if (b.numero != numero) b]),
    evento: 'baia_removida',
    entidade: 'baia',
    entidadeId: numero,
    gravar: (_) => fonte.removerBaia(numero),
  );

  Future<bool> atualizarBaia(Baia baia, {String? evento}) => _atualizarBaia(
    baia.numero,
    (_) => baia,
    evento: evento ?? 'baia_editada',
    entidade: 'baia',
    entidadeId: baia.numero,
  );

  Future<bool> alterarStatusBaia(String numero, StatusBaia status) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(
      status: status,
      ultimaLimpeza: status == StatusBaia.emDia
          ? DateTime(hoje.year, hoje.month, hoje.day, 7, 10)
          : b.ultimaLimpeza,
    ),
    evento: 'baia_status_alterado',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'status': status.name},
  );

  /// Marca/desmarca uma tarefa de manejo. Devolve o novo estado da tarefa.
  Future<bool> alternarManejo(String numero, String tarefaId) async {
    // Os valores do evento precisam ser lidos ANTES da transformação: os
    // argumentos de _atualizarBaia são avaliados antes do closure rodar, então
    // construir a propriedades lá dentro reportaria estado obsoleto.
    final baiaAtual = _acervo.baia(numero);
    final tarefa = baiaAtual?.manejo.where((t) => t.id == tarefaId).firstOrNull;
    if (baiaAtual == null || tarefa == null) return false;

    final novo = !tarefa.concluida;
    final rotinaCompleta = baiaAtual.manejo
        .every((t) => t.id == tarefaId ? novo : t.concluida);

    await _atualizarBaia(
      numero,
      (b) {
        final manejo = [
          for (final t in b.manejo)
            if (t.id == tarefaId) t.copiarCom(concluida: novo) else t,
        ];
        return b.copiarCom(
          manejo: manejo,
          ultimaLimpeza: rotinaCompleta
              ? DateTime(hoje.year, hoje.month, hoje.day, 17, 5)
              : b.ultimaLimpeza,
        );
      },
      evento: 'manejo_alternado',
      entidade: 'baia',
      entidadeId: numero,
      propriedades: {
        'tarefaId': tarefaId,
        'tarefa': tarefa.descricao,
        'tipo': tarefa.tipo.name,
        'concluida': novo,
        'rotinaCompleta': rotinaCompleta,
      },
    );
    return novo;
  }

  Future<bool> atualizarHorarioManejo(String numero, String tarefaId, String horario) =>
      _atualizarBaia(
        numero,
        (b) => b.copiarCom(
          manejo: [
            for (final t in b.manejo)
              if (t.id == tarefaId) t.copiarCom(horario: horario) else t,
          ],
        ),
        evento: 'manejo_horario_alterado',
        entidade: 'baia',
        entidadeId: numero,
        propriedades: {'tarefaId': tarefaId, 'horario': horario},
      );

  Future<bool> adicionarTarefa(
    String numero, {
    required TipoManejo tipo,
    required String descricao,
    required String horario,
    required String quantidade,
    String responsavel = '',
  }) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(
      manejo: [
        ...b.manejo,
        TarefaManejo(
          id: novoId('rm'),
          tipo: tipo,
          descricao: descricao,
          horario: horario,
          quantidade: quantidade,
          responsavel: responsavel,
        ),
      ],
    ),
    evento: 'manejo_tarefa_adicionada',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'tipo': tipo.name, 'descricao': descricao, 'horario': horario},
  );

  Future<bool> removerTarefa(String numero, String tarefaId) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(manejo: [for (final t in b.manejo) if (t.id != tarefaId) t]),
    evento: 'manejo_tarefa_removida',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'tarefaId': tarefaId},
  );

  Future<bool> adicionarOcorrencia(
    String numero, {
    required TipoOcorrencia tipo,
    required String descricao,
    required String responsavel,
    DateTime? data,
  }) => _atualizarBaia(
    numero,
    (b) {
      final nova = Ocorrencia(
        id: novoId('oc'),
        data: data ?? DateTime.now(),
        tipo: tipo,
        descricao: descricao,
        responsavel: responsavel,
        resolvida: false,
      );
      return b.copiarCom(
        ocorrencias: [nova, ...b.ocorrencias],
        status: tipo == TipoOcorrencia.estrutura ? StatusBaia.manutencao : b.status,
      );
    },
    evento: 'ocorrencia_registrada',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {
      'tipo': tipo.name,
      'responsavel': responsavel,
      'baiaEmManutencao': tipo == TipoOcorrencia.estrutura,
    },
  );

  Future<bool> alternarOcorrenciaResolvida(String numero, String ocorrenciaId) =>
      _atualizarBaia(
        numero,
        (b) {
          final lista = [
            for (final o in b.ocorrencias)
              if (o.id == ocorrenciaId) o.copiarCom(resolvida: !o.resolvida) else o,
          ];
          final pendentes = lista.where((o) => !o.resolvida).length;
          return b.copiarCom(
            ocorrencias: lista,
            status: pendentes == 0 && b.status == StatusBaia.manutencao
                ? StatusBaia.emDia
                : b.status,
          );
        },
        evento: 'ocorrencia_resolvida',
        entidade: 'baia',
        entidadeId: numero,
        propriedades: {'ocorrenciaId': ocorrenciaId},
      );

  Future<bool> removerOcorrencia(String numero, String ocorrenciaId) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(
      ocorrencias: [for (final o in b.ocorrencias) if (o.id != ocorrenciaId) o],
    ),
    evento: 'ocorrencia_removida',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'ocorrenciaId': ocorrenciaId},
  );

  Future<bool> adicionarObservacao(
    String numero, {
    required String autor,
    required String texto,
    DateTime? data,
  }) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(
      observacoes: [
        Observacao(id: novoId('ob'), data: data ?? DateTime.now(), autor: autor, texto: texto),
        ...b.observacoes,
      ],
    ),
    evento: 'observacao_adicionada',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'autor': autor, 'caracteres': texto.length},
  );

  Future<bool> removerObservacao(String numero, String observacaoId) => _atualizarBaia(
    numero,
    (b) => b.copiarCom(
      observacoes: [for (final o in b.observacoes) if (o.id != observacaoId) o],
    ),
    evento: 'observacao_removida',
    entidade: 'baia',
    entidadeId: numero,
    propriedades: {'observacaoId': observacaoId},
  );

  Future<bool> _atualizarBaia(
    String numero,
    Baia Function(Baia) transformacao, {
    String? evento,
    String? entidade,
    String? entidadeId,
    Map<String, Object?> propriedades = const {},
  }) => _aplicar(
    (a) {
      if (!a.baias.any((b) => b.numero == numero)) return a;
      return a.copiarCom(
        baias: [for (final b in a.baias) if (b.numero == numero) transformacao(b) else b],
      );
    },
    evento: evento,
    entidade: entidade,
    entidadeId: entidadeId,
    propriedades: propriedades,
    gravar: (a) {
      final atualizada = a.baia(numero);
      return atualizada == null ? Future<void>.value() : fonte.salvarBaia(atualizada);
    },
  );
}
