import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

/// Fonte que registra exatamente **quais** operações de escrita recebeu.
///
/// É o que permite provar que a gravação é por entidade, e não o acervo inteiro.
class _FonteObservada implements FonteDeDados {
  _FonteObservada(this._acervo);

  Acervo _acervo;
  final List<String> escritas = [];

  @override
  String get descricao => 'observada';
  @override
  bool get permiteEscrita => true;

  @override
  Future<Acervo> carregar() async => _acervo;

  @override
  Future<Acervo> salvar(Acervo acervo) async {
    escritas.add('salvar(acervo inteiro)');
    _acervo = acervo;
    return acervo;
  }

  @override
  Future<void> salvarCavalo(Cavalo cavalo) async {
    escritas.add('salvarCavalo(${cavalo.id})');
    final existe = _acervo.cavalos.any((c) => c.id == cavalo.id);
    _acervo = _acervo.copiarCom(
      cavalos: existe
          ? [for (final c in _acervo.cavalos) if (c.id == cavalo.id) cavalo else c]
          : [..._acervo.cavalos, cavalo],
    );
  }

  @override
  Future<void> removerCavalo(String id) async {
    escritas.add('removerCavalo($id)');
    _acervo = _acervo.copiarCom(
      cavalos: [for (final c in _acervo.cavalos) if (c.id != id) c],
      baias: [for (final b in _acervo.baias) if (b.cavaloId != id) b],
    );
  }

  @override
  Future<void> salvarBaia(Baia baia) async {
    escritas.add('salvarBaia(${baia.numero})');
    final existe = _acervo.baias.any((b) => b.numero == baia.numero);
    _acervo = _acervo.copiarCom(
      baias: existe
          ? [for (final b in _acervo.baias) if (b.numero == baia.numero) baia else b]
          : [..._acervo.baias, baia],
    );
  }

  @override
  Future<void> removerBaia(String numero) async {
    escritas.add('removerBaia($numero)');
    _acervo = _acervo.copiarCom(
      baias: [for (final b in _acervo.baias) if (b.numero != numero) b],
    );
  }

  @override
  Future<void> salvarProva(String cavaloId, Prova prova) async {
    escritas.add('salvarProva($cavaloId, ${prova.id})');
    final alvo = _acervo.cavaloPorId(cavaloId)!;
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
    escritas.add('salvarProvas($cavaloId, ${provas.length})');
    final alvo = _acervo.cavaloPorId(cavaloId)!;
    final porId = {for (final p in provas) p.id: p};
    await salvarCavalo(
      alvo.copiarCom(provas: [for (final p in alvo.provas) porId.remove(p.id) ?? p, ...porId.values]),
    );
  }

  @override
  Future<void> removerProva(String cavaloId, String provaId) async {
    escritas.add('removerProva($cavaloId, $provaId)');
    final alvo = _acervo.cavaloPorId(cavaloId)!;
    await salvarCavalo(alvo.copiarCom(provas: [for (final p in alvo.provas) if (p.id != provaId) p]));
  }

  @override
  Future<void> removerMidia(String cavaloId, String midiaId) async {
    escritas.add('removerMidia($cavaloId, $midiaId)');
    final alvo = _acervo.cavaloPorId(cavaloId)!;
    await salvarCavalo(alvo.copiarCom(midias: [for (final m in alvo.midias) if (m.id != midiaId) m]));
  }

  @override
  Future<ResultadoSgp> buscarProvasSgp(String cavaloId) async {
    escritas.add('buscarProvasSgp($cavaloId)');
    return const ResultadoSgp(encontrado: false);
  }

  @override
  Future<String> enviarMidia(
    String cavaloId, {
    required List<int> bytes,
    required String tipoConteudo,
    required String nomeArquivo,
  }) async {
    escritas.add('enviarMidia($cavaloId)');
    return 'https://exemplo.invalid/$nomeArquivo';
  }

  @override
  Future<void> salvarMidia(String cavaloId, Midia midia) async {
    escritas.add('salvarMidia($cavaloId, ${midia.id})');
    final alvo = _acervo.cavaloPorId(cavaloId)!;
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
    escritas.add('definirPrincipal($id)');
    final atual = _acervo.cavaloPorId(id);
    if (atual == null) return;
    await salvarCavalo(atual.copiarCom(principal: true));
  }
}

