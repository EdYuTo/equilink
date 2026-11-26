import 'dart:convert';

import 'modelos.dart';

/// Fotografia completa dos dados do haras.
///
/// É a unidade de leitura e escrita: qualquer fonte de dados devolve e recebe
/// este agregado, então trocar memória por banco de dados não muda a interface
/// das telas.
class Acervo {
  const Acervo({required this.cavalos, required this.baias, this.versao = 1});

  final List<Cavalo> cavalos;
  final List<Baia> baias;

  /// Incrementada a cada gravação; permite detectar conflitos no backend.
  final int versao;

  /// Cavalo em destaque, usado pelo aplicativo do usuário.
  Cavalo? get principal {
    if (cavalos.isEmpty) return null;
    for (final c in cavalos) {
      if (c.principal) return c;
    }
    return cavalos.first;
  }

  Cavalo? cavaloPorId(String id) {
    for (final c in cavalos) {
      if (c.id == id) return c;
    }
    return null;
  }

  Baia? baia(String numero) {
    for (final b in baias) {
      if (b.numero == numero) return b;
    }
    return null;
  }

  Acervo copiarCom({List<Cavalo>? cavalos, List<Baia>? baias, int? versao}) => Acervo(
    cavalos: cavalos ?? this.cavalos,
    baias: baias ?? this.baias,
    versao: versao ?? this.versao,
  );

  factory Acervo.fromJson(Map<String, dynamic> j) => Acervo(
    cavalos: [
      for (final c in (j['cavalos'] as List? ?? const []))
        Cavalo.fromJson(c as Map<String, dynamic>),
    ],
    baias: [
      for (final b in (j['baias'] as List? ?? const []))
        Baia.fromJson(b as Map<String, dynamic>),
    ],
    versao: (j['versao'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'versao': versao,
    'cavalos': [for (final c in cavalos) c.toJson()],
    'baias': [for (final b in baias) b.toJson()],
  };
}

/// Erro de comunicação com a fonte de dados, já com mensagem em português.
class ErroFonte implements Exception {
  const ErroFonte(this.mensagem, {this.causa, this.status});

  final String mensagem;
  final Object? causa;
  final int? status;

  @override
  String toString() => mensagem;
}

/// A API exige sessão: a interface deve pedir login.
class ErroAutenticacao extends ErroFonte {
  const ErroAutenticacao(super.mensagem, {super.status = 401, super.causa});
}

/// A sessão existe, mas o papel do usuário não permite a operação.
class ErroPermissao extends ErroFonte {
  const ErroPermissao(super.mensagem, {super.status = 403, super.causa});
}

/// Contrato de qualquer origem de dados do aplicativo.
///
/// Implementações previstas:
/// - `FonteMemoria`  — dados de demonstração em memória (padrão hoje).
/// - `FonteHttp`     — API REST (`/acervo`, `PUT /acervo`).
/// - `FonteAsset`    — JSON empacotado no aplicativo, somente leitura.
///
/// Para plugar um backend novo, basta implementar estes quatro métodos e
/// apontar `--dart-define=EQUILINK_FONTE=http`.
abstract interface class FonteDeDados {
  /// Nome curto exibido no painel administrativo (ex.: `memória`, `http`).
  String get descricao;

  /// Indica se a fonte aceita alterações. Fontes somente leitura fazem o
  /// painel administrativo operar em modo de visualização.
  bool get permiteEscrita;

  /// Lê o acervo completo. Deve lançar [ErroFonte] em caso de falha.
  Future<Acervo> carregar();

  /// Persiste o acervo completo e devolve o estado efetivamente gravado
  /// (o backend pode normalizar identificadores e incrementar a versão).
  ///
  /// Usado como fallback e para substituição total. **Não** é o caminho das
  /// gravações do dia a dia: duas pessoas editando ao mesmo tempo se
  /// sobrescreveriam. Prefira os métodos por entidade abaixo.
  Future<Acervo> salvar(Acervo acervo);

  // ---------------------------------------------------------------------------
  // Gravação por entidade
  //
  // Cada operação toca apenas o registro afetado, então dois operadores
  // editando animais diferentes não se atropelam. Implementações em memória
  // podem herdar o comportamento simples via [gravacaoGranular].
  // ---------------------------------------------------------------------------

  /// Insere ou atualiza um cavalo (com suas provas e mídias aninhadas).
  Future<void> salvarCavalo(Cavalo cavalo);

  /// Remove um cavalo e, em cascata, suas provas e mídias.
  Future<void> removerCavalo(String id);

  /// Insere ou atualiza uma baia.
  Future<void> salvarBaia(Baia baia);

  /// Remove uma baia e, em cascata, manejo, ocorrências e observações.
  Future<void> removerBaia(String numero);

  /// Insere ou atualiza uma prova de um cavalo.
  Future<void> salvarProva(String cavaloId, Prova prova);

  /// Remove uma prova de um cavalo.
  Future<void> removerProva(String cavaloId, String provaId);

  /// Remove uma mídia de um cavalo.
  Future<void> removerMidia(String cavaloId, String midiaId);

  /// Insere ou atualiza várias provas de um cavalo de uma vez (importação).
  Future<void> salvarProvas(String cavaloId, List<Prova> provas);

  /// Lê no SGP as passadas do cavalo, sem gravar. Só o servidor consulta o SGP.
  Future<ResultadoSgp> buscarProvasSgp(String cavaloId);

  /// Insere ou atualiza uma mídia de um cavalo.
  Future<void> salvarMidia(String cavaloId, Midia midia);

  /// Envia um arquivo e devolve a URL pública para usar em [Midia.arquivo].
  ///
  /// O envio é separado da gravação: primeiro o arquivo chega ao armazenamento,
  /// depois a mídia é gravada com a URL. Assim um arquivo órfão não deixa
  /// registro apontando para nada.
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  });

