import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:equilink_core/equilink_core.dart';

import 'core/sessao_escopo.dart';
import 'core/tema.dart';
import 'escopo.dart';
import 'rotas.dart';
import 'package:equilink_ui/equilink_ui.dart';

import 'widgets/visualizador_midia.dart';

class EquiLinkApp extends StatefulWidget {
  const EquiLinkApp({super.key, this.fonte, this.analytics, this.baias = false, this.sessaoInicial});

  /// Permite injetar uma fonte nos testes; em produção vem de [Ambiente].
  final FonteDeDados? fonte;

  /// Permite injetar a telemetria nos testes; em produção vem de [Ambiente].
  final Analytics? analytics;

  /// Liga o módulo de baias, fora da v1. Só os testes desse módulo o usam hoje.
  final bool baias;

  /// Permite aos testes abrir o app com alguém já conectado.
  final Sessao? sessaoInicial;

  @override
  State<EquiLinkApp> createState() => _EquiLinkAppState();
}

class _EquiLinkAppState extends State<EquiLinkApp> {
  late final Repositorio _repositorio;
  late final Analytics _analytics;
  final _visualizador = VisualizadorController();
  late final _roteador = criarRoteador(
    aoNavegar: _registrarNavegacao,
    baias: widget.baias,
  );

  /// Cliente de sessão; `null` no modo demonstração (fonte em memória).
  late final SessaoApi? _sessaoApi = Ambiente.criarSessao();

  /// `null` = visitante anônimo vendo a vitrine.
  Sessao? _sessao;

  @override
  void initState() {
    super.initState();
    _sessao = widget.sessaoInicial;
    _analytics = widget.analytics ?? Analytics(Ambiente.criarColetor());
    _repositorio = Repositorio(
      widget.fonte ?? Ambiente.criarFonte(),
      analytics: _analytics,
    );
    _repositorio.carregar();

    // Quem já entrou continua entrado ao reabrir: o cookie `HttpOnly` sobrevive
    // ao recarregar. Em paralelo, para a vitrine não esperar a resposta.
    if (_sessaoApi != null) _restaurarSessao();
  }

  /// Recupera a sessão existente; descarta cookie vencido ou revogado.
  Future<void> _restaurarSessao() async {
    final sessao = await _sessaoApi!.atual();
    if (!mounted || sessao == null) return;
    setState(() => _sessao = sessao);
    // Com sessão, a API devolve o acervo completo (manejo incluído).
    _repositorio.carregar();
  }

  /// Entrou: recarrega para receber os dados privados das baias.
  void _aposEntrar(Sessao sessao) {
    setState(() => _sessao = sessao);
    _analytics.registrar('acesso_proprietario', propriedades: {'papel': sessao.papel});
    _repositorio.carregar();
  }

  /// Saiu: volta ao acervo público.
  Future<void> _sair() async {
    await _sessaoApi?.sair();
    if (!mounted) return;
    setState(() => _sessao = null);
    _analytics.registrar('saida_proprietario');
    _repositorio.carregar();
  }

  /// Registra cada troca de tela. O roteador chama isto; as telas não precisam
  /// saber que a telemetria existe.
  void _registrarNavegacao(String rota) => _analytics.visitar(rota);

  @override
  void dispose() {
    _visualizador.dispose();
    _roteador.dispose();
    _analytics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EquiLink',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      routerConfig: _roteador,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('pt')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return EscopoUi(
          paleta: paletaDoApp,
          child: SessaoEscopo(
          sessao: _sessao,
          sessaoApi: _sessaoApi,
          entrar: _aposEntrar,
          sair: _sair,
          child: RepositorioEscopo(
          repositorio: _repositorio,
          child: VisualizadorEscopo(
            notifier: _visualizador,
            child: ListenableBuilder(
              listenable: _visualizador,
              builder: (context, _) {
                final midia = _visualizador.midia;
                final aberto = midia != null;
                return Stack(
                  children: [
                    // Enquanto o acervo não chega, o app mostra carregamento ou
                    // erro em vez das telas: nenhuma tela precisa lidar com
                    // dados ausentes.
                    IgnorePointer(
                      ignoring: aberto,
                      child: ExcludeSemantics(
                        excluding: aberto,
                        // O portão precisa ouvir o repositório: sem isso o app
                        // ficaria preso na tela de carregamento.
                        child: ListenableBuilder(
                          listenable: _repositorio,
                          builder: (context, _) => _Portao(
                            rep: _repositorio,
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    if (aberto)
                      Positioned.fill(
                        child: Overlay(
                          initialEntries: [
                            OverlayEntry(
                              builder: (context) => VisualizadorMidia(
                                midia: midia,
                                aoFechar: _visualizador.fechar,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ),
          ),
        );
      },
    );
  }
}

/// Exibe o conteúdo somente quando o acervo está pronto.
class _Portao extends StatelessWidget {
  const _Portao({required this.rep, required this.child});

  final Repositorio rep;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (rep.estado) {
      case EstadoCarga.pronto:
        if (rep.cavalo == null) return const _AcervoVazio();
        return child;
      case EstadoCarga.erro:
        return _Falha(
          mensagem: rep.erro ?? 'Não foi possível carregar os dados.',
          fonte: rep.fonte.descricao,
          aoTentarNovamente: rep.carregar,
        );
      case EstadoCarga.inicial:
      case EstadoCarga.carregando:
        return const _Carregando();
    }
  }
}

/// Nenhum animal cadastrado ainda — orienta a cadastrar pelo painel.
class _AcervoVazio extends StatelessWidget {
  const _AcervoVazio();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const Padding(
            padding: EdgeInsets.all(Espacos.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_outlined, size: 40, color: Cores.dourado),
                SizedBox(height: Espacos.x4),
                Text(
                  'Nenhum animal cadastrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Cores.texto),
                ),
                SizedBox(height: Espacos.x2),
                Text(
                  'Use o painel administrativo para cadastrar o primeiro cavalo '
                  'e definir qual aparece neste aplicativo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Cores.textoSecundario, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Cores.fundo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.6),
            SizedBox(height: Espacos.x4),
            Text(
              'Carregando os perfis...',
              style: TextStyle(fontSize: 14, color: Cores.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.mensagem, required this.fonte, required this.aoTentarNovamente});

  final String mensagem;
  final String fonte;
  final Future<void> Function() aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(Espacos.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40, color: Cores.vermelho),
                const SizedBox(height: Espacos.x4),
                const Text(
                  'Não foi possível carregar os dados',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Cores.texto),
                ),
                const SizedBox(height: Espacos.x2),
                Text(
                  mensagem,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Cores.textoSecundario,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: Espacos.x4),
                Text(
                  'Fonte: $fonte',
                  style: const TextStyle(fontSize: 11.5, color: Cores.textoSecundario),
                ),
                const SizedBox(height: Espacos.x5),
                FilledButton.icon(
                  onPressed: () => aoTentarNovamente(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
