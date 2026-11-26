import 'package:flutter_test/flutter_test.dart';
import 'package:equilink_core/equilink_core.dart';

void main() {
  group('serialização', () {
    test('acervo sobrevive a uma ida e volta em JSON', () {
      final original = FonteMemoria.acervoDeDemonstracao();
      final texto = FonteMemoria(inicial: original).exportarJson();
      final volta = FonteMemoria.importarJson(texto);

      expect(volta.cavalos.length, original.cavalos.length);
      expect(volta.baias.length, original.baias.length);

      final a = original.principal!;
      final b = volta.principal!;
      expect(b.id, a.id);
      expect(b.nome, a.nome);
      expect(b.sexo, a.sexo);
      expect(b.nascimento, a.nascimento);
      expect(b.provas.length, a.provas.length);
      expect(b.midias.length, a.midias.length);
      expect(b.proprietario.nome, a.proprietario.nome);
      expect(b.genealogia.geracoes, a.genealogia.geracoes);
      expect(b.genealogia.emLargura().length, a.genealogia.emLargura().length);
      expect(b.melhorTempo, a.melhorTempo);
    });

    test('enum desconhecido cai no valor padrão em vez de quebrar', () {
      final cavalo = Cavalo.fromJson(const {
        'id': 'x',
        'nome': 'TESTE',
        'registro': 'P1',
        'sexo': 'invalido',
        'nascimento': '2020-01-01T00:00:00.000',
      });
      expect(cavalo.sexo, Sexo.femea);
      expect(cavalo.provas, isEmpty);
      expect(cavalo.midias, isEmpty);
    });

    test('data inválida não derruba a leitura', () {
      final prova = Prova.fromJson(const {'id': 'p', 'data': 'não é data'});
      expect(prova.data, DateTime(1970));
    });
  });

  group('fonte em memória', () {
    test('devolve o acervo de demonstração com baias 01 a 05', () async {
      final fonte = FonteMemoria();
      final acervo = await fonte.carregar();

      expect(acervo.baias.map((b) => b.numero).toList(), ['01', '02', '03', '04', '05']);
      expect(acervo.cavalos.length, 5);
      expect(acervo.principal!.nome, 'ISABEL TORO LEO');
      expect(acervo.principal!.provas.length, 12);
    });

    test('gravar incrementa a versão e persiste entre leituras', () async {
      final fonte = FonteMemoria();
      final inicial = await fonte.carregar();
      final novaBaia = Baia(
        numero: '99',
        cavaloId: 'isabel-toro-leo',
        status: StatusBaia.emDia,
        ultimaLimpeza: DateTime(2026, 1, 1),
        manejo: const [],
        ocorrencias: const [],
        observacoes: const [],
      );

      final gravado = await fonte.salvar(inicial.copiarCom(baias: [...inicial.baias, novaBaia]));
      expect(gravado.versao, inicial.versao + 1);

      final relido = await fonte.carregar();
      expect(relido.baia('99'), isNotNull);
      expect(relido.versao, gravado.versao);
    });
  });

  group('repositório sobre a fonte em memória', () {
    late Repositorio repo;

    setUp(() async {
      // Relógio fixo no dia dos dados de demonstração.
      repo = Repositorio(FonteMemoria(), agora: () => DateTime(2026, 10, 14));
      await repo.carregar();
    });

    test('carrega e expõe o cavalo principal', () {
      expect(repo.estado, EstadoCarga.pronto);
      expect(repo.cavalo!.nome, 'ISABEL TORO LEO');
      expect(repo.permiteEscrita, isTrue);
      expect(repo.erro, isNull);
    });

    test('criar, editar e remover cavalo', () async {
      final novo = repo.cavalo!.copiarCom(
        id: 'novo-animal',
        nome: 'NOVO ANIMAL',
        registro: 'P999999',
        principal: false,
      );

      expect(await repo.salvarCavalo(novo), isTrue);
      expect(repo.cavalos.length, 6);
      expect(repo.cavaloPorId('novo-animal')!.nome, 'NOVO ANIMAL');

      expect(await repo.salvarCavalo(novo.copiarCom(nome: 'NOVO ANIMAL II')), isTrue);
      expect(repo.cavalos.length, 6, reason: 'editar não deve duplicar');
      expect(repo.cavaloPorId('novo-animal')!.nome, 'NOVO ANIMAL II');

      expect(await repo.removerCavalo('novo-animal'), isTrue);
      expect(repo.cavalos.length, 5);
    });

    test('remover cavalo também remove a baia que o abrigava', () async {
      expect(repo.baia('01')!.cavaloId, 'isabel-toro-leo');

      await repo.removerCavalo('isabel-toro-leo');

      expect(repo.cavaloPorId('isabel-toro-leo'), isNull);
      expect(repo.baia('01'), isNull, reason: 'baia órfã não pode permanecer');
    });

    test('definir principal troca o cavalo exibido no app', () async {
      expect(repo.cavalo!.id, 'isabel-toro-leo');

      expect(await repo.definirPrincipal('tornado-do-vale'), isTrue);

      expect(repo.cavalo!.id, 'tornado-do-vale');
      expect(repo.cavalos.where((c) => c.principal).length, 1);
    });

    test('provas: adicionar, editar e remover', () async {
      final cavaloId = repo.cavalo!.id;
      final prova = Prova(
        id: 'prova-nova',
        data: DateTime(2026, 12, 1),
        nome: 'Três Tambores',
        local: 'Barretos - SP',
        categoria: 'Aberta',
        colocacao: 1,
        tempoSegundos: 16.4,
        inscritos: 30,
      );

      expect(await repo.salvarProva(cavaloId, prova.copiarCom(data: DateTime(2026, 12, 1))), isTrue);
      expect(repo.cavalo!.provas.length, 13);

      await repo.salvarProva(
        cavaloId,
        prova.copiarCom(data: DateTime(2026, 12, 1), colocacao: 2),
      );
      expect(repo.cavalo!.provas.length, 13, reason: 'editar não deve duplicar');
      expect(repo.cavaloPorId(cavaloId)!.provas.firstWhere((p) => p.id == 'prova-nova').colocacao, 2);

      await repo.removerProva(cavaloId, 'prova-nova');
      expect(repo.cavalo!.provas.length, 12);
    });

    test('mídias: adicionar e remover', () async {
      final cavaloId = repo.cavalo!.id;
      final antes = repo.cavalo!.midias.length;

      const midia = Midia(id: 'm-nova', tipo: TipoMidia.foto, arquivo: 'assets/img/hero.jpg');
      expect(await repo.salvarMidia(cavaloId, midia), isTrue);
      expect(repo.cavalo!.midias.length, antes + 1);
      expect(repo.cavalo!.fotos.length, 13);

      await repo.removerMidia(cavaloId, 'm-nova');
      expect(repo.cavalo!.midias.length, antes);
    });

    test('baia nova herda a rotina como pendente e numera em sequência', () async {
      expect(await repo.adicionarBaia(
        cavaloId: 'estrela-guia',
        status: StatusBaia.emDia,
        rotinaModelo: repo.rotinaPadrao(),
      ), isTrue);

      final nova = repo.baia('06')!;
      expect(repo.baias.length, 6);
      expect(nova.cavaloId, 'estrela-guia');
      expect(nova.manejo.length, 8);
      expect(nova.manejo.every((t) => !t.concluida), isTrue);
    });

    test('alternar manejo atualiza a última limpeza quando tudo é concluído', () async {
      final baia = repo.baia('01')!;
      final limpezaAntes = baia.ultimaLimpeza;

      for (final t in baia.manejo.where((t) => !t.concluida).toList()) {
        expect(await repo.alternarManejo('01', t.id), isTrue);
      }

      final depois = repo.baia('01')!;
      expect(depois.manejo.every((t) => t.concluida), isTrue);
      expect(depois.ultimaLimpeza.isAfter(limpezaAntes), isTrue);
      expect(repo.baia('01')!.pendentes, 0);
    });

    test('ocorrência estrutural põe a baia em manutenção; resolver libera', () async {
      expect(repo.baia('03')!.status, StatusBaia.emDia);

      await repo.adicionarOcorrencia(
        '03',
        tipo: TipoOcorrencia.estrutura,
        descricao: 'Divisória solta.',
        responsavel: 'Manutenção',
      );

      final comProblema = repo.baia('03')!;
      expect(comProblema.status, StatusBaia.manutencao);

      await repo.alternarOcorrenciaResolvida('03', comProblema.ocorrencias.first.id);

      final resolvida = repo.baia('03')!;
      expect(resolvida.ocorrencias.first.resolvida, isTrue);
      expect(resolvida.status, StatusBaia.emDia);
    });

    test('tarefas e observações podem ser incluídas e removidas', () async {
      final antes = repo.baia('02')!.manejo.length;
      await repo.adicionarTarefa(
        '02',
        tipo: TipoManejo.exercicio,
        descricao: 'Trote leve',
        horario: '07:30',
        quantidade: '20 min',
      );
      expect(repo.baia('02')!.manejo.length, antes + 1);

      final novaTarefa = repo.baia('02')!.manejo.last;
      await repo.removerTarefa('02', novaTarefa.id);
      expect(repo.baia('02')!.manejo.length, antes);

      final obsAntes = repo.baia('02')!.observacoes.length;
      await repo.adicionarObservacao('02', autor: 'Teste', texto: 'Observação de teste.');
      expect(repo.baia('02')!.observacoes.length, obsAntes + 1);

      final novaObs = repo.baia('02')!.observacoes.first;
      await repo.removerObservacao('02', novaObs.id);
      expect(repo.baia('02')!.observacoes.length, obsAntes);
    });

    test('consumo diário e indicadores refletem o acervo', () {
      final consumo = {for (final c in repo.consumoDiario) c.insumo: c.quilos};
      expect(consumo['Ração'], closeTo(22.5, 0.001));
      expect(consumo['Feno'], closeTo(10, 0.001));
      expect(consumo['Suplemento'], closeTo(0.15, 0.001));

      expect(repo.manejoPendenteTotal, 22);
      expect(repo.ocorrenciasAbertasTotal, 3);
      expect(repo.baiasEmManutencao, 1);
    });
  });

  group('repositório somente leitura', () {
    test('recusa escrita e explica o motivo', () async {
      final repo = Repositorio(_FonteSomenteLeitura());
      await repo.carregar();

      expect(repo.permiteEscrita, isFalse);
      expect(await repo.salvarCavalo(repo.cavalo!), isFalse);
      expect(repo.erro, contains('somente leitura'));
    });
  });

  group('repositório com fonte que falha', () {
    test('expõe o erro de leitura sem quebrar', () async {
      final repo = Repositorio(_FonteQuebrada());
      await repo.carregar();

      expect(repo.estado, EstadoCarga.erro);
      expect(repo.erro, contains('indisponível'));
      expect(repo.cavalo, isNull);
    });

    test('falha de gravação mantém o dado local e reporta o erro', () async {
      final repo = Repositorio(_FonteQuebrada(leituraOk: true));
      await repo.carregar();
      expect(repo.estado, EstadoCarga.pronto);

      final ok = await repo.definirPrincipal('tornado-do-vale');
      expect(ok, isFalse);
      expect(repo.erro, contains('indisponível'));
    });
  });
}

