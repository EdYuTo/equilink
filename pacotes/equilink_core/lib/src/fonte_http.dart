import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fonte_dados.dart';
import 'modelos.dart';

/// Fonte de dados servida por uma API REST.
///
/// Contrato esperado do backend:
///
/// | Método | Rota                    | Corpo              |
/// |--------|-------------------------|--------------------|
/// | GET    | `/acervo`               | —                  |
/// | PUT    | `/acervo`               | `Acervo` (total)   |
/// | PUT    | `/cavalos/:id`          | `Cavalo`           |
/// | DELETE | `/cavalos/:id`          | —                  |
/// | PUT    | `/baias/:numero`        | `Baia`             |
/// | DELETE | `/baias/:numero`        | —                  |
///
/// O cabeçalho `Authorization` é enviado quando [cabecalhos] traz um token.
/// A gravação é por entidade para que dois operadores editando registros
/// diferentes não se sobrescrevam.
///
/// Sessão: com [usarCookies], o navegador envia o cookie `HttpOnly` emitido por
/// `POST /sessao`. O token de sessão nunca passa por Dart — um XSS não consegue
/// lê-lo, só o próprio navegador o apresenta.
///
/// Respostas `401` viram [ErroAutenticacao] para a interface pedir login, e
/// `403` viram [ErroPermissao] para explicar que o papel não permite.
class FonteHttp implements FonteDeDados {
  FonteHttp({
    required this.base,
    this.cabecalhos = const {},
    this.usarCookies = true,
    this.tempoLimite = const Duration(seconds: 20),
    http.Client? cliente,
  }) : _cliente = cliente ?? http.Client();

  /// Raiz da API, sem barra final (ex.: `https://api.haras.app`).
  final String base;
  final Map<String, String> cabecalhos;

  /// Envia e aceita o cookie de sessão do navegador.
  ///
  /// No web quem controla o cookie é o próprio navegador; fora dele, o padrão
  /// `http.Client` ignora cookies, então a sessão por cookie é um recurso da
  /// versão web — no Android/iOS o mesmo backend deve ser acessado com o token
  /// de serviço em [cabecalhos].
  final bool usarCookies;

  final Duration tempoLimite;
  final http.Client _cliente;

  @override
  String get descricao => 'API REST ($base)';

  @override
  bool get permiteEscrita => true;

  Uri get _endpoint => Uri.parse('$base/acervo');

