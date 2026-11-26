import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:equilink_core/equilink_core.dart';

import 'core/analytics_painel.dart';
import 'core/inatividade.dart';
import 'telas/login.dart';
import 'core/escopo.dart';
import 'core/tema.dart';
import 'package:equilink_ui/equilink_ui.dart';
import 'rotas.dart';

void main() {
  // URLs sem `#` no web. O Worker já serve o index.html para qualquer rota
  // (not_found_handling: single-page-application), então `/cavalos/novo` abre o
  // assistente direto em vez de cair na visão geral.
  if (kIsWeb) usePathUrlStrategy();
  runApp(const PainelApp());
}

/// Painel administrativo do EquiLink.
///
/// Compartilha o mesmo núcleo de dados do aplicativo do usuário: ler e gravar
/// aqui reflete no app, porque ambos conversam com a mesma [FonteDeDados].
class PainelApp extends StatefulWidget {
  const PainelApp({super.key, this.fonte, this.coletorAnalitico, this.sessaoApi});

  /// Permite injetar uma fonte nos testes; em produção vem de [Ambiente].
  final FonteDeDados? fonte;

  /// Permite injetar o coletor de analytics nos testes.
  final ColetorAnaliticoPainel? coletorAnalitico;

  /// Permite injetar o cliente de sessão nos testes; em produção vem de [Ambiente].
  final SessaoApi? sessaoApi;

  @override
  State<PainelApp> createState() => _PainelAppState();
}

class _PainelAppState extends State<PainelApp> {
  late final Repositorio _repositorio;
  late final ColetorAnaliticoPainel _analytics;
  late final _roteador = criarRoteadorAdmin();

  /// Cliente de sessão; `null` quando a fonte é memória (testes/demonstração).
  late final SessaoApi? _sessaoApi = widget.sessaoApi ?? Ambiente.criarSessao();

  /// Sessão resolvida. `null` = ninguém autenticado.
  Sessao? _sessao;

  /// Motivo exibido na tela de login (ex.: sessão expirada).
  String? _motivoLogin;

  /// Encerra a sessão depois de 1 h sem atividade.
  late final VigiaInatividade _vigia = VigiaInatividade()
    ..aoExpirar = _expirarPorInatividade
    ..aoAvisar = _avisarInatividade;


  @override
  void initState() {
    super.initState();
    // O painel tem o próprio coletor: registra as ações feitas aqui e aceita
    // importar os eventos vindos do aplicativo.
    _analytics = widget.coletorAnalitico ?? ColetorAnaliticoPainel();
    _repositorio = Repositorio(
      widget.fonte ?? Ambiente.criarFonte(),
      analytics: Analytics(
        _ColetorDoPainel(_analytics),
        usuario: 'painel',
      ),
    );
    // Sem backend (memória) o painel abre direto — é o modo demonstração.
    if (_sessaoApi == null) {
      _repositorio.carregar();
      return;
    }
    _restaurarSessao();
  }

  /// Recupera a sessão existente ao abrir o painel.
  ///
  /// O cookie `HttpOnly` sobrevive ao recarregar a página, então quem já entrou
  /// não deve ver o formulário de novo. Perguntar ao servidor também descarta
  /// cookie vencido, revogado ou forjado.
  Future<void> _restaurarSessao() async {
    final sessao = await _sessaoApi!.atual();
    if (!mounted) return;
    if (sessao == null) {
      // Sem sessão: mostra o login sem carregar acervo (que viria público).
      setState(() => _sessao = null);
      return;
    }
    setState(() => _sessao = sessao);
    _vigia.iniciar();
    _repositorio.carregar();
    _carregarTelemetria();
  }

