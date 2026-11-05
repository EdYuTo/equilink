import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:equilink_ui/equilink_ui.dart';

import '../core/tema.dart';
import '../rotas.dart';
import '../core/sessao_escopo.dart';
import '../widgets/comuns.dart';

/// Tela de acesso do aplicativo.
///
/// Diferente do painel, entrar aqui é **opcional**: o visitante continua vendo a
/// vitrine. O login serve para o proprietário ver o manejo das baias, que a API
/// só entrega ao dono do animal.
class TelaAcesso extends StatelessWidget {
  const TelaAcesso({super.key});

  @override
  Widget build(BuildContext context) {
    final escopo = SessaoEscopo.de(context);
    final api = escopo.sessaoApi;

    if (api == null) {
      // Sem backend (demonstração em memória) não há o que autenticar.
      return Scaffold(
        backgroundColor: Cores.fundo,
        appBar: AppBar(title: const Text('Acesso do proprietário')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(Espacos.x5),
            child: Text(
              'Esta versão está usando dados de demonstração, sem backend. '
              'O acesso do proprietário fica disponível quando o aplicativo '
              'aponta para a API.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Cores.textoSecundario, height: 1.5),
            ),
          ),
        ),
      );
    }

    if (escopo.autenticado) return const _JaAutenticado();

    return FormularioAcesso(
      sessaoApi: api,
      paleta: paletaDoApp,
      fundo: Cores.fundo,
      aoEntrar: escopo.entrar,
      titulo: 'Acesso do proprietário',
      subtitulo: 'Entre para gerenciar os seus cavalos.',
      aoVoltar: () {
        // Quem abriu o link direto não tem para onde voltar: vai ao perfil.
        final navegador = Navigator.of(context);
        navegador.canPop() ? navegador.pop() : context.go(Rotas.perfil);
      },
    );
  }
}

/// Quem já entrou vê seus dados e a saída.
class _JaAutenticado extends StatelessWidget {
  const _JaAutenticado();

  @override
  Widget build(BuildContext context) {
    final escopo = SessaoEscopo.de(context);
    final sessao = escopo.sessao!;

    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(title: const Text('Acesso do proprietário')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(Espacos.x4),
            child: Painel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 22, color: Cores.verde),
                      const SizedBox(width: Espacos.x2),
                      Expanded(
                        child: Text(
                          sessao.usuario,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Cores.texto,
                          ),
                        ),
                      ),
                      Etiqueta(sessao.papelRotulo, cor: Cores.verde, fundo: Cores.verdeFundo),
                    ],
                  ),
                  const SizedBox(height: Espacos.x3),
                  const Text(
                    'Você está vendo o manejo completo das baias, incluindo '
                    'ocorrências e observações dos seus cavalos.',
                    style: TextStyle(fontSize: 12.5, color: Cores.textoSecundario, height: 1.5),
                  ),
                  const SizedBox(height: Espacos.x4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await escopo.sair();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sair'),
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
