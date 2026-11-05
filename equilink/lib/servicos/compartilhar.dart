import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:equilink_core/equilink_core.dart';

/// Conteúdo textual e visual compartilhado do cavalo.
abstract final class IdentidadeCavalo {
  /// Endereço público que o QR Code da placa aponta.
  static String url(ContextoPerfil perfil) => perfil.urlPublica;

  static String texto(Cavalo cavalo) =>
      '${cavalo.nome} • ${cavalo.raca} • Registro ${cavalo.registro}\n'
      'Sexo: ${cavalo.sexo.rotulo} | Nascimento: ${_data(cavalo.nascimento)} | '
      'Pelagem: ${cavalo.pelagem}\n'
      'Proprietário: ${cavalo.proprietario.nome} — ${cavalo.proprietario.fazenda}\n'
      'Criador: ${cavalo.criador.nome} — ${cavalo.criador.cidade}\n'
      '${ContextoPerfil(cavalo: cavalo).urlPublica}';

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Dados do perfil público gerado para um cavalo.
class ContextoPerfil {
  const ContextoPerfil({required this.cavalo});

  final Cavalo cavalo;

  /// Link público do animal, usado no QR da placa e ao compartilhar.
  ///
  /// O registro vai em maiúsculas por ser o identificador oficial do animal; a
  /// rota `/cavalo/:registro` procura sem diferenciar caixa.
  String get urlPublica => '${Ambiente.sitePublico}/cavalo/${cavalo.registro}';
}

abstract final class CompartilhamentoPerfil {
  static Future<void> compartilhar(BuildContext context, Repositorio repositorio) async {
    final cavalo = repositorio.cavaloObrigatorio;
    final texto = IdentidadeCavalo.texto(cavalo);
    await SharePlus.instance.share(
      ShareParams(
        text: texto,
        subject: 'Perfil de ${cavalo.nome}',
        sharePositionOrigin: _origem(context),
      ),
    );
  }

  static Rect? _origem(BuildContext context) {
    final caixa = context.findRenderObject();
    if (caixa is! RenderBox || !caixa.hasSize) return null;
    return caixa.localToGlobal(Offset.zero) & caixa.size;
  }
}

/// QR Code do cavalo, reutilizado na placa e nas ações rápidas.
class QrDoCavalo extends StatelessWidget {
  const QrDoCavalo({
    super.key,
    required this.dados,
    this.tamanho = 200,
    this.cor = Colors.black,
    this.fundo = Colors.white,
    this.padding = 8,
  });

  final String dados;
  final double tamanho;
  final Color cor;
  final Color fundo;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: QrImageView(
        data: dados,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        padding: EdgeInsets.all(padding),
        backgroundColor: fundo,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: cor),
        dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: cor),
        semanticsLabel: 'QR Code de identificação do cavalo',
      ),
    );
  }
}
