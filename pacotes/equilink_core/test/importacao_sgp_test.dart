import 'dart:convert';

import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Prova _prova(String id, DateTime data, double tempo, {int colocacao = 5, String? fonte}) => Prova(
  id: id,
  data: data,
  nome: 'Prova $id',
  local: '',
  categoria: 'Três Tambores - Aberta',
  colocacao: colocacao,
  tempoSegundos: tempo,
  inscritos: 0,
  fonte: fonte,
);

Cavalo _comProvas(Cavalo base, List<Prova> provas) => base.copiarCom(provas: provas);

void main() {
  group('passada sem tempo (SAT no SGP)', () {
    late Cavalo cavalo;

    setUp(() {
      final base = FonteMemoria.acervoDeDemonstracao().cavalos.first;
      cavalo = _comProvas(base, [
        _prova('a', DateTime(2026, 3, 1), 17.0),
        _prova('b', DateTime(2026, 3, 2), 0, colocacao: 0),
        _prova('c', DateTime(2026, 3, 3), 18.0),
      ]);
    });

    test('não vira melhor tempo nem entra na média', () {
      expect(cavalo.provas[1].temTempo, isFalse);
      expect(cavalo.melhorTempo, 17.0);
      expect(cavalo.tempoMedio, 17.5);
      expect(cavalo.tempoMedioRecente, 17.5);
    });

    test('cavalo só com passadas sem tempo não tem melhor tempo', () {
      final semTempo = _comProvas(cavalo, [_prova('x', DateTime(2026, 1, 1), 0, colocacao: 0)]);
      expect(semTempo.melhorTempo, isNull);
      expect(semTempo.tempoMedio, isNull);
      expect(semTempo.tempoMedioRecente, isNull);
    });

    test('tempo zero aparece como travessão', () {
      expect(tempoProvaCompacto(0), '—');
      expect(tempoProvaCompacto(16.742), '16,742s');
    });
  });

  group('desempenho por mês', () {
    test('ignora meses sem tempo e mostra no máximo os 12 mais recentes', () async {
      final fonte = FonteMemoria();
      final repo = Repositorio(fonte);
      await repo.carregar();
      final alvo = repo.cavalo!;
      final provas = [
        for (var m = 1; m <= 24; m++) _prova('t$m', DateTime(2024 + (m - 1) ~/ 12, (m - 1) % 12 + 1, 5), 17 + m / 100),
        _prova('sat', DateTime(2026, 6, 5), 0, colocacao: 0),
      ];
      await repo.salvarCavalo(_comProvas(alvo, provas));

      final mensal = repo.desempenhoPorMes();
      expect(mensal, hasLength(12));
      expect(mensal.first.melhorTempo, closeTo(17.13, 1e-9), reason: 'começa em jan/2025');
      expect(mensal.last.melhorTempo, closeTo(17.24, 1e-9));
      expect(mensal.every((m) => m.melhorTempo > 0), isTrue);
    });
  });

  group('importação do SGP', () {
    test('a resposta do servidor vira prévia com as provas', () {
      final r = ResultadoSgp.fromJson({
        'encontrado': true,
        'url': 'https://www.sgpsistema.com/?page=horse_profile&id=1',
        'provas': [
          _prova('sgp-1-2-3', DateTime(2026, 10, 18), 16.511, fonte: 'SGP').toJson(),
        ],
      });
      expect(r.encontrado, isTrue);
      expect(r.provas.single.fonte, 'SGP');
      expect(r.provas.single.tempoSegundos, 16.511);

      final nada = ResultadoSgp.fromJson({'encontrado': false, 'motivo': 'Nenhum cavalo'});
      expect(nada.encontrado, isFalse);
      expect(nada.motivo, 'Nenhum cavalo');
      expect(nada.provas, isEmpty);
    });

    test('a fonte HTTP lê a prévia e grava em lotes de até 500', () async {
      final pedidos = <http.Request>[];
      final cliente = MockClient((pedido) async {
        pedidos.add(pedido);
        if (pedido.method == 'GET') {
          return http.Response(
            jsonEncode({'encontrado': true, 'url': 'u', 'provas': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final n = (jsonDecode(pedido.body)['provas'] as List).length;
        return http.Response(jsonEncode({'ok': true, 'gravadas': n, 'ignoradas': 0}), 200);
      });
      final fonte = FonteHttp(base: 'https://api.exemplo', cliente: cliente);

      final previa = await fonte.buscarProvasSgp('cavalo 1');
      expect(previa.encontrado, isTrue);
      expect(pedidos.single.url.toString(), 'https://api.exemplo/cavalos/cavalo%201/provas/sgp');

      pedidos.clear();
      final muitas = [for (var i = 0; i < 1201; i++) _prova('p$i', DateTime(2026, 1, 1), 17)];
      await fonte.salvarProvas('cavalo 1', muitas);
      expect(pedidos.map((p) => p.method), everyElement('POST'));
      expect(pedidos.map((p) => p.url.toString()), everyElement('https://api.exemplo/cavalos/cavalo%201/provas'));
      expect(pedidos.map((p) => (jsonDecode(p.body)['provas'] as List).length), [500, 500, 201]);
    });

    test('a fonte HTTP traduz recusa do SGP em erro com a mensagem do servidor', () async {
      final cliente = MockClient(
        (_) async => http.Response(jsonEncode({'erro': 'Não foi possível ler o SGP agora.'}), 502),
      );
      final fonte = FonteHttp(base: 'https://api.exemplo', cliente: cliente);
      await expectLater(
        fonte.buscarProvasSgp('c'),
        throwsA(isA<ErroFonte>().having((e) => e.mensagem, 'mensagem', contains('SGP'))),
      );
    });

    test('importar junta as novas, atualiza as já gravadas e grava uma vez só', () async {
      final fonte = FonteMemoria();
      final repo = Repositorio(fonte);
      await repo.carregar();
      final alvo = repo.cavalo!;
      final antes = alvo.provas.length;
      final ja = _prova('sgp-1-1-1', DateTime(2026, 1, 1), 17.5, fonte: 'SGP');
      await repo.salvarCavalo(_comProvas(alvo, [...alvo.provas, ja]));

      final ok = await repo.importarProvas(alvo.id, [
        ja.copiarCom(colocacao: 1),
        _prova('sgp-1-2-2', DateTime(2026, 2, 1), 16.9, fonte: 'SGP'),
      ]);

      expect(ok, isTrue);
      final depois = repo.cavaloPorId(alvo.id)!;
      expect(depois.provas, hasLength(antes + 2));
      expect(depois.provas.firstWhere((p) => p.id == 'sgp-1-1-1').colocacao, 1);
      expect((await fonte.carregar()).cavaloPorId(alvo.id)!.provas, hasLength(antes + 2));
    });

    test('sem servidor, a busca no SGP explica e não quebra', () async {
      final repo = Repositorio(FonteMemoria());
      await repo.carregar();
      final r = await repo.buscarProvasSgp(repo.cavalo!.id);
      expect(r, isNull);
      expect(repo.erro, contains('servidor'));
    });
  });
}
