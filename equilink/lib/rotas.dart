import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:equilink_core/equilink_core.dart';
import 'core/tema.dart';
import 'escopo.dart';
import 'core/sessao_escopo.dart';
import 'telas/baia_detalhe.dart';
import 'telas/baias.dart';
import 'telas/genealogia.dart';
import 'telas/historico.dart';
import 'telas/midias.dart';
import 'telas/perfil.dart';
import 'telas/acesso.dart';
import 'telas/placa.dart';
import 'widgets/marca.dart';


/// Largura máxima do conteúdo em telas grandes (web e tablets).
const double larguraMaximaConteudo = 760;

/// Largura a partir da qual a navegação migra da barra inferior para a barra
/// lateral.
const double larguraNavegacaoLateral = 900;

class Rotas {
  static const perfil = '/perfil';
  static const genealogia = '/genealogia';
  static const historico = '/historico';
  static const midias = '/midias';
  static const baias = '/baias';
  static const placa = '/placa';

  /// Acesso do proprietário (opcional: o app funciona anônimo).
  static const acesso = '/acesso';

  /// Perfil de um animal específico, alvo do QR Code da placa.
  static String cavaloPorRegistro(String registro) => '/cavalo/$registro';

  static String baia(String numero) => '/baias/$numero';
}

/// Cria o roteador. [aoNavegar] recebe cada rota visitada, para a telemetria
/// registrar a jornada sem que as telas conheçam o analytics.
///
/// [baias] liga o módulo de baias e manejo, que fica fora da v1. O código segue
/// no projeto para a versão futura.
GoRouter criarRoteador({void Function(String rota)? aoNavegar, bool baias = false}) {
  final chaveRaiz = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: chaveRaiz,
    initialLocation: Rotas.perfil,
    observers: [
      if (aoNavegar != null)
        _ObservadorNavegacao(aoNavegar),
    ],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _MolduraPrincipal(
          navigationShell: navigationShell,
          itens: baias ? _itens : _itens.sublist(0, 4),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.perfil,
                builder: (context, state) => const TelaPerfil(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.genealogia,
                builder: (context, state) => const TelaGenealogia(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.historico,
                builder: (context, state) => const TelaHistorico(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Rotas.midias, builder: (context, state) => const TelaMidias()),
            ],
          ),
          if (baias) StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.baias,
                builder: (context, state) => const TelaBaias(),
                routes: [
                  GoRoute(
                    path: ':numero',
                    builder: (context, state) =>
                        TelaBaiaDetalhe(numero: state.pathParameters['numero']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Links antigos para o módulo desligado abrem o perfil, sem erro.
      if (!baias)
        GoRoute(
          path: '/baias/:numero',
          redirect: (context, state) => Rotas.perfil,
        ),
      if (!baias)
        GoRoute(
          path: Rotas.baias,
          redirect: (context, state) => Rotas.perfil,
        ),
      GoRoute(
        path: Rotas.placa,
        parentNavigatorKey: chaveRaiz,
        builder: (context, state) => const PortaoAcesso(child: TelaPlaca()),
      ),
      GoRoute(
        path: Rotas.acesso,
        parentNavigatorKey: chaveRaiz,
        builder: (context, state) => const TelaAcesso(),
      ),
      // Alvo do QR Code da placa: /cavalo/<registro>. Redireciona para o
      // perfil, que passa a exibir o animal pedido em vez do destaque.
      GoRoute(
        path: '/cavalo/:registro',
        parentNavigatorKey: chaveRaiz,
        redirect: (context, state) {
          final registro = state.pathParameters['registro'] ?? '';
          final rep = RepositorioEscopo.de(context);
          rep.focarRegistro(registro);
          return Rotas.perfil;
        },
      ),
    ],
  );
}

/// Mostra [child] só para quem entrou; os demais veem a tela de acesso.
///
/// Ao entrar, a sessão muda e o conteúdo aparece sem nova navegação. Ao
/// recarregar a página, o acesso aparece por um instante até a sessão ser
/// restaurada, e o conteúdo protegido nunca é desenhado antes disso.
class PortaoAcesso extends StatelessWidget {
  const PortaoAcesso({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SessaoEscopo.de(context).autenticado ? child : const TelaAcesso();
}

/// Observa as trocas de rota e as repassa para a telemetria.
class _ObservadorNavegacao extends NavigatorObserver {
  _ObservadorNavegacao(this.aoNavegar);

  final void Function(String rota) aoNavegar;

  @override
  void didPush(Route<dynamic> rota, Route<dynamic>? anterior) {
    super.didPush(rota, anterior);
    final nome = rota.settings.name;
    if (nome != null) aoNavegar(nome);
  }
}

class _ItemNavegacao {
  const _ItemNavegacao(this.rotulo, this.icone, this.iconeAtivo);

  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
}

const _itens = <_ItemNavegacao>[
  _ItemNavegacao('Perfil', Icons.badge_outlined, Icons.badge),
  _ItemNavegacao('Genealogia', Icons.account_tree_outlined, Icons.account_tree),
  _ItemNavegacao('Histórico', Icons.emoji_events_outlined, Icons.emoji_events),
  _ItemNavegacao('Fotos', Icons.photo_library_outlined, Icons.photo_library),
  _ItemNavegacao('Baias', Icons.home_work_outlined, Icons.home_work),
];

class _MolduraPrincipal extends StatelessWidget {
  const _MolduraPrincipal({required this.navigationShell, required this.itens});

  final StatefulNavigationShell navigationShell;
  final List<_ItemNavegacao> itens;

  void _selecionar(int indice) {
    navigationShell.goBranch(
      indice,
      initialLocation: indice == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repositorio = RepositorioEscopo.de(context);
    final largura = MediaQuery.sizeOf(context).width;
    final usarLateral = largura >= larguraNavegacaoLateral;

    final conteudo = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: larguraMaximaConteudo),
        child: navigationShell,
      ),
    );

    if (usarLateral) {
      return Scaffold(
        backgroundColor: Cores.escuro,
        body: Row(
          children: [
            _BarraLateral(
              indice: navigationShell.currentIndex,
              aoSelecionar: _selecionar,
              itens: itens,
              pendencias: repositorio.manejoPendenteTotal,
            ),
            Expanded(child: ColoredBox(color: Cores.fundo, child: conteudo)),
          ],
        ),
      );
    }

    return Scaffold(
      body: conteudo,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1F3532))),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _selecionar,
          destinations: [
            for (var i = 0; i < itens.length; i++)
              NavigationDestination(
                icon: _IconeComSelo(
                  icone: itens[i].icone,
                  contagem: i == 4 ? repositorio.manejoPendenteTotal : 0,
                ),
                selectedIcon: _IconeComSelo(
                  icone: itens[i].iconeAtivo,
                  cor: Cores.douradoClaro,
                  contagem: i == 4 ? repositorio.manejoPendenteTotal : 0,
                ),
                label: itens[i].rotulo,
              ),
          ],
        ),
      ),
    );
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral({
    required this.indice,
    required this.aoSelecionar,
    required this.itens,
    required this.pendencias,
  });

  final int indice;
  final ValueChanged<int> aoSelecionar;
  final List<_ItemNavegacao> itens;
  final int pendencias;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      color: Cores.escuro,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacos.x5, Espacos.x6, Espacos.x4, Espacos.x5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LogoEquilink(tamanho: 13, traco: 16),
                        SizedBox(height: 4),
                        Text(
                          'Meus cavalos',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const BotaoAcesso(),
                ],
              ),
            ),
            for (var i = 0; i < itens.length; i++)
              _DestinoLateral(
                item: itens[i],
                ativo: i == indice,
                contagem: i == 4 ? pendencias : 0,
                aoTocar: () => aoSelecionar(i),
              ),
            const Spacer(),
            if (itens.length > 4) Padding(
              padding: const EdgeInsets.all(Espacos.x5),
              child: Text(
                pendencias == 0
                    ? 'Manejo do dia concluído'
                    : plural(pendencias, 'tarefa de manejo pendente', 'tarefas de manejo pendentes'),
                style: const TextStyle(fontSize: 11.5, color: Colors.white54, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinoLateral extends StatelessWidget {
  const _DestinoLateral({
    required this.item,
    required this.ativo,
    required this.aoTocar,
    required this.contagem,
  });

  final _ItemNavegacao item;
  final bool ativo;
  final VoidCallback aoTocar;
  final int contagem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espacos.x3, vertical: 2),
      child: Material(
        color: ativo ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(Raios.pequeno),
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(Raios.pequeno),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacos.x3, vertical: 12),
            child: Row(
              children: [
                Icon(
                  ativo ? item.iconeAtivo : item.icone,
                  size: 20,
                  color: ativo ? Cores.douradoClaro : Colors.white60,
                ),
                const SizedBox(width: Espacos.x3),
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
                if (contagem > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Cores.dourado,
                      borderRadius: BorderRadius.circular(Raios.total),
                    ),
                    child: Text(
                      '$contagem',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Cores.escuro,
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

class _IconeComSelo extends StatelessWidget {
  const _IconeComSelo({required this.icone, this.contagem = 0, this.cor});

  final IconData icone;
  final int contagem;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    if (contagem == 0) {
      return Icon(icone, color: cor);
    }
    return ExcludeSemantics(
      child: Badge(
        label: Text('$contagem'),
        backgroundColor: Cores.dourado,
        textColor: Cores.escuro,
        child: Icon(icone, color: cor),
      ),
    );
  }
}

/// Selo de acesso: mostra o usuário quando conectado, ou o convite para entrar.
///
/// O aplicativo é público; este é o único ponto de entrada do proprietário.
class BotaoAcesso extends StatelessWidget {
  const BotaoAcesso({super.key});

  @override
  Widget build(BuildContext context) {
    final sessao = SessaoEscopo.de(context);
    final conectado = sessao.autenticado;

    return IconButton(
      tooltip: conectado
          ? 'Conectado como ${sessao.sessao!.usuario}'
          : 'Acesso do proprietário',
      onPressed: () => context.push(Rotas.acesso),
      icon: Icon(
        conectado ? Icons.verified_user : Icons.person_outline,
        size: 22,
        color: conectado ? Cores.verde : Colors.white70,
      ),
    );
  }
}
