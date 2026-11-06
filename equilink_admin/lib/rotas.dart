import 'core/navegar_stub.dart' if (dart.library.js_interop) 'core/navegar_web.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:equilink_core/equilink_core.dart';

import 'core/escopo.dart';
import 'core/tema.dart';
import 'telas/analytics.dart';
import 'telas/cavalos.dart';
import 'telas/novo_cavalo.dart';
import 'telas/editor.dart';
import 'telas/fonte.dart';
import 'telas/painel.dart';
import 'telas/provas.dart';
import 'widgets/sugestoes.dart';

/// Rotas do painel administrativo.
abstract final class RotasAdmin {
  static const painel = '/';
  static const cavalos = '/cavalos';
  static const provas = '/provas';
  static const fonte = '/fonte';
  static const analytics = '/analytics';

  /// Editor de um cavalo específico (`/cavalos/<id>`).
  static String cavalo(String id) => '/cavalos/$id';

  /// Assistente de cadastro, fora da lista para não colidir com `/cavalos/:id`.
  static const novoCavalo = '/cavalos/novo';
}

GoRouter criarRoteadorAdmin() {
  return GoRouter(
    initialLocation: RotasAdmin.painel,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _Moldura(rotaAtual: state.uri.path, child: child),
        routes: [
          GoRoute(path: RotasAdmin.painel, builder: (context, state) => const TelaPainel()),
          GoRoute(
            path: RotasAdmin.cavalos,
            builder: (context, state) => const TelaCavalos(),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (context, state) => const TelaNovoCavalo(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    TelaCavaloEditor(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: RotasAdmin.provas, builder: (context, state) => const TelaProvas()),
          GoRoute(path: RotasAdmin.fonte, builder: (context, state) => const TelaFonte()),
          GoRoute(
            path: RotasAdmin.analytics,
            builder: (context, state) => const TelaAnalytics(),
          ),
        ],
      ),
    ],
  );
}

class _Item {
  const _Item(this.rotulo, this.icone, this.rota, {this.endereco});

  final String rotulo;
  final IconData icone;
  final String rota;

  /// Página fora do aplicativo. Quando presente, o item sai do painel.
  final String? endereco;
}

const _itens = <_Item>[
  _Item('Visão geral', Icons.dashboard_outlined, RotasAdmin.painel),
  _Item('Cavalos', Icons.pets_outlined, RotasAdmin.cavalos),
  _Item('Provas', Icons.emoji_events_outlined, RotasAdmin.provas),
  _Item('Analytics', Icons.insights_outlined, RotasAdmin.analytics),
  _Item('Fonte de dados', Icons.storage_outlined, RotasAdmin.fonte),
  _Item(
    'Etiquetas',
    Icons.sell_outlined,
    '/etiquetas',
    endereco: 'https://painel.equilinkapp.com.br/etiquetas',
  ),
];

/// Moldura do painel: barra lateral fixa em telas largas, gaveta em telas
/// estreitas.
class _Moldura extends StatefulWidget {
  const _Moldura({required this.rotaAtual, required this.child});

  final String rotaAtual;
  final Widget child;

  @override
  State<_Moldura> createState() => _MolduraState();
}

class _MolduraState extends State<_Moldura> {
  /// Painel de sugestões aberto.
  bool _sugestoesAbertas = false;

  @override
  Widget build(BuildContext context) {
    final rotaAtual = widget.rotaAtual;
    final child = widget.child;
    final rep = AdminEscopo.de(context);
    final largura = MediaQuery.sizeOf(context).width;
    final usarGaveta = largura < 860;

    final conteudo = Column(
      children: [
        if (rep.erro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AdminCores.vermelhoFundo,
                  borderRadius: BorderRadius.circular(AdminRaios.pequeno),
                  border: Border.all(color: AdminCores.vermelho.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 17, color: AdminCores.vermelho),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rep.erro!,
                        style: const TextStyle(fontSize: 12.5, color: AdminCores.vermelho),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dispensar',
                      onPressed: rep.limparErro,
                      icon: const Icon(Icons.close, size: 16, color: AdminCores.vermelho),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (!_sugestoesAbertas)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: _CantoInferior(
                    aoAbrirSugestoes: () => setState(() => _sugestoesAbertas = true),
                  ),
                ),
              if (_sugestoesAbertas)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: PainelSugestoes(
                    rota: rotaAtual,
                    aberto: true,
                    aoAlternar: () => setState(() => _sugestoesAbertas = false),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (usarGaveta) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administração'),
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: AdminCores.barra,
          child: SafeArea(
            child: _Menu(rotaAtual: rotaAtual, aoNavegar: (rota) {
              Navigator.of(context).pop();
              context.go(rota);
            }),
          ),
        ),
        body: conteudo,
      );
    }

    return Scaffold(
      backgroundColor: AdminCores.fundo,
      body: Row(
        children: [
          SizedBox(
            width: 248,
            child: ColoredBox(
              color: AdminCores.barra,
              child: SafeArea(
                child: _Menu(rotaAtual: rotaAtual, aoNavegar: (rota) => context.go(rota)),
              ),
            ),
          ),
          Expanded(child: conteudo),
        ],
      ),
    );
  }
}

