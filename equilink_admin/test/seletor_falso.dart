import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Arquivo escolhido de mentira, com bytes em memória.
final class ArquivoFalso extends PlatformFile {
  ArquivoFalso(this.name, this.bytes);

  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.parse('memoria:///$name');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

/// Seletor de arquivos que devolve sempre o mesmo [arquivo], sem abrir janela.
class SeletorFalso extends FilePickerPlatform {
  SeletorFalso(this.arquivo);

  final PlatformFile? arquivo;
  int escolhas = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    escolhas += 1;
    return arquivo;
  }

  /// Instala o seletor durante o teste e devolve o original no fim.
  static SeletorFalso instalar(PlatformFile? arquivo, void Function(void Function()) aoTerminar) {
    final original = FilePickerPlatform.instance;
    final falso = SeletorFalso(arquivo);
    FilePickerPlatform.instance = falso;
    aoTerminar(() => FilePickerPlatform.instance = original);
    return falso;
  }
}

/// PNG de 1×1 pixel, transparente.
final pngMinimo = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
