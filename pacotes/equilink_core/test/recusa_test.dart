import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonte que recusa toda gravação, como a API com sessão vencida ou papel
/// sem permissão.
class _FonteQueRecusa extends FonteMemoria {
  @override
  Future<void> salvarCavalo(Cavalo cavalo) async => throw const ErroPermissao('Seu perfil não permite isso.');

  @override
  Future<void> removerCavalo(String id) async => throw const ErroAutenticacao('Sessão expirada ou não iniciada.');

  @override
  Future<void> salvarProva(String cavaloId, Prova prova) async =>
      throw const ErroPermissao('Seu perfil não permite isso.');

  @override
  Future<void> removerProva(String cavaloId, String provaId) async =>
      throw const ErroPermissao('Seu perfil não permite isso.');
}

/// EQL-013: uma gravação recusada não pode continuar aparecendo como feita.
void main() {
  late Repositorio repo;
  late Acervo antes;

  setUp(() async {
    repo = Repositorio(_FonteQueRecusa());
    await repo.carregar();
    antes = repo.acervo;
  });

  test('cavalo editado volta ao que era quando a API recusa', () async {
    final cavalo = repo.cavalo!;
    final ok = await repo.salvarCavalo(cavalo.copiarCom(nome: 'NOME RECUSADO'));
    expect(ok, isFalse);
    expect(repo.cavaloPorId(cavalo.id)!.nome, cavalo.nome);
    expect(repo.erro, 'Seu perfil não permite isso.');
  });

  test('cavalo removido reaparece quando a API recusa', () async {
    final id = repo.cavalo!.id;
    expect(await repo.removerCavalo(id), isFalse);
    expect(repo.cavaloPorId(id), isNotNull);
    expect(repo.acervo.baias.length, antes.baias.length, reason: 'a baia dele também volta');
  });

  test('prova nova some e prova removida volta quando a API recusa', () async {
    final cavalo = repo.cavalo!;
    final nova = Prova(
      id: 'p-recusada',
      data: DateTime(2026, 1, 1),
      nome: 'X',
      local: '',
      categoria: '',
      colocacao: 1,
      tempoSegundos: 17,
      inscritos: 0,
    );
    expect(await repo.salvarProva(cavalo.id, nova), isFalse);
    expect(repo.cavaloPorId(cavalo.id)!.provas.any((p) => p.id == 'p-recusada'), isFalse);

    final primeira = cavalo.provas.first.id;
    expect(await repo.removerProva(cavalo.id, primeira), isFalse);
    expect(repo.cavaloPorId(cavalo.id)!.provas.any((p) => p.id == primeira), isTrue);
  });
}