  /// Define qual cavalo aparece no aplicativo do usuário.
  Future<void> definirPrincipal(String id);
}

/// Prévia da importação do SGP: as passadas que o site lista para o cavalo.
class ResultadoSgp {
  const ResultadoSgp({required this.encontrado, this.motivo, this.url, this.provas = const []});

  /// Falso quando nenhum cavalo do SGP tem o mesmo nome e registro.
  final bool encontrado;
  final String? motivo;

  /// Página pública do cavalo no SGP, para conferir.
  final String? url;
  final List<Prova> provas;

  factory ResultadoSgp.fromJson(Map<String, dynamic> j) => ResultadoSgp(
    encontrado: j['encontrado'] == true,
    motivo: j['motivo'] as String?,
    url: j['url'] as String?,
    provas: [
      for (final p in (j['provas'] as List?) ?? const []) Prova.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// Comportamento padrão para fontes sem gravação granular.
///
/// Aplica a mudança sobre o acervo em memória e delega para [salvar]. Serve
/// para `FonteMemoria` e para qualquer fonte de teste; uma fonte real (SQL,
/// API por recurso) deve sobrescrever os métodos.
mixin GravacaoGranular implements FonteDeDados {
  /// Acervo atualmente conhecido pela fonte.
  Acervo get acervoAtual;

  /// Substitui o acervo conhecido após gravação.
  set acervoAtual(Acervo valor);

  @override
  Future<void> salvarCavalo(Cavalo cavalo) async {
    final atual = acervoAtual;
    final existe = atual.cavalos.any((c) => c.id == cavalo.id);
    acervoAtual = await salvar(
      atual.copiarCom(
        cavalos: existe
            ? [for (final c in atual.cavalos) if (c.id == cavalo.id) cavalo else c]
            : [...atual.cavalos, cavalo],
      ),
    );
  }

  @override
  Future<void> removerCavalo(String id) async {
    final atual = acervoAtual;
    acervoAtual = await salvar(
      atual.copiarCom(
        cavalos: [for (final c in atual.cavalos) if (c.id != id) c],
        baias: [for (final b in atual.baias) if (b.cavaloId != id) b],
      ),
    );
  }

  @override
  Future<void> salvarBaia(Baia baia) async {
    final atual = acervoAtual;
    final existe = atual.baias.any((b) => b.numero == baia.numero);
    acervoAtual = await salvar(
      atual.copiarCom(
        baias: existe
            ? [for (final b in atual.baias) if (b.numero == baia.numero) baia else b]
            : [...atual.baias, baia],
      ),
    );
  }

  @override
  Future<void> removerBaia(String numero) async {
    final atual = acervoAtual;
    acervoAtual = await salvar(
      atual.copiarCom(baias: [for (final b in atual.baias) if (b.numero != numero) b]),
    );
  }

  @override
  Future<void> salvarProva(String cavaloId, Prova prova) async {
    final atual = acervoAtual;
    final alvo = atual.cavaloPorId(cavaloId);
    if (alvo == null) {
      throw ErroFonte('Cavalo $cavaloId não encontrado para gravar a prova.');
    }
    final existe = alvo.provas.any((p) => p.id == prova.id);
    await salvarCavalo(
      alvo.copiarCom(
        provas: existe
            ? [for (final p in alvo.provas) if (p.id == prova.id) prova else p]
            : [...alvo.provas, prova],
      ),
    );
  }

  @override
  Future<void> salvarProvas(String cavaloId, List<Prova> provas) async {
    final atual = acervoAtual;
    final alvo = atual.cavaloPorId(cavaloId);
    if (alvo == null) {
      throw ErroFonte('Cavalo $cavaloId não encontrado para gravar as provas.');
    }
    final porId = {for (final p in provas) p.id: p};
    await salvarCavalo(
      alvo.copiarCom(provas: [for (final p in alvo.provas) porId.remove(p.id) ?? p, ...porId.values]),
    );
  }

  @override
  Future<void> removerProva(String cavaloId, String provaId) async {
    final alvo = acervoAtual.cavaloPorId(cavaloId);
    if (alvo == null) return;
    await salvarCavalo(alvo.copiarCom(provas: [for (final p in alvo.provas) if (p.id != provaId) p]));
  }

  @override
  Future<void> removerMidia(String cavaloId, String midiaId) async {
    final alvo = acervoAtual.cavaloPorId(cavaloId);
    if (alvo == null) return;
    await salvarCavalo(alvo.copiarCom(midias: [for (final m in alvo.midias) if (m.id != midiaId) m]));
  }

  @override
  Future<ResultadoSgp> buscarProvasSgp(String cavaloId) async =>
      throw const ErroFonte('A importação do SGP precisa do servidor: abra o painel publicado.');

  @override
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async {
    // Fonte em memória não tem armazenamento: incorpora o arquivo como data URI.
    // Serve para demonstração e testes; em produção a FonteHttp faz o upload.
    final base64 = base64Encode(bytes);
    return 'data:$tipoConteudo;base64,$base64';
  }

  @override
  Future<void> salvarMidia(String cavaloId, Midia midia) async {
    final atual = acervoAtual;
    final alvo = atual.cavaloPorId(cavaloId);
    if (alvo == null) {
      throw ErroFonte('Cavalo $cavaloId não encontrado para gravar a mídia.');
    }
    final existe = alvo.midias.any((m) => m.id == midia.id);
    await salvarCavalo(
      alvo.copiarCom(
        midias: existe
            ? [for (final m in alvo.midias) if (m.id == midia.id) midia else m]
            : [...alvo.midias, midia],
      ),
    );
  }

  @override
  Future<void> definirPrincipal(String id) async {
    final atual = acervoAtual;
    await salvar(
      atual.copiarCom(
        cavalos: [for (final c in atual.cavalos) c.copiarCom(principal: c.id == id)],
      ),
    );
  }
}
