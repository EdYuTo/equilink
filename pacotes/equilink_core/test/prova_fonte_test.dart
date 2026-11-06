import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final prova = Prova(
    id: 'p1',
    data: DateTime(2026, 5, 12),
    nome: 'Mega Show',
    local: '',
    categoria: 'Test Horse',
    colocacao: 0,
    tempoSegundos: 18.227,
    inscritos: 0,
    fonte: 'HorseSport',
  );

  test('prova sem colocação informada não conta como pódio', () {
    expect(prova.temColocacao, isFalse);
    expect(prova.podio, isFalse);
    expect(prova.vitoria, isFalse);
    expect(colocacao(0), '—');
    expect(colocacao(3), '3º');
  });

  test('a fonte sobrevive à ida e volta e à edição', () {
    expect(Prova.fromJson(prova.toJson()).fonte, 'HorseSport');
    expect(prova.copiarCom(nome: 'Outro').fonte, 'HorseSport');
  });

  test('prova cadastrada à mão não envia fonte', () {
    final manual = Prova(
      id: 'p2',
      data: DateTime(2026, 1, 1),
      nome: 'A',
      local: 'B',
      categoria: 'C',
      colocacao: 1,
      tempoSegundos: 1,
      inscritos: 1,
    );
    expect(manual.toJson().containsKey('fonte'), isFalse);
  });
}
