import 'dart:convert';

import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

FonteHttp _fonte(int status, Object? corpo) => FonteHttp(
  base: 'https://api.exemplo',
  cliente: MockClient(
    (_) async => http.Response(
      corpo is String ? corpo : jsonEncode(corpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

Matcher _erro<T extends ErroFonte>(String mensagem, int status) => throwsA(
  isA<T>()
      .having((e) => e.mensagem, 'mensagem', mensagem)
      .having((e) => e.status, 'status', status),
);

final _prova = Prova(
  id: 'p1',
  data: DateTime(2026, 1, 1),
  nome: 'Três Tambores',
  local: '',
  categoria: 'Aberta',
  colocacao: 2,
  tempoSegundos: 17,
  inscritos: 0,
);

/// EQL-012: a mensagem que a API devolve em `erro` chega à interface, em vez
/// do texto genérico com o status.
void main() {
  group('recusa da API', () {
    test('gravação recusada mostra o erro da API', () async {
      final fonte = _fonte(409, {'erro': 'A prova p1 pertence a outro cavalo.'});
      await expectLater(
        fonte.salvarProva('c1', _prova),
        _erro<ErroFonte>('A prova p1 pertence a outro cavalo.', 409),
      );
    });

    test('remoção recusada mostra o erro da API', () async {
      final fonte = _fonte(409, {'erro': 'Cavalo com provas vinculadas.'});
      await expectLater(fonte.removerCavalo('c1'), _erro<ErroFonte>('Cavalo com provas vinculadas.', 409));
    });

    test('403 continua ErroPermissao, com o texto da API', () async {
      final fonte = _fonte(403, {'erro': 'Seu papel é somente leitura.'});
      await expectLater(
        fonte.salvarCavalo(FonteMemoria.acervoDeDemonstracao().cavalos.first),
        _erro<ErroPermissao>('Seu papel é somente leitura.', 403),
      );
    });

    test('401 continua ErroAutenticacao, com o texto da API', () async {
      final fonte = _fonte(401, {'erro': 'Sessão expirada.'});
      await expectLater(fonte.removerProva('c1', 'p1'), _erro<ErroAutenticacao>('Sessão expirada.', 401));
    });

    test('envio de mídia recusado mostra o erro da API', () async {
      final fonte = _fonte(413, {'erro': 'Arquivo acima de 50 MB.'});
      await expectLater(
        fonte.enviarMidia('c1', bytes: const [1, 2, 3], tipoConteudo: 'image/png', nomeArquivo: 'a.png'),
        _erro<ErroFonte>('Arquivo acima de 50 MB.', 413),
      );
    });

    test('sem erro legível no corpo, mantém o texto genérico', () async {
      await expectLater(
        _fonte(500, '<html>falha</html>').salvarProva('c1', _prova),
        _erro<ErroFonte>('A API recusou PUT /cavalos/c1/provas/p1 (500).', 500),
      );
      await expectLater(
        _fonte(403, {'outro': 1}).removerCavalo('c1'),
        _erro<ErroPermissao>('Seu perfil não permite remover /cavalos/c1.', 403),
      );
    });
  });
}
