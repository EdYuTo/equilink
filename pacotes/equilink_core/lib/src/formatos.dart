/// Formatação de datas, horas e números no padrão brasileiro.
library;

const _meses = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const _mesesAbrev = <String>[
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

const _diasSemana = <String>[
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

String dois(int valor) => valor.toString().padLeft(2, '0');

/// `18/08/2018`
String dataCurta(DateTime data) => '${dois(data.day)}/${dois(data.month)}/${data.year}';

/// `18 de agosto de 2018`
String dataLonga(DateTime data) => '${data.day} de ${_meses[data.month - 1]} de ${data.year}';

/// `18 ago 2018`
String dataMedia(DateTime data) =>
    '${dois(data.day)} ${_mesesAbrev[data.month - 1]} ${data.year}';

/// `quarta-feira, 18 de agosto`
String diaDaSemanaLongo(DateTime data) => '${_diasSemana[data.weekday - 1]}, ${data.day} de '
    '${_meses[data.month - 1]}';

/// `18/08/2018 às 06:30`
String dataHora(DateTime data) => '${dataCurta(data)} às ${dois(data.hour)}:${dois(data.minute)}';

/// `16,742 s` — tempo de prova com milésimos e vírgula decimal.
String tempoProva(double segundos) {
  final inteiros = segundos.floor();
  final milesimos = ((segundos - inteiros) * 1000).round();
  final minutos = inteiros ~/ 60;
  final resto = inteiros % 60;
  final fracao = milesimos.toString().padLeft(3, '0');
  if (minutos > 0) {
    return '$minutos:${dois(resto)},$fracao';
  }
  return '$resto,$fracao';
}

/// `16,742s` — versão compacta para tabelas.
String tempoProvaCompacto(double segundos) => '${tempoProva(segundos)}s';

/// `1,52 m`
String metros(double valor) => '${valor.toStringAsFixed(2).replaceAll('.', ',')} m';

/// `520 kg`
String quilos(int valor) => '$valor kg';

/// `0:32`
String duracaoVideo(int segundos) => '${segundos ~/ 60}:${dois(segundos % 60)}';

/// Idade em anos e meses: `7 anos` / `8 meses` / `1 ano e 3 meses`.
String idade(DateTime nascimento, {DateTime? referencia}) {
  final hoje = referencia ?? DateTime(2026, 10, 14);
  var anos = hoje.year - nascimento.year;
  var meses = hoje.month - nascimento.month;
  if (hoje.day < nascimento.day) meses -= 1;
  if (meses < 0) {
    anos -= 1;
    meses += 12;
  }
  if (anos <= 0) {
    return meses == 1 ? '1 mês' : '$meses meses';
  }
  final textoAnos = anos == 1 ? '1 ano' : '$anos anos';
  if (meses == 0) return textoAnos;
  final textoMeses = meses == 1 ? '1 mês' : '$meses meses';
  return '$textoAnos e $textoMeses';
}

/// `1º`, `2º`, `3º`... usado nas colocações das provas.
String colocacao(int posicao) => posicao > 0 ? '$posicaoº' : '—';

/// `12 provas`
String plural(int quantidade, String singular, String pluralForma) =>
    '$quantidade ${quantidade == 1 ? singular : pluralForma}';

/// Percentual com vírgula: `41,7%`
String percentual(double fracao, {int casas = 1}) =>
    '${(fracao * 100).toStringAsFixed(casas).replaceAll('.', ',')}%';

String telefone(String bruto) {
  final digitos = bruto.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
  }
  if (digitos.length == 10) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
  }
  return bruto;
}