/// Fonte que recusa qualquer escrita.
class _FonteSomenteLeitura with GravacaoGranular implements FonteDeDados {
  final _acervo = FonteMemoria.acervoDeDemonstracao();

  @override
  Acervo get acervoAtual => _acervo;

  @override
  set acervoAtual(Acervo valor) {}

  @override
  String get descricao => 'somente leitura';
  @override
  bool get permiteEscrita => false;
  @override
  Future<Acervo> carregar() async => _acervo;
  @override
  Future<Acervo> salvar(Acervo acervo) async => throw const ErroFonte('somente leitura');
}

/// Fonte que sempre falha na rede (e opcionalmente funciona na leitura).
class _FonteQuebrada with GravacaoGranular implements FonteDeDados {
  _FonteQuebrada({this.leituraOk = false});

  final bool leituraOk;

  Acervo _conhecido = FonteMemoria.acervoDeDemonstracao();

  @override
  Acervo get acervoAtual => _conhecido;

  @override
  set acervoAtual(Acervo valor) => _conhecido = valor;

  @override
  String get descricao => 'quebrada';
  @override
  bool get permiteEscrita => true;
  @override
  Future<Acervo> carregar() async {
    if (leituraOk) return FonteMemoria.acervoDeDemonstracao();
    throw const ErroFonte('Servidor indisponível.');
  }

  @override
  Future<Acervo> salvar(Acervo acervo) async => throw const ErroFonte('Servidor indisponível.');
}
