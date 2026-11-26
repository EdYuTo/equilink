import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// EQL-017: a data de hoje vem de um relógio, não de uma constante.
void main() {
  test('sem relógio informado, hoje é a data real', () {
    final antes = DateTime.now();
    final hoje = Repositorio(FonteMemoria()).hoje;
    expect(hoje.isBefore(antes), isFalse);
    expect(hoje.difference(antes).inSeconds, lessThan(5));
  });

  test('o relógio injetado define hoje e as datas gravadas', () async {
    var agora = DateTime(2027, 3, 5, 9, 30);
    final repo = Repositorio(FonteMemoria(), agora: () => agora);
    await repo.carregar();
    expect(repo.hoje, DateTime(2027, 3, 5, 9, 30));

    await repo.adicionarBaia(cavaloId: 'estrela-guia', status: StatusBaia.emDia);
    expect(repo.baia('06')!.ultimaLimpeza, DateTime(2027, 3, 5, 7));

    // O relógio é lido a cada uso, não só na criação do repositório.
    agora = DateTime(2027, 3, 6, 8);
    await repo.alterarStatusBaia('06', StatusBaia.emDia);
    expect(repo.baia('06')!.ultimaLimpeza, DateTime(2027, 3, 6, 7, 10));
  });

  test('idade sem referência usa a data real', () {
    final agora = DateTime.now();
    final nascimento = DateTime(agora.year - 3, agora.month, 1);
    expect(idade(nascimento), '3 anos');
  });
}