  Map<String, String> get _cabecalhosPadrao => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    ...cabecalhos,
  };

  /// Traduz o status HTTP em erro de domínio, para a interface reagir.
  ///
  /// Quando a API explica a recusa no campo `erro` do corpo (ex.: "A prova X
  /// pertence a outro cavalo."), é esse o texto que chega ao operador. A
  /// mensagem genérica, com método e status, fica para respostas sem
  /// explicação legível.
  Never _recusar(http.Response resposta, String acao) {
    final status = resposta.statusCode;
    final daApi = _mensagemDaApi(resposta);
    if (status == 401) {
      throw ErroAutenticacao(daApi ?? 'Sessão expirada ou não iniciada.', status: status);
    }
    if (status == 403) {
      throw ErroPermissao(daApi ?? 'Seu perfil não permite $acao.', status: status);
    }
    throw ErroFonte(daApi ?? 'A API recusou $acao ($status).', status: status);
  }

  /// O campo `erro` de uma resposta JSON da API, se houver um texto nele.
  static String? _mensagemDaApi(http.Response resposta) {
    try {
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      final erro = corpo is Map ? corpo['erro'] : null;
      if (erro is String && erro.trim().isNotEmpty) return erro.trim();
    } on FormatException {
      // Corpo vazio, HTML de proxy ou bytes inválidos: fica a mensagem genérica.
    }
    return null;
  }

  @override
  Future<Acervo> carregar() async {
    try {
      final resposta = await _cliente.get(_endpoint, headers: _cabecalhosPadrao).timeout(tempoLimite);
      if (resposta.statusCode != 200) {
        _recusar(resposta, 'carregar o acervo');
      }
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      return Acervo.fromJson(corpo);
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Não foi possível carregar o acervo da API.', causa: erro);
    }
  }

  @override
  Future<Acervo> salvar(Acervo acervo) async {
    try {
      final resposta = await _cliente
          .put(_endpoint, headers: _cabecalhosPadrao, body: jsonEncode(acervo.toJson()))
          .timeout(tempoLimite);
      if (resposta.statusCode != 200 && resposta.statusCode != 201) {
        throw ErroFonte(
          _mensagemDaApi(resposta) ?? 'A API recusou a gravação (${resposta.statusCode}).',
          status: resposta.statusCode,
        );
      }
      if (resposta.bodyBytes.isEmpty) return acervo.copiarCom(versao: acervo.versao + 1);
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      return Acervo.fromJson(corpo);
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Não foi possível gravar o acervo na API.', causa: erro);
    }
  }

  // ---------------------------------------------------------------------------
  // Gravação por entidade
  // ---------------------------------------------------------------------------

  Uri _rota(String caminho) => Uri.parse('$base$caminho');

  Future<void> _enviarCorpo(String metodo, String caminho, Map<String, dynamic> corpo) async {
    try {
      final uri = _rota(caminho);
      final resposta = metodo == 'PUT'
          ? await _cliente.put(uri, headers: _cabecalhosPadrao, body: jsonEncode(corpo)).timeout(tempoLimite)
          : await _cliente.post(uri, headers: _cabecalhosPadrao, body: jsonEncode(corpo)).timeout(tempoLimite);
      if (resposta.statusCode >= 400) {
        _recusar(resposta, '$metodo $caminho');
      }
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Falha ao gravar $caminho.', causa: erro);
    }
  }

  Future<void> _remover(String caminho) async {
    try {
      final resposta = await _cliente.delete(_rota(caminho), headers: _cabecalhosPadrao).timeout(tempoLimite);
      if (resposta.statusCode >= 400 && resposta.statusCode != 404) {
        _recusar(resposta, 'remover $caminho');
      }
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Falha ao remover $caminho.', causa: erro);
    }
  }

  @override
  Future<void> salvarCavalo(Cavalo cavalo) =>
      _enviarCorpo('PUT', '/cavalos/${Uri.encodeComponent(cavalo.id)}', cavalo.toJson());

  @override
  Future<void> removerCavalo(String id) => _remover('/cavalos/${Uri.encodeComponent(id)}');

  @override
  Future<void> salvarBaia(Baia baia) =>
      _enviarCorpo('PUT', '/baias/${Uri.encodeComponent(baia.numero)}', baia.toJson());

  @override
  Future<void> removerBaia(String numero) => _remover('/baias/${Uri.encodeComponent(numero)}');

  @override
  Future<void> salvarProva(String cavaloId, Prova prova) => _enviarCorpo(
    'PUT',
    '/cavalos/${Uri.encodeComponent(cavaloId)}/provas/${Uri.encodeComponent(prova.id)}',
    prova.toJson(),
  );

  @override
  Future<void> removerProva(String cavaloId, String provaId) => _remover(
    '/cavalos/${Uri.encodeComponent(cavaloId)}/provas/${Uri.encodeComponent(provaId)}',
  );

  @override
  Future<void> removerMidia(String cavaloId, String midiaId) => _remover(
    '/cavalos/${Uri.encodeComponent(cavaloId)}/midias/${Uri.encodeComponent(midiaId)}',
  );

  /// Tamanho máximo de um lote de provas aceito pela API.
  static const loteProvas = 500;

  @override
  Future<void> salvarProvas(String cavaloId, List<Prova> provas) async {
    final caminho = '/cavalos/${Uri.encodeComponent(cavaloId)}/provas';
    for (var i = 0; i < provas.length; i += loteProvas) {
      final fim = i + loteProvas < provas.length ? i + loteProvas : provas.length;
      await _enviarCorpo('POST', caminho, {
        'provas': [for (final p in provas.sublist(i, fim)) p.toJson()],
      });
    }
  }

  @override
  Future<ResultadoSgp> buscarProvasSgp(String cavaloId) async {
    try {
      final resposta = await _cliente
          .get(_rota('/cavalos/${Uri.encodeComponent(cavaloId)}/provas/sgp'), headers: _cabecalhosPadrao)
          .timeout(tempoLimite);
      if (resposta.statusCode == 401 || resposta.statusCode == 403) {
        _recusar(resposta, 'importar do SGP');
      }
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (resposta.statusCode != 200) {
        final mensagem = corpo is Map && corpo['erro'] is String ? corpo['erro'] as String : null;
        throw ErroFonte(
          mensagem ?? 'A API recusou a consulta ao SGP (${resposta.statusCode}).',
          status: resposta.statusCode,
        );
      }
      return ResultadoSgp.fromJson(corpo as Map<String, dynamic>);
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Não foi possível consultar o SGP.', causa: erro);
    }
  }

  @override
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async {
    try {
      final resposta = await _cliente
          .post(
            _rota('/cavalos/${Uri.encodeComponent(cavaloId)}/midias'),
            headers: {
              ..._cabecalhosPadrao,
              'Content-Type': tipoConteudo,
              'X-Nome-Arquivo': Uri.encodeComponent(nomeArquivo),
            },
            body: bytes,
          )
          .timeout(tempoLimite);

      if (resposta.statusCode != 201) {
        if (resposta.statusCode >= 400) _recusar(resposta, 'enviar a mídia');
        throw ErroFonte(
          'A API respondeu ${resposta.statusCode} ao enviar a mídia.',
          status: resposta.statusCode,
        );
      }

      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      final arquivo = corpo['arquivo'];
      if (arquivo is! String || arquivo.isEmpty) {
        throw const ErroFonte('A API não devolveu a URL da mídia enviada.');
      }
      return arquivo;
    } on ErroFonte {
      rethrow;
    } catch (erro) {
      throw ErroFonte('Não foi possível enviar a mídia.', causa: erro);
    }
  }

  @override
  Future<void> salvarMidia(String cavaloId, Midia midia) => _enviarCorpo(
    'PUT',
    '/cavalos/${Uri.encodeComponent(cavaloId)}/midias/${Uri.encodeComponent(midia.id)}',
    midia.toJson(),
  );

  @override
  Future<void> definirPrincipal(String id) => _enviarCorpo(
    'POST',
    '/cavalos/${Uri.encodeComponent(id)}/principal',
    const {},
  );

  void encerrar() => _cliente.close();
}
