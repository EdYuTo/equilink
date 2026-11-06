import 'package:equilink_core/equilink_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a ficha do ancestral sobrevive à ida e volta em JSON', () {
    const ficha = Ancestral(
      nome: 'MCM HAMMERTIME',
      registro: 'P166842',
      nascimento: '2012-03-04',
      premiacaoProvas: 86410.5,
      premiacaoReprodutor: 1200,
      filhosPremiados: 41,
      fonte: 'SGP',
      atualizadoEm: '2026-11-06',
    );
    const filho = Ancestral(nome: 'A', registro: 'B', pai: ficha);
    final volta = Ancestral.fromJson(filho.toJson());
    expect(volta.toJson(), filho.toJson());
    expect(volta.pai!.filhosPremiados, 41);

    // Editar o nome do pai no painel não pode perder a ficha.
    final editado = ficha.copiarCom(nome: 'NOVO');
    expect(editado.premiacaoProvas, 86410.5);
    expect(editado.fonte, 'SGP');
  });

  test('ancestral antigo, sem ficha, continua igual', () {
    const antigo = Ancestral(nome: 'A', registro: 'B');
    expect(Ancestral.fromJson(antigo.toJson()).toJson(), {'nome': 'A', 'registro': 'B'});
  });
}