void main() {
  group('gravação por entidade', () {
    late _FonteObservada fonte;
    late Repositorio repo;

    setUp(() async {
      fonte = _FonteObservada(FonteMemoria.acervoDeDemonstracao());
      repo = Repositorio(fonte);
      await repo.carregar();
    });

    test('editar um cavalo escreve só aquele cavalo', () async {
      final cavalo = repo.cavaloPorId('tornado-do-vale')!;
      await repo.salvarCavalo(cavalo.copiarCom(nome: 'TORNADO II'));

      expect(fonte.escritas, ['salvarCavalo(tornado-do-vale)']);
      expect(
        fonte.escritas.any((e) => e.startsWith('salvar(acervo inteiro)')),
        isFalse,
        reason: 'o acervo inteiro não deve ser reenviado',
      );
    });

    test('remover cavalo usa a operação de remoção', () async {
      await repo.removerCavalo('luna-badger');
      expect(fonte.escritas, ['removerCavalo(luna-badger)']);
    });

    test('destacar cavalo não reenvia o acervo inteiro', () async {
      await repo.definirPrincipal('boneca-freckles');
      // A operação dedicada é usada; a escrita pode delegar internamente para
      // salvarCavalo (uma entidade), nunca para o acervo inteiro.
      expect(fonte.escritas.first, 'definirPrincipal(boneca-freckles)');
      expect(
        fonte.escritas.any((e) => e.startsWith('salvar(acervo inteiro)')),
        isFalse,
      );
      expect(fonte.escritas.every((e) => !e.contains('salvar(acervo')), isTrue);
    });

    test('gravar prova passa pelo cavalo, não pelo acervo', () async {
      await repo.salvarProva(
        'isabel-toro-leo',
        Prova(
          id: 'p-nova',
          data: DateTime(2026, 12, 1),
          nome: 'Três Tambores',
          local: 'Barretos - SP',
          categoria: 'Aberta',
          colocacao: 1,
          tempoSegundos: 16.4,
          inscritos: 30,
        ),
      );

      expect(fonte.escritas.first, contains('salvarProva(isabel-toro-leo'));
      expect(fonte.escritas.any((e) => e.startsWith('salvar(')), isFalse);
    });

    // EQL-008: remover caía no `salvar` do acervo inteiro, que só insere e
    // atualiza; o item voltava.
    test('remover prova e mídia usa a remoção, não o acervo', () async {
      final cavalo = repo.cavaloPorId('isabel-toro-leo')!;
      await repo.removerProva(cavalo.id, cavalo.provas.first.id);
      await repo.removerMidia(cavalo.id, cavalo.midias.first.id);

      expect(fonte.escritas, [
        'removerProva(isabel-toro-leo, ${cavalo.provas.first.id})',
        'salvarCavalo(isabel-toro-leo)',
        'removerMidia(isabel-toro-leo, ${cavalo.midias.first.id})',
        'salvarCavalo(isabel-toro-leo)',
      ]);
      expect(repo.cavaloPorId(cavalo.id)!.provas.any((p) => p.id == cavalo.provas.first.id), isFalse);
    });

    test('editar a descrição grava só aquele cavalo', () async {
      await repo.atualizarDescricao('isabel-toro-leo', 'Nova descrição');
      expect(fonte.escritas, ['salvarCavalo(isabel-toro-leo)']);
      expect(repo.cavaloPorId('isabel-toro-leo')!.descricao, 'Nova descrição');
    });

    test('mexer no manejo grava apenas a baia afetada', () async {
      final baia = repo.baia('01')!;
      final pendente = baia.manejo.firstWhere((t) => !t.concluida);

      await repo.alternarManejo('01', pendente.id);

      expect(fonte.escritas, ['salvarBaia(01)']);
    });

    test('criar baia grava só a baia nova', () async {
      await repo.adicionarBaia(cavaloId: 'estrela-guia', status: StatusBaia.emDia);
      expect(fonte.escritas, ['salvarBaia(06)']);
    });

    test('remover baia usa a operação de remoção', () async {
      await repo.removerBaia('05');
      expect(fonte.escritas, ['removerBaia(05)']);
    });
  });

  group('sem sobrescrita entre operadores', () {
    test('dois operadores editando cavalos diferentes preservam ambas as edições', () async {
      // Duas instâncias independentes, como dois navegadores abertos.
      final fonte = _FonteObservada(FonteMemoria.acervoDeDemonstracao());
      final operadorA = Repositorio(fonte);
      final operadorB = Repositorio(fonte);
      await operadorA.carregar();
      await operadorB.carregar();

      // Antes da correção, cada um reenviava o acervo inteiro e o último
      // a gravar apagava a edição do outro.
      await operadorA.salvarCavalo(
        operadorA.cavaloPorId('tornado-do-vale')!.copiarCom(nome: 'EDITADO POR A'),
      );
      await operadorB.salvarCavalo(
        operadorB.cavaloPorId('luna-badger')!.copiarCom(nome: 'EDITADO POR B'),
      );

      final final_ = await fonte.carregar();
      expect(final_.cavaloPorId('tornado-do-vale')!.nome, 'EDITADO POR A');
      expect(
        final_.cavaloPorId('luna-badger')!.nome,
        'EDITADO POR B',
        reason: 'a edição de B não pode apagar a de A',
      );
      expect(final_.cavalos.length, 5, reason: 'nenhum cavalo pode desaparecer');
    });

    test('editar baia de um haras não apaga cavalo criado por outro operador', () async {
      final fonte = _FonteObservada(FonteMemoria.acervoDeDemonstracao());
      final operadorA = Repositorio(fonte);
      final operadorB = Repositorio(fonte);
      await operadorA.carregar();
      await operadorB.carregar();

      await operadorA.salvarCavalo(
        operadorA.cavalo!.copiarCom(id: 'animal-novo', nome: 'ANIMAL NOVO', principal: false),
      );
      await operadorB.alternarManejo('02', operadorB.baia('02')!.manejo.first.id);

      final final_ = await fonte.carregar();
      expect(final_.cavaloPorId('animal-novo'), isNotNull);
    });
  });

  group('mixin de gravação granular', () {
    test('FonteMemoria aceita as operações por entidade', () async {
      final fonte = FonteMemoria();
      final acervo = await fonte.carregar();
      final cavalo = acervo.cavaloPorId('tornado-do-vale')!;

      await fonte.salvarCavalo(cavalo.copiarCom(nome: 'NOVO NOME'));

      final relido = await fonte.carregar();
      expect(relido.cavaloPorId('tornado-do-vale')!.nome, 'NOVO NOME');
      expect(relido.cavalos.length, acervo.cavalos.length);
    });

    test('salvarProva em cavalo inexistente falha com mensagem clara', () async {
      final fonte = FonteMemoria();
      await fonte.carregar();

      expect(
        () => fonte.salvarProva(
          'nao-existe',
          Prova(
            id: 'p',
            data: DateTime(2026),
            nome: 'x',
            local: 'x',
            categoria: 'x',
            colocacao: 1,
            tempoSegundos: 1,
            inscritos: 1,
          ),
        ),
        throwsA(isA<ErroFonte>()),
      );
    });
  });
}