  /// Traz os eventos gravados no backend.
  ///
  /// O aplicativo envia telemetria para o banco; sem esta leitura o painel
  /// mostrava só o que aconteceu naquela sessão do navegador.
  Future<void> _carregarTelemetria() async {
    final api = Ambiente.api;
    if (api.isEmpty) return;
    await _analytics.carregarDe(
      () => buscarEventosNaApi(
        base: api,
        cabecalhos: Ambiente.token.isEmpty
            ? const {}
            : {'Authorization': 'Bearer ${Ambiente.token}'},
      ),
      rotulo: 'API (${Ambiente.api})',
    );
    // `total` fica no rótulo de origem montado por carregarDe.
  }

  /// Chamado quando a FonteHttp recebe 401: a sessão morreu no servidor.
  void _sessaoExpirou() {
    if (!mounted || _sessao == null) return;
    _vigia.parar();
    setState(() {
      _sessao = null;
      _motivoLogin = 'Sua sessão expirou. Entre de novo.';
    });
  }

  /// Recarrega o acervo depois do login.
  void _aposEntrar(Sessao sessao) {
    setState(() {
      _sessao = sessao;
      _motivoLogin = null;
    });
    _vigia.iniciar();
    _repositorio.carregar();
  }

  /// O prazo estourou: encerra a sessão também no servidor.
  Future<void> _expirarPorInatividade() async {
    await _sessaoApi?.sair();
    if (!mounted) return;
    setState(() {
      _sessao = null;
      _motivoLogin =
          'Sessão encerrada por inatividade (${_vigia.limiteEmTexto} sem uso). Entre de novo.';
    });
  }

  /// Faltando pouco para expirar, avisa e deixa o operador continuar.
  void _avisarInatividade() {
    if (!mounted || _sessao == null) return;
    setState(() {});
  }

  Future<void> _sair() async {
    _vigia.parar();
    await _sessaoApi?.sair();
    if (!mounted) return;
    setState(() {
      _sessao = null;
      _motivoLogin = 'Sessão encerrada.';
    });
  }

