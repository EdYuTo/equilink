import 'package:web/web.dart' as web;

/// Sai do aplicativo e abre [endereco] na mesma aba.
void abrirEndereco(String endereco) => web.window.location.assign(endereco);
