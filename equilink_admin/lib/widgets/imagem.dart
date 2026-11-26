import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Tipos de imagem aceitos pela API; a mesma lista vive em `TIPOS_MIDIA` no Worker.
const tiposImagemAceitos = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'gif': 'image/gif',
};

/// Imagem de uma foto do acervo, venha ela de onde vier.
///
/// - `http(s)://`: arquivo enviado ao R2, carregado pela rede.
/// - `data:`: o que a fonte em memória (demonstração) devolve no envio.
/// - qualquer outra coisa, inclusive os `assets/img/...` do acervo semente,
///   que só o aplicativo do usuário empacota: mostra [semImagem].
///
/// Antes as miniaturas do painel usavam `Image.asset` para tudo e nenhuma
/// foto enviada chegava a aparecer.
class ImagemAcervo extends StatefulWidget {
  const ImagemAcervo(this.endereco, {super.key, required this.semImagem, this.fit = BoxFit.cover});

  final String endereco;
  final Widget semImagem;
  final BoxFit fit;

  static bool remota(String endereco) =>
      endereco.startsWith('http://') || endereco.startsWith('https://');

  @override
  State<ImagemAcervo> createState() => _ImagemAcervoState();
}

class _ImagemAcervoState extends State<ImagemAcervo> {
  // Decodificado uma vez por endereço: bytes novos a cada build fariam o
  // Image.memory decodificar e piscar de novo.
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decodificar(widget.endereco);
  }

  @override
  void didUpdateWidget(ImagemAcervo antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.endereco != widget.endereco) _bytes = _decodificar(widget.endereco);
  }

  static Uint8List? _decodificar(String endereco) {
    if (!endereco.startsWith('data:')) return null;
    try {
      return UriData.parse(endereco).contentAsBytes();
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        errorBuilder: (context, erro, pilha) => widget.semImagem,
      );
    }
    if (ImagemAcervo.remota(widget.endereco)) {
      return Image.network(
        widget.endereco,
        fit: widget.fit,
        errorBuilder: (context, erro, pilha) => widget.semImagem,
        loadingBuilder: (context, filho, progresso) => progresso == null ? filho : widget.semImagem,
      );
    }
    return widget.semImagem;
  }
}