  @override
  void dispose() {
    _vigia.dispose();
    _roteador.dispose();
    _analytics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EquiLink — Administração',
      debugShowCheckedModeBanner: false,
      theme: construirTemaAdmin(),
      routerConfig: _roteador,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return EscopoUi(
          paleta: paletaDoPainel,
          child: AnalyticsPainelEscopo(
          notifier: _analytics,
          child: AdminEscopo(
            repositorio: _repositorio,
            child: ListenableBuilder(
              listenable: _repositorio,
              builder: (context, _) => AreaDeAtividade(
                vigia: _vigia,
                child: ListenableBuilder(
                  listenable: _vigia,
                  builder: (context, _) => Stack(
                    children: [
                      _Portao(
                        rep: _repositorio,
                        sessaoApi: _sessaoApi,
                        sessao: _sessao,
                        motivoLogin: _motivoLogin,
                        aoEntrar: _aposEntrar,
                        aoSair: _sair,
                        aoExpirar: _sessaoExpirou,
                        child: child ?? const SizedBox.shrink(),
                      ),
                      if (_vigia.avisando && _sessao != null)
                        _AvisoInatividade(
                          restante: _vigia.restante,
                          aoContinuar: _vigia.prorrogar,
                          aoSair: _sair,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

/// Dá ao login a camada de sobreposição que ele não tem.
///
/// O login é desenhado no `builder` do app, acima do roteador e de qualquer
/// `Navigator`. Campo de texto (alças e menu de seleção) e dica de botão
/// precisam de um `Overlay` ancestral; sem ele, focar o campo "Usuário", que
/// tem autofoco, quebrava a cada carregamento (EQL-042).
class _ComSobreposicao extends StatefulWidget {
  const _ComSobreposicao({required this.child});

  final Widget child;

  @override
  State<_ComSobreposicao> createState() => _ComSobreposicaoState();
}

class _ComSobreposicaoState extends State<_ComSobreposicao> {
  late final OverlayEntry _entrada = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_ComSobreposicao antigo) {
    super.didUpdateWidget(antigo);
    // A entrada só se reconstrói quando pedida: assim o motivo do login muda.
    _entrada.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entrada]);
}

/// Só libera o painel quando o acervo está disponível.
class _Portao extends StatelessWidget {
  const _Portao({
    required this.rep,
    required this.child,
    this.sessaoApi,
    this.sessao,
    this.motivoLogin,
    this.aoEntrar,
    this.aoSair,
    this.aoExpirar,
  });

  final Repositorio rep;
  final Widget child;

  /// Quando há backend, o painel só abre com sessão.
  final SessaoApi? sessaoApi;
  final Sessao? sessao;
  final String? motivoLogin;
  final ValueChanged<Sessao>? aoEntrar;
  final Future<void> Function()? aoSair;
  final VoidCallback? aoExpirar;

  @override
  Widget build(BuildContext context) {
    // Com backend: sem sessão não há painel, nem no modo de erro.
    if (sessaoApi != null && sessao == null) {
      return _ComSobreposicao(
        child: TelaLogin(
          sessaoApi: sessaoApi!,
          aoEntrar: aoEntrar ?? (_) {},
          motivo: motivoLogin,
        ),
      );
    }

    switch (rep.estado) {
      case EstadoCarga.pronto:
        // O selo de sessão é desenhado pela moldura, junto do botão de
        // sugestões: dois `Positioned` independentes no mesmo canto se
        // sobrepunham.
        return SessaoAdminEscopo(sessao: sessao, aoSair: aoSair, child: child);
      case EstadoCarga.erro:
        // Sessão morta no servidor: volta ao login em vez de mostrar erro.
        if (rep.erro != null && rep.erro!.contains('Sessão') && aoExpirar != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => aoExpirar!());
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 38, color: AdminCores.vermelho),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível carregar o acervo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rep.erro ?? 'Erro desconhecido.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminCores.textoSecundario,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fonte: ${rep.fonte.descricao}',
                      style: const TextStyle(fontSize: 11.5, color: AdminCores.textoSecundario),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: rep.carregar,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case EstadoCarga.inicial:
      case EstadoCarga.carregando:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.4),
                SizedBox(height: 16),
                Text(
                  'Carregando o acervo...',
                  style: TextStyle(fontSize: 13.5, color: AdminCores.textoSecundario),
                ),
              ],
            ),
          ),
        );
    }
  }
}


/// Faz o coletor do painel funcionar como destino de telemetria do núcleo.
class _ColetorDoPainel implements ColetorAnalytics {
  _ColetorDoPainel(this._painel);

  final ColetorAnaliticoPainel _painel;

  @override
  String get descricao => 'painel administrativo';
  @override
  String? get ultimoErro => _painel.ultimoErro;
  @override
  void registrar(EventoAnalitico evento) => _painel.registrar(evento);
  @override
  void registrarVarios(Iterable<EventoAnalitico> eventos) {
    for (final e in eventos) {
      _painel.registrar(e);
    }
  }
  @override
  Future<void> encerrar() async {}
}


/// Moldura mínima que mostra quem está conectado e permite sair.
/// Aviso de inatividade: aparece faltando 2 minutos e deixa continuar.
///
/// Sem ele, o operador perdia o que estava digitando quando a sessão caísse.
class _AvisoInatividade extends StatelessWidget {
  const _AvisoInatividade({
    required this.restante,
    required this.aoContinuar,
    required this.aoSair,
  });

  final Duration restante;
  final VoidCallback aoContinuar;
  final Future<void> Function() aoSair;

  @override
  Widget build(BuildContext context) {
    final minutos = restante.inMinutes;
    final segundos = restante.inSeconds % 60;
    final falta = minutos > 0
        ? '${minutos}min ${segundos.toString().padLeft(2, '0')}s'
        : '${segundos}s';

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Material(
            color: AdminCores.barra,
            borderRadius: BorderRadius.circular(AdminRaios.medio),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sessão por expirar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sem atividade, você será desconectado em $falta.',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: aoSair,
                    style: TextButton.styleFrom(foregroundColor: Colors.white60),
                    child: const Text('Sair'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: aoContinuar,
                    child: const Text('Continuar conectado'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
