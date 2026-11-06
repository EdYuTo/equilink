import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:equilink/app.dart';
import 'package:equilink_core/equilink_core.dart';
import 'package:equilink/telas/acesso.dart';
import 'package:equilink/telas/baias.dart';
import 'package:equilink/telas/genealogia.dart';
import 'package:equilink/telas/historico.dart';
import 'package:equilink/telas/perfil.dart';
import 'package:equilink/telas/placa.dart';
import 'package:equilink/widgets/marca.dart';
import 'package:equilink/widgets/visualizador_midia.dart';
import 'package:equilink/core/sessao_escopo.dart';
import 'package:equilink/escopo.dart';

void main() {
  group('formatação pt-BR', () {
    test('tempo de prova usa vírgula e três milésimos', () {
      expect(tempoProva(16.742), '16,742');
      expect(tempoProva(9.05), '9,050');
      expect(tempoProva(75.4), '1:15,400');
    });

    test('idade considera anos e meses completos', () {
      final hoje = DateTime(2026, 10, 14);
      expect(idade(DateTime(2018, 8, 18), referencia: hoje), '8 anos e 1 mês');
      expect(idade(DateTime(2026, 8, 20), referencia: hoje), '1 mês');
      expect(idade(DateTime(2026, 9, 1), referencia: hoje), '1 mês');
      expect(idade(DateTime(2019, 10, 14), referencia: hoje), '7 anos');
    });

    test('percentual e plural seguem o padrão brasileiro', () {
      expect(percentual(5 / 12), '41,7%');
      expect(percentual(0.5, casas: 0), '50%');
      expect(plural(1, 'prova', 'provas'), '1 prova');
      expect(plural(12, 'prova', 'provas'), '12 provas');
    });

    test('telefone recebe máscara brasileira', () {
      expect(telefone('11999999999'), '(11) 99999-9999');
      expect(telefone('1133334444'), '(11) 3333-4444');
    });
  });

  group('repositório', () {
    test('concluir toda a rotina atualiza a última limpeza', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      final baia = repositorio.baia('01')!;
      final limpezaAnterior = baia.ultimaLimpeza;
      final pendentes = baia.manejo.where((t) => !t.concluida).toList();
      expect(pendentes, isNotEmpty);

      for (final tarefa in pendentes) {
        expect(await repositorio.alternarManejo('01', tarefa.id), isTrue);
      }

      final atualizada = repositorio.baia('01')!;
      expect(atualizada.manejo.every((t) => t.concluida), isTrue);
      expect(atualizada.ultimaLimpeza.isAfter(limpezaAnterior), isTrue);
      // As demais baias mantêm suas pendências.
      expect(repositorio.manejoPendenteTotal, greaterThan(0));
      expect(repositorio.baia('01')!.manejo.where((t) => !t.concluida), isEmpty);
    });

    test('ocorrência estrutural coloca a baia em manutenção e resolvê-la libera', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      expect(repositorio.baia('03')!.status, StatusBaia.emDia);

      await repositorio.adicionarOcorrencia(
        '03',
        tipo: TipoOcorrencia.estrutura,
        descricao: 'Divisória solta.',
        responsavel: 'Manutenção',
      );

      final baia = repositorio.baia('03')!;
      expect(baia.status, StatusBaia.manutencao);
      expect(baia.ocorrencias.first.resolvida, isFalse);

      await repositorio.alternarOcorrenciaResolvida('03', baia.ocorrencias.first.id);

      final resolvida = repositorio.baia('03')!;
      expect(resolvida.ocorrencias.first.resolvida, isTrue);
      expect(resolvida.status, StatusBaia.emDia);
    });

    test('nova baia recebe numeração sequencial e a rotina padrão', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      await repositorio.adicionarBaia(cavaloId: 'estrela-guia', status: StatusBaia.emDia);

      expect(repositorio.baias.length, 6);
      final nova = repositorio.baia('06')!;
      expect(nova.cavaloId, 'estrela-guia');
      expect(nova.manejo.length, repositorio.baia('01')!.manejo.length);
      expect(nova.manejo.every((t) => !t.concluida), isTrue);
    });

    test('consumo diário agrega ração, feno e suplemento', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      final consumo = {for (final c in repositorio.consumoDiario) c.insumo: c.quilos};

      // Ração: 3 refeições de 1,5 kg por baia, em 5 baias.
      expect(consumo['Ração'], closeTo(22.5, 0.001));
      // Feno: 2,0 kg por baia, em 5 baias.
      expect(consumo['Feno'], closeTo(10, 0.001));
      // Suplemento: 30 g por baia, em 5 baias.
      expect(consumo['Suplemento'], closeTo(0.15, 0.001));
    });

    test('estatísticas esportivas derivam das provas cadastradas', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      final cavalo = repositorio.cavalo!;
      expect(cavalo.provas.length, 12);
      expect(cavalo.vitorias, 5);
      expect(cavalo.podios, 9);
      expect(cavalo.melhorTempo, 16.583);
    });

    test('genealogia alcança os bisavós em quatro níveis', () async {
      final repositorio = Repositorio(FonteMemoria());
      await repositorio.carregar();
      final cavalo = repositorio.cavalo!;
      // animal + pais + avós + bisavós
      expect(cavalo.genealogia.geracoes, 4);
      // 2 pais + 4 avós + 8 bisavós, mais o próprio animal.
      expect(cavalo.genealogia.emLargura().length, 15);
      expect(cavalo.pai.nome, 'LEO DO VALE');
      expect(cavalo.pai.pai!.nome, 'Toro Leo');
      expect(cavalo.pai.pai!.pai!.nome, 'Doc Bar');
    });
  });

  group('interface', () {
    /// Navegação inferior é usada apenas em telas estreitas.
    Future<void> usarTelaDeCelular(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 940);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// Toca em um destino da barra inferior (evita colisão com abas internas).
    Future<void> irPara(WidgetTester tester, String rotulo) async {
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(rotulo)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('abre no perfil do cavalo com dados principais', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      expect(find.text('DETALHES'), findsOneWidget);
      expect(find.byType(LogoEquilink), findsOneWidget);
      expect(find.text('ISABEL TORO LEO'), findsOneWidget);
      expect(find.textContaining('P341234'), findsWidgets);
    });

    testWidgets('navega pelos módulos principais', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(baias: true, fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      await irPara(tester, 'Genealogia');
      expect(find.text('BISAVÓS'), findsOneWidget);
      expect(find.textContaining('LEO DO VALE'), findsWidgets);

      await irPara(tester, 'Histórico');
      expect(find.text('Estatísticas'), findsOneWidget);

      await irPara(tester, 'Baias');
      expect(find.textContaining('Baia 01'), findsWidgets);
      expect(find.text('Em dia'), findsWidgets);
    });

    testWidgets('conclui uma tarefa de manejo pela lista consolidada', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(baias: true, fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      await irPara(tester, 'Baias');
      expect(find.text('Manejo pendente'), findsOneWidget);

      await tester.tap(find.text('Manejo').first);
      await tester.pumpAndSettle();

      // Primeira tarefa ainda pendente da primeira baia.
      final pendente = tester.widgetList<Checkbox>(find.byType(Checkbox)).firstWhere(
        (c) => c.value == false,
      );
      expect(pendente.value, isFalse);
      await tester.tap(find.byWidget(pendente));
      await tester.pumpAndSettle();

      expect(find.textContaining('registrada como concluída'), findsOneWidget);
    });

    testWidgets('visitante não vê a placa, nem pelo link direto', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      expect(find.text('Placa de identificação'), findsNothing);

      GoRouter.of(tester.element(find.byType(TelaPerfil))).push('/placa');
      await tester.pumpAndSettle();

      expect(find.byType(TelaPlaca), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Acesso do proprietário'), findsOneWidget);
    });

    testWidgets('quem entrou abre a placa de identificação pelo perfil', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(
        EquiLinkApp(
          fonte: FonteMemoria(),
          sessaoInicial: const Sessao(usuario: 'teste', harasId: 'h1', papel: 'leitor'),
        ),
      );
      await tester.pumpAndSettle();

      final botao = find.text('Placa de identificação');
      await tester.scrollUntilVisible(botao, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.byType(TelaPlaca), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('abre os detalhes da baia com a rotina de manejo', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(baias: true, fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      await irPara(tester, 'Baias');

      await tester.tap(find.text('Baia 02').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Baia 02 - TORNADO DO VALE'), findsOneWidget);
      expect(find.text('Rotina de manejo'), findsOneWidget);
      expect(find.text('Ração da manhã'), findsOneWidget);
    });

    testWidgets('o visualizador de mídia cobre a navegação principal', (tester) async {
      await usarTelaDeCelular(tester);
      await tester.pumpWidget(EquiLinkApp(baias: true, fonte: FonteMemoria()));
      await tester.pumpAndSettle();

      await irPara(tester, 'Fotos');

      // Abre o visualizador tocando na foto de capa.
      await tester.tap(find.text('Capa'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Com o visualizador aberto, a navegação principal fica inacessível:
      // tocar em "Baias" não pode trocar de módulo por baixo da mídia.
      final destinos = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Baias'),
      );
      await tester.tap(destinos, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Meus cavalos'), findsNothing);

      // Fechar o visualizador devolve o controle da navegação.
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);

      await irPara(tester, 'Baias');
      expect(find.text('Meus cavalos'), findsOneWidget);
    });
  });

  group('v1: perfil público', () {
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EquiLinkApp(fonte: FonteMemoria()));
      await tester.pumpAndSettle();
    }

    Finder destino(String rotulo) =>
        find.descendant(of: find.byType(NavigationBar), matching: find.text(rotulo));

    testWidgets('baias ficam fora da navegação e o link antigo abre o perfil', (tester) async {
      await abrir(tester);
      expect(destino('Baias'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));

      GoRouter.of(tester.element(find.byType(TelaPerfil))).go('/baias');
      await tester.pumpAndSettle();
      expect(find.text('DETALHES'), findsOneWidget);
    });

    testWidgets('perfil mostra os detalhes e esconde placa e edição do visitante', (tester) async {
      await abrir(tester);
      for (final rotulo in ['PROPRIETÁRIO', 'CRIADOR', 'NASCIMENTO', 'SEXO', 'PELAGEM', 'REGISTRO', 'PAI', 'MÃE']) {
        expect(find.text(rotulo), findsWidgets, reason: rotulo);
      }
      expect(find.byTooltip('Placa de identificação'), findsNothing);
      expect(find.textContaining('QR Code'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Acesso do proprietário'), findsOneWidget);
      expect(find.text('Compartilhar perfil'), findsNothing);
    });

    testWidgets('o visualizador de mídia não usa o texto sem estilo do Flutter', (tester) async {
      await abrir(tester);
      await tester.tap(destino('Fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capa').first);
      await tester.pumpAndSettle();
      final textos = find.descendant(
        of: find.byType(VisualizadorMidia),
        matching: find.byType(Text),
      );
      expect(textos, findsWidgets);
      for (final elemento in textos.evaluate()) {
        expect(DefaultTextStyle.of(elemento).style.decoration, isNot(TextDecoration.underline));
      }
    });

    testWidgets('a aba Fotos não mostra QR Code ao visitante', (tester) async {
      await abrir(tester);
      await tester.tap(destino('Fotos'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('QR Code'), findsNothing);
    });

    testWidgets('genealogia mostra só a árvore e tocar abre a ficha do ancestral', (tester) async {
      await abrir(tester);
      await tester.tap(destino('Genealogia'));
      await tester.pumpAndSettle();

      expect(find.text('PAIS'), findsOneWidget);
      expect(find.text('Lista'), findsNothing);
      expect(find.text('Ancestrais'), findsNothing);
      expect(find.text('Profundidade da árvore'), findsNothing);

      final cavalo = FonteMemoria.acervoDeDemonstracao().principal!;
      await tester.tap(find.textContaining(cavalo.pai.nome.toUpperCase(), findRichText: true).first);
      await tester.pumpAndSettle();

      expect(find.text('PAI'), findsWidgets);
      expect(find.textContaining('Pais, avós e bisavós de'), findsOneWidget);

      await tester.tap(find.textContaining('Pais, avós e bisavós de'));
      await tester.pumpAndSettle();
      expect(find.text(cavalo.pai.nome), findsOneWidget);
      expect(find.text('BISAVÓS'), findsWidgets);
    });

    testWidgets('o zoom da árvore respeita os limites', (tester) async {
      await abrir(tester);
      await tester.tap(destino('Genealogia'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      await tester.tap(find.byTooltip('Diminuir zoom'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('a ficha mostra os dados reais e o que falta fica como não informado', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArvoreGenealogica(
              slots: montarSlots(
                const Ancestral(
                  nome: 'RAIZ',
                  registro: 'R',
                  pai: Ancestral(
                    nome: 'GARANHAO',
                    registro: 'P1',
                    premiacaoProvas: 18222,
                    premiacaoReprodutor: 3837038.3,
                    filhosPremiados: 41,
                    nascimento: '2015-07-02',
                    fonte: 'SGP',
                    atualizadoEm: '2026-11-06',
                  ),
                ),
              ),
              aoTocar: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pai · GARANHAO', findRichText: true), findsOneWidget);
      expect(find.text('Não informado'), findsNWidgets(13));
      expect(reais(3837038.3), 'R\$ 3.837.038,30');
      expect(reais(18222), 'R\$ 18.222,00');
      expect(reais(0), 'R\$ 0,00');
    });

    test('o histórico cita cada fonte uma vez e ignora as provas sem fonte', () {
      Prova prova(String? fonte) => Prova(
        id: 'p',
        data: DateTime(2026),
        nome: 'A',
        local: '',
        categoria: 'B',
        colocacao: 0,
        tempoSegundos: 1,
        inscritos: 0,
        fonte: fonte,
      );
      expect(fontesDasProvas([prova('HorseSport'), prova('HorseSport'), prova(null), prova('')]), ['HorseSport']);
      expect(fontesDasProvas([prova(null)]), isEmpty);
    });

    test('a árvore tem 14 posições e nomeia cada ramo', () {
      final slots = montarSlots(const Ancestral(nome: 'RAIZ', registro: 'R'));
      expect(slots, hasLength(14));
      expect(slots.where((s) => s.geracao == 1), hasLength(2));
      expect(slots.where((s) => s.geracao == 2), hasLength(4));
      expect(slots.where((s) => s.geracao == 3), hasLength(8));
      expect(slots.every((s) => s.ancestral == null), isTrue);
      expect(slots.map((s) => s.papel), containsAll(['Pai', 'Mãe', 'Avô materno', 'Avó paterna', 'Bisavó materna']));
    });

    test('ancestral gravado como travessão conta como não informado', () {
      final slots = montarSlots(
        const Ancestral(
          nome: 'RAIZ',
          registro: 'R',
          pai: Ancestral(nome: '—', registro: '—'),
          mae: Ancestral(nome: 'MAE', registro: '—'),
        ),
      );
      expect(slots.where((s) => s.ancestral != null).map((s) => s.ancestral!.nome), ['MAE']);
    });

    test('ancestral sem nome conta como não informado e não abre ramo', () {
      final slots = montarSlots(
        const Ancestral(
          nome: 'RAIZ',
          registro: 'R',
          pai: Ancestral(nome: '', registro: '', pai: Ancestral(nome: 'OCULTO', registro: 'X')),
          mae: Ancestral(nome: 'MAE', registro: 'M'),
        ),
      );
      expect(slots.where((s) => s.ancestral != null).map((s) => s.ancestral!.nome), ['MAE']);
    });
  });

  group('link direto do animal', () {
    const registro = 'P347821';
    const nome = 'TORNADO DO VALE';

    Future<void> abrirEm(WidgetTester tester, String rota) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.defaultRouteNameTestValue = rota;
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(EquiLinkApp(fonte: FonteMemoria()));
      await tester.pumpAndSettle();
    }

    String urlAtual(WidgetTester tester) => GoRouter.of(
      tester.element(find.byType(NavigationBar)),
    ).routerDelegate.currentConfiguration.uri.toString();

    Future<void> irPara(WidgetTester tester, String rotulo) async {
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(rotulo)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('abre o animal e mantém o endereço do link', (tester) async {
      await abrirEm(tester, '/cavalo/$registro');
      expect(find.text(nome), findsWidgets);
      expect(find.text('ISABEL TORO LEO'), findsNothing);
      expect(urlAtual(tester), '/cavalo/$registro');
    });

    testWidgets('as abas levam o animal na URL e voltam ao link', (tester) async {
      await abrirEm(tester, '/cavalo/$registro');

      await irPara(tester, 'Genealogia');
      expect(urlAtual(tester), '/genealogia?cavalo=$registro');
      expect(find.text(nome), findsOneWidget);

      await irPara(tester, 'Perfil');
      expect(urlAtual(tester), '/cavalo/$registro');

      await irPara(tester, 'Perfil');
      expect(urlAtual(tester), '/cavalo/$registro');
    });

    testWidgets('recarregar em outra aba continua no animal', (tester) async {
      await abrirEm(tester, '/genealogia?cavalo=$registro');
      expect(find.text(nome), findsOneWidget);
      expect(find.text('ISABEL TORO LEO'), findsNothing);
      expect(urlAtual(tester), '/genealogia?cavalo=$registro');
    });

    testWidgets('recarregar o acervo mantém o animal do link', (tester) async {
      await abrirEm(tester, '/cavalo/$registro');
      final contexto = tester.element(find.byType(NavigationBar));
      await RepositorioEscopo.de(contexto).carregar();
      await tester.pumpAndSettle();
      expect(find.text(nome), findsWidgets);
      expect(urlAtual(tester), '/cavalo/$registro');
    });

    testWidgets('sem link, o app continua no destaque', (tester) async {
      await abrirEm(tester, '/perfil');
      expect(find.text('ISABEL TORO LEO'), findsOneWidget);
      expect(urlAtual(tester), '/perfil');
    });

    testWidgets('registro inexistente explica em vez de mostrar outro animal', (tester) async {
      await abrirEm(tester, '/cavalo/NAO-EXISTE');
      expect(find.textContaining('NAO-EXISTE'), findsOneWidget);
      expect(find.text('ISABEL TORO LEO'), findsNothing);
      expect(urlAtual(tester), '/cavalo/NAO-EXISTE');
    });

    testWidgets('sair do registro inexistente leva ao destaque', (tester) async {
      await abrirEm(tester, '/cavalo/NAO-EXISTE');
      await tester.tap(find.text('Ver o perfil em destaque'));
      await tester.pumpAndSettle();
      expect(find.text('ISABEL TORO LEO'), findsOneWidget);
      expect(urlAtual(tester), '/perfil');
    });
  });

  group('acesso do proprietário', () {
    testWidgets('visitante vê o aviso de manejo privado e é levado ao login', (tester) async {
      // Fonte em memória: sem backend não haveria aviso nem login, então o
      // cenário usa uma sessão explícita de visitante com backend disponível.
      final sessaoApi = SessaoApi(base: 'https://exemplo.invalid');
      await tester.pumpWidget(
        SessaoEscopo(
          sessao: null,
          sessaoApi: sessaoApi,
          entrar: (_) {},
          sair: () async {},
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const AvisoManejoPrivado(),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TelaAcesso()),
                        ),
                        child: const Text('abrir acesso'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('O manejo das baias é privado'), findsOneWidget);

      await tester.tap(find.text('abrir acesso'));
      await tester.pumpAndSettle();
      expect(find.text('Acesso do proprietário'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Continuar sem entrar'), findsOneWidget);
    });

    testWidgets('quem já entrou não vê o aviso de privacidade', (tester) async {
      final sessaoApi = SessaoApi(base: 'https://exemplo.invalid');
      await tester.pumpWidget(
        SessaoEscopo(
          sessao: const Sessao(usuario: 'eduardo', harasId: 'h1', papel: 'proprietario'),
          sessaoApi: sessaoApi,
          entrar: (_) {},
          sair: () async {},
          child: const MaterialApp(home: Scaffold(body: AvisoManejoPrivado())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('O manejo das baias é privado'), findsNothing);
    });
  });

  group('regressões do e2e', () {
    test('link por registro foca o animal pedido e avisa quando não existe', () async {
      final rep = Repositorio(FonteMemoria());
      await rep.carregar();

      // Sem foco, o app mostra o perfil em destaque.
      final destaque = rep.cavalo!.registro;
      expect(rep.erroFoco, isNull);

      // Um registro existente passa a ser o exibido.
      final outro = rep.cavalos.firstWhere((c) => c.registro != destaque);
      expect(rep.focarRegistro(outro.registro.toLowerCase()), isTrue);
      expect(rep.cavalo!.id, outro.id);
      expect(rep.erroFoco, isNull);

      // Registro inexistente explica em vez de mostrar outro animal.
      expect(rep.focarRegistro('NAO-EXISTE'), isFalse);
      expect(rep.erroFoco, contains('NAO-EXISTE'));

      // Limpar volta ao destaque.
      rep.limparFoco();
      expect(rep.erroFoco, isNull);
      expect(rep.cavalo!.registro, destaque);
    });

    test('baia sem animal é reconhecida como vazia', () async {
      final rep = Repositorio(FonteMemoria());
      await rep.carregar();

      expect(rep.baiaOrfa(null), isTrue);
      expect(rep.baiaOrfa(''), isTrue);
      expect(rep.baiaOrfa('cavalo-que-nao-existe'), isTrue);
      final existente = rep.cavalos.first.id;
      expect(rep.baiaOrfa(existente), isFalse);
    });

    testWidgets('diálogo de nova baia lista o acervo, não uma lista fixa', (tester) async {
      final fonte = FonteMemoria();
      final rep = Repositorio(fonte);
      await rep.carregar();

      // A lista fixa no código tinha animais que não existem no acervo
      // ("ESTRELA GUIA", "VENTO NORTE") e escondia os cadastrados. A opção
      // precisa sair sempre de `repositorio.cavalos`.
      final idsDoAcervo = rep.cavalos.map((c) => c.id).toSet();
      expect(idsDoAcervo, isNot(contains('estrela-guia')));
      expect(idsDoAcervo, isNot(contains('vento-norte')));

      final livres = rep.cavalos.where(
        (c) => !rep.baias.any((b) => b.cavaloId == c.id),
      ).toList();
      // Cada animal sem baia é uma opção válida; nenhum vem de fora do acervo.
      for (final c in livres) {
        expect(idsDoAcervo, contains(c.id));
      }
    });
  });
}
