import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Marca "— EQUILINK —": dois traços e o nome no meio.
///
/// A fonte é provisória (Libre Baskerville, licença OFL) até recebermos a
/// definitiva.
class LogoEquilink extends StatelessWidget {
  const LogoEquilink({super.key, this.tamanho = 15, this.traco = 30});

  final double tamanho;

  /// Comprimento de cada traço lateral.
  final double traco;

  @override
  Widget build(BuildContext context) {
    Widget linha() => Container(width: traco, height: 1.5, color: Cores.douradoClaro);

    return Semantics(
      label: 'EquiLink',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          linha(),
          const SizedBox(width: 10),
          Text(
            'EQUILINK',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'LibreBaskerville',
              fontVariations: const [FontVariation('wght', 700)],
              fontSize: tamanho,
              letterSpacing: tamanho * 0.2,
              color: Cores.douradoClaro,
            ),
          ),
          const SizedBox(width: 10 - 3),
          linha(),
        ],
      ),
    );
  }
}