/// Canto inferior direito: sugestões em cima, sessão abaixo.
///
/// Antes, o selo de sessão (desenhado pelo portão de autenticação) e o botão de
/// sugestões (desenhado pela moldura) eram `Positioned` independentes no mesmo
/// canto e se sobrepunham. Agora um único dono empilha os dois.
class _CantoInferior extends StatelessWidget {
  const _CantoInferior({required this.aoAbrirSugestoes});

  final VoidCallback aoAbrirSugestoes;

  @override
  Widget build(BuildContext context) {
    final sessao = SessaoAdminEscopo.talvezDe(context);
    final temSessao = sessao?.sessao != null && sessao?.aoSair != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _BotaoSugestoes(aoTocar: aoAbrirSugestoes),
        if (temSessao) ...[
          const SizedBox(height: 10),
          _SeloSessao(sessao: sessao!.sessao!, aoSair: sessao.aoSair!),
        ],
      ],
    );
  }
}

/// Selo discreto de quem está conectado; clicar encerra a sessão.
class _SeloSessao extends StatelessWidget {
  const _SeloSessao({required this.sessao, required this.aoSair});

  final Sessao sessao;
  final Future<void> Function() aoSair;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminCores.barra,
      borderRadius: BorderRadius.circular(AdminRaios.total),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdminRaios.total),
        onTap: aoSair,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '${sessao.usuario} · ${sessao.papelRotulo} · sair',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão que abre as sugestões da página atual.
///
/// **Fora do design system, de propósito.** O painel inteiro é verde-escuro e
/// dourado discreto; este botão precisa ser notado por quem tem a ideia na hora
/// e não sabe que existe um lugar para escrever. Por isso cor saturada, sombra
/// alta e um pulso lento — sem repetir nenhum token de [AdminCores].
class _BotaoSugestoes extends StatefulWidget {
  const _BotaoSugestoes({required this.aoTocar});

  final VoidCallback aoTocar;

  @override
  State<_BotaoSugestoes> createState() => _BotaoSugestoesState();
}

class _BotaoSugestoesState extends State<_BotaoSugestoes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  /// Quantos ciclos o pulso faz antes de parar.
  ///
  /// `repeat()` infinito impediria `pumpAndSettle` de terminar em qualquer
  /// teste de widget. Três ciclos chamam atenção de quem chega e depois
  /// deixam o botão em repouso.
  static const _ciclos = 3;
  int _feitos = 0;

  /// Amarelo de destaque: existe só aqui, deliberadamente alheio ao tema.
  static const _amarelo = Color(0xFFFFC23D);
  static const _tinta = Color(0xFF1A1505);

  @override
  void initState() {
    super.initState();
    _pulso.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _feitos += 1;
        if (_feitos >= _ciclos) {
          _pulso.stop();
          _pulso.value = 0;
        } else {
          _pulso.reverse();
        }
      }
    });
    _pulso.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeita quem pediu menos movimento no sistema.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulso.stop();
      _pulso.value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, filho) {
        final t = Curves.easeInOut.transform(_pulso.value);
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _amarelo,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _amarelo.withValues(alpha: 0.25 + 0.35 * t),
                  blurRadius: 12 + 14 * t,
                  spreadRadius: 1 + 3 * t,
                ),
                const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: filho,
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lightbulb, size: 19, color: _tinta),
              SizedBox(width: 9),
              Text(
                'Sugestões',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: _tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.rotaAtual, required this.aoNavegar});

  final String rotaAtual;
  final ValueChanged<String> aoNavegar;

  @override
  Widget build(BuildContext context) {
    final rep = AdminEscopo.de(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EQUILINK',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Painel administrativo',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
        for (final item in _itens)
          _Destino(
            item: item,
            ativo: rotaAtual == item.rota ||
                (item.rota != RotasAdmin.painel && rotaAtual.startsWith(item.rota)),
            aoTocar: () {
              final endereco = item.endereco;
              endereco == null ? aoNavegar(item.rota) : abrirEndereco(endereco);
            },
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FONTE DE DADOS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rep.fonte.descricao,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 3),
              Text(
                rep.permiteEscrita ? 'Escrita habilitada' : 'Somente leitura',
                style: TextStyle(
                  fontSize: 11,
                  color: rep.permiteEscrita ? AdminCores.douradoClaro : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Destino extends StatelessWidget {
  const _Destino({required this.item, required this.ativo, required this.aoTocar});

  final _Item item;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: ativo ? Colors.white.withValues(alpha: 0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRaios.pequeno),
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(AdminRaios.pequeno),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.icone, size: 19, color: ativo ? AdminCores.douradoClaro : Colors.white60),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.rotulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                      color: ativo ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
