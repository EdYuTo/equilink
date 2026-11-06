/// Modelos de domínio do EquiLink.
///
/// Todas as entidades são imutáveis e sabem se converter de/para JSON, de
/// modo que qualquer fonte de dados (memória, arquivo, API REST) use o mesmo
/// formato de transporte.
library;

/// Caminhos padrão de mídia usados quando um registro não traz o seu.
///
/// Centralizado para que mover ou renomear um asset não exija caçar strings
/// espalhadas pelas telas.
abstract final class MidiaPadrao {
  /// Imagem usada quando não há foto de perfil cadastrada.
  static const imagem = 'assets/img/hero.jpg';

  /// Capa usada quando um vídeo não traz imagem própria.
  static const capaVideo = 'assets/img/act1.jpg';
}

enum Sexo {
  femea('Fêmea'),
  macho('Macho');

  const Sexo(this.rotulo);
  final String rotulo;

  static Sexo porNome(String? nome) =>
      Sexo.values.firstWhere((v) => v.name == nome, orElse: () => Sexo.femea);
}

/// Situação sanitária/de conservação da baia.
enum StatusBaia {
  emDia('Em dia'),
  manutencao('Manutenção'),
  atencao('Atenção');

  const StatusBaia(this.rotulo);
  final String rotulo;

  static StatusBaia porNome(String? nome) =>
      StatusBaia.values.firstWhere((v) => v.name == nome, orElse: () => StatusBaia.emDia);
}

enum TipoManejo {
  alimentacao('Alimentação'),
  agua('Água'),
  exercicio('Exercício'),
  higiene('Higiene'),
  saude('Saúde');

  const TipoManejo(this.rotulo);
  final String rotulo;

  static TipoManejo porNome(String? nome) =>
      TipoManejo.values.firstWhere((v) => v.name == nome, orElse: () => TipoManejo.alimentacao);
}

enum TipoOcorrencia {
  saude('Saúde'),
  manejo('Manejo'),
  estrutura('Estrutura');

  const TipoOcorrencia(this.rotulo);
  final String rotulo;

  static TipoOcorrencia porNome(String? nome) =>
      TipoOcorrencia.values.firstWhere((v) => v.name == nome, orElse: () => TipoOcorrencia.saude);
}

enum TipoMidia {
  foto,
  video;

  static TipoMidia porNome(String? nome) =>
      TipoMidia.values.firstWhere((v) => v.name == nome, orElse: () => TipoMidia.foto);
}

/// Converte texto ISO-8601 em data, tolerando nulos e formatos inválidos.
DateTime _data(Object? valor, {DateTime? padrao}) {
  if (valor is DateTime) return valor;
  if (valor is String) {
    final lido = DateTime.tryParse(valor);
    if (lido != null) return lido;
  }
  return padrao ?? DateTime(1970);
}

String _iso(DateTime data) => data.toIso8601String();

class Proprietario {
  const Proprietario({
    required this.nome,
    required this.fazenda,
    required this.telefone,
    required this.cidade,
  });

  final String nome;
  final String fazenda;
  final String telefone;
  final String cidade;

  factory Proprietario.fromJson(Map<String, dynamic> j) => Proprietario(
    nome: j['nome'] as String? ?? '',
    fazenda: j['fazenda'] as String? ?? '',
    telefone: j['telefone'] as String? ?? '',
    cidade: j['cidade'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'fazenda': fazenda,
    'telefone': telefone,
    'cidade': cidade,
  };

  Proprietario copiarCom({String? nome, String? fazenda, String? telefone, String? cidade}) =>
      Proprietario(
        nome: nome ?? this.nome,
        fazenda: fazenda ?? this.fazenda,
        telefone: telefone ?? this.telefone,
        cidade: cidade ?? this.cidade,
      );
}

class Criador {
  const Criador({required this.nome, required this.cidade});

  final String nome;
  final String cidade;

  factory Criador.fromJson(Map<String, dynamic> j) =>
      Criador(nome: j['nome'] as String? ?? '', cidade: j['cidade'] as String? ?? '');

  Map<String, dynamic> toJson() => {'nome': nome, 'cidade': cidade};

  Criador copiarCom({String? nome, String? cidade}) =>
      Criador(nome: nome ?? this.nome, cidade: cidade ?? this.cidade);
}

/// Nó da genealogia (pai, mãe, avós, bisavós...).
class Ancestral {
  const Ancestral({
    required this.nome,
    required this.registro,
    this.pelagem,
    this.pai,
    this.mae,
    this.nascimento,
    this.premiacaoProvas,
    this.premiacaoReprodutor,
    this.filhosPremiados,
    this.fonte,
    this.atualizadoEm,
  });

  final String nome;
  final String registro;
  final String? pelagem;
  final Ancestral? pai;
  final Ancestral? mae;

  /// Data de nascimento em AAAA-MM-DD, quando conhecida.
  final String? nascimento;

  /// Premiação do próprio animal em provas.
  final double? premiacaoProvas;

  /// Premiação somada dos filhos, como garanhão ou matriz.
  final double? premiacaoReprodutor;
  final int? filhosPremiados;

  /// De onde vieram os dados da ficha, como "SGP".
  final String? fonte;

  /// Quando os dados da ficha foram consultados, em AAAA-MM-DD.
  final String? atualizadoEm;

  /// Percorre a árvore em largura, da raiz para as folhas.
  Iterable<Ancestral> emLargura() sync* {
    final fila = <Ancestral>[this];
    while (fila.isNotEmpty) {
      final atual = fila.removeAt(0);
      yield atual;
      if (atual.pai != null) fila.add(atual.pai!);
      if (atual.mae != null) fila.add(atual.mae!);
    }
  }

  /// Maior profundidade da árvore a partir deste nó (1 = sem ascendentes).
  int get geracoes {
    final p = pai?.geracoes ?? 0;
    final m = mae?.geracoes ?? 0;
    return 1 + (p > m ? p : m);
  }

  factory Ancestral.fromJson(Map<String, dynamic> j) => Ancestral(
    nome: j['nome'] as String? ?? '',
    registro: j['registro'] as String? ?? '',
    pelagem: j['pelagem'] as String?,
    pai: j['pai'] == null ? null : Ancestral.fromJson(j['pai'] as Map<String, dynamic>),
    mae: j['mae'] == null ? null : Ancestral.fromJson(j['mae'] as Map<String, dynamic>),
    nascimento: j['nascimento'] as String?,
    premiacaoProvas: (j['premiacaoProvas'] as num?)?.toDouble(),
    premiacaoReprodutor: (j['premiacaoReprodutor'] as num?)?.toDouble(),
    filhosPremiados: (j['filhosPremiados'] as num?)?.toInt(),
    fonte: j['fonte'] as String?,
    atualizadoEm: j['atualizadoEm'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'registro': registro,
    if (pelagem != null) 'pelagem': pelagem,
    if (pai != null) 'pai': pai!.toJson(),
    if (mae != null) 'mae': mae!.toJson(),
    if (nascimento != null) 'nascimento': nascimento,
    if (premiacaoProvas != null) 'premiacaoProvas': premiacaoProvas,
    if (premiacaoReprodutor != null) 'premiacaoReprodutor': premiacaoReprodutor,
    if (filhosPremiados != null) 'filhosPremiados': filhosPremiados,
    if (fonte != null) 'fonte': fonte,
    if (atualizadoEm != null) 'atualizadoEm': atualizadoEm,
  };

  Ancestral copiarCom({
    String? nome,
    String? registro,
    String? pelagem,
    Ancestral? pai,
    Ancestral? mae,
  }) => Ancestral(
    nome: nome ?? this.nome,
    registro: registro ?? this.registro,
    pelagem: pelagem ?? this.pelagem,
    pai: pai ?? this.pai,
    mae: mae ?? this.mae,
    nascimento: nascimento,
    premiacaoProvas: premiacaoProvas,
    premiacaoReprodutor: premiacaoReprodutor,
    filhosPremiados: filhosPremiados,
    fonte: fonte,
    atualizadoEm: atualizadoEm,
  );
}

class Prova {
  const Prova({
    required this.id,
    required this.data,
    required this.nome,
    required this.local,
    required this.categoria,
    required this.colocacao,
    required this.tempoSegundos,
    required this.inscritos,
    this.premiacao,
    this.fonte,
  });

  final String id;
  final DateTime data;
  final String nome;
  final String local;
  final String categoria;
  final int colocacao;
  final double tempoSegundos;
  final int inscritos;
  final String? premiacao;

  /// De onde veio o resultado, como "HorseSport". Nulo quando foi cadastrado à mão.
  final String? fonte;

  /// Zero significa que a fonte não informou a colocação.
  bool get temColocacao => colocacao > 0;
  bool get vitoria => colocacao == 1;
  bool get podio => temColocacao && colocacao <= 3;

  factory Prova.fromJson(Map<String, dynamic> j) => Prova(
    id: j['id'] as String? ?? '',
    data: _data(j['data']),
    nome: j['nome'] as String? ?? '',
    local: j['local'] as String? ?? '',
    categoria: j['categoria'] as String? ?? '',
    colocacao: (j['colocacao'] as num?)?.toInt() ?? 0,
    tempoSegundos: (j['tempoSegundos'] as num?)?.toDouble() ?? 0,
    inscritos: (j['inscritos'] as num?)?.toInt() ?? 0,
    premiacao: j['premiacao'] as String?,
    fonte: j['fonte'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': _iso(data),
    'nome': nome,
    'local': local,
    'categoria': categoria,
    'colocacao': colocacao,
    'tempoSegundos': tempoSegundos,
    'inscritos': inscritos,
    if (premiacao != null) 'premiacao': premiacao,
    if (fonte != null) 'fonte': fonte,
  };

  Prova copiarCom({
    String? id,
    DateTime? data,
    String? nome,
    String? local,
    String? categoria,
    int? colocacao,
    double? tempoSegundos,
    int? inscritos,
    String? premiacao,
    String? fonte,
  }) => Prova(
    id: id ?? this.id,
    data: data ?? this.data,
    nome: nome ?? this.nome,
    local: local ?? this.local,
    categoria: categoria ?? this.categoria,
    colocacao: colocacao ?? this.colocacao,
    tempoSegundos: tempoSegundos ?? this.tempoSegundos,
    inscritos: inscritos ?? this.inscritos,
    premiacao: premiacao ?? this.premiacao,
    fonte: fonte ?? this.fonte,
  );
}

class Midia {
  const Midia({
    required this.id,
    required this.tipo,
    required this.arquivo,
    this.legenda = '',
    this.duracaoSegundos,
    this.local,
    this.poster,
  });

  final String id;
  final TipoMidia tipo;

  /// Caminho do asset (fotos) ou do vídeo empacotado no aplicativo.
  final String arquivo;
  final String legenda;
  final int? duracaoSegundos;
  final String? local;

  /// Imagem de capa exibida antes da reprodução de um vídeo.
  final String? poster;

  factory Midia.fromJson(Map<String, dynamic> j) => Midia(
    id: j['id'] as String? ?? '',
    tipo: TipoMidia.porNome(j['tipo'] as String?),
    arquivo: j['arquivo'] as String? ?? '',
    legenda: j['legenda'] as String? ?? '',
    duracaoSegundos: (j['duracaoSegundos'] as num?)?.toInt(),
    local: j['local'] as String?,
    poster: j['poster'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'arquivo': arquivo,
    'legenda': legenda,
    if (duracaoSegundos != null) 'duracaoSegundos': duracaoSegundos,
    if (local != null) 'local': local,
    if (poster != null) 'poster': poster,
  };

  Midia copiarCom({
    String? id,
    TipoMidia? tipo,
    String? arquivo,
    String? legenda,
    int? duracaoSegundos,
    String? local,
    String? poster,
  }) => Midia(
    id: id ?? this.id,
    tipo: tipo ?? this.tipo,
    arquivo: arquivo ?? this.arquivo,
    legenda: legenda ?? this.legenda,
    duracaoSegundos: duracaoSegundos ?? this.duracaoSegundos,
    local: local ?? this.local,
    poster: poster ?? this.poster,
  );
}

class TarefaManejo {
  const TarefaManejo({
    required this.id,
    required this.tipo,
    required this.descricao,
    required this.horario,
    required this.quantidade,
    this.concluida = false,
    this.responsavel = '',
  });

  final String id;
  final TipoManejo tipo;
  final String descricao;
  final String horario;
  final String quantidade;
  final bool concluida;
  final String responsavel;

  factory TarefaManejo.fromJson(Map<String, dynamic> j) => TarefaManejo(
    id: j['id'] as String? ?? '',
    tipo: TipoManejo.porNome(j['tipo'] as String?),
    descricao: j['descricao'] as String? ?? '',
    horario: j['horario'] as String? ?? '',
    quantidade: j['quantidade'] as String? ?? '',
    concluida: j['concluida'] as bool? ?? false,
    responsavel: j['responsavel'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'descricao': descricao,
    'horario': horario,
    'quantidade': quantidade,
    'concluida': concluida,
    'responsavel': responsavel,
  };

  TarefaManejo copiarCom({
    String? id,
    TipoManejo? tipo,
    String? descricao,
    String? horario,
    String? quantidade,
    bool? concluida,
    String? responsavel,
  }) => TarefaManejo(
    id: id ?? this.id,
    tipo: tipo ?? this.tipo,
    descricao: descricao ?? this.descricao,
    horario: horario ?? this.horario,
    quantidade: quantidade ?? this.quantidade,
    concluida: concluida ?? this.concluida,
    responsavel: responsavel ?? this.responsavel,
  );
}

class Ocorrencia {
  const Ocorrencia({
    required this.id,
    required this.data,
    required this.tipo,
    required this.descricao,
    required this.responsavel,
    required this.resolvida,
  });

  final String id;
  final DateTime data;
  final TipoOcorrencia tipo;
  final String descricao;
  final String responsavel;
  final bool resolvida;

  factory Ocorrencia.fromJson(Map<String, dynamic> j) => Ocorrencia(
    id: j['id'] as String? ?? '',
    data: _data(j['data']),
    tipo: TipoOcorrencia.porNome(j['tipo'] as String?),
    descricao: j['descricao'] as String? ?? '',
    responsavel: j['responsavel'] as String? ?? '',
    resolvida: j['resolvida'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': _iso(data),
    'tipo': tipo.name,
    'descricao': descricao,
    'responsavel': responsavel,
    'resolvida': resolvida,
  };

  Ocorrencia copiarCom({
    String? id,
    DateTime? data,
    TipoOcorrencia? tipo,
    String? descricao,
    String? responsavel,
    bool? resolvida,
  }) => Ocorrencia(
    id: id ?? this.id,
    data: data ?? this.data,
    tipo: tipo ?? this.tipo,
    descricao: descricao ?? this.descricao,
    responsavel: responsavel ?? this.responsavel,
    resolvida: resolvida ?? this.resolvida,
  );
}

class Observacao {
  const Observacao({
    required this.id,
    required this.data,
    required this.autor,
    required this.texto,
  });

  final String id;
  final DateTime data;
  final String autor;
  final String texto;

  factory Observacao.fromJson(Map<String, dynamic> j) => Observacao(
    id: j['id'] as String? ?? '',
    data: _data(j['data']),
    autor: j['autor'] as String? ?? '',
    texto: j['texto'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': _iso(data),
    'autor': autor,
    'texto': texto,
  };

  Observacao copiarCom({String? id, DateTime? data, String? autor, String? texto}) => Observacao(
    id: id ?? this.id,
    data: data ?? this.data,
    autor: autor ?? this.autor,
    texto: texto ?? this.texto,
  );
}

class Baia {
  const Baia({
    required this.numero,
    required this.cavaloId,
    required this.status,
    required this.ultimaLimpeza,
    required this.manejo,
    required this.ocorrencias,
    required this.observacoes,
    this.area = 'Haras principal',
  });

  final String numero;
  final String cavaloId;
  final StatusBaia status;
  final DateTime ultimaLimpeza;
  final List<TarefaManejo> manejo;
  final List<Ocorrencia> ocorrencias;
  final List<Observacao> observacoes;
  final String area;

  int get pendentes => manejo.where((t) => !t.concluida).length;
  int get resolvidas => ocorrencias.where((o) => o.resolvida).length;
  double get progressoManejo => manejo.isEmpty ? 0 : (manejo.length - pendentes) / manejo.length;

  factory Baia.fromJson(Map<String, dynamic> j) => Baia(
    numero: j['numero'] as String? ?? '',
    cavaloId: j['cavaloId'] as String? ?? '',
    status: StatusBaia.porNome(j['status'] as String?),
    ultimaLimpeza: _data(j['ultimaLimpeza']),
    manejo: [
      for (final t in (j['manejo'] as List? ?? const []))
        TarefaManejo.fromJson(t as Map<String, dynamic>),
    ],
    ocorrencias: [
      for (final o in (j['ocorrencias'] as List? ?? const []))
        Ocorrencia.fromJson(o as Map<String, dynamic>),
    ],
    observacoes: [
      for (final o in (j['observacoes'] as List? ?? const []))
        Observacao.fromJson(o as Map<String, dynamic>),
    ],
    area: j['area'] as String? ?? 'Haras principal',
  );

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'cavaloId': cavaloId,
    'status': status.name,
    'ultimaLimpeza': _iso(ultimaLimpeza),
    'manejo': [for (final t in manejo) t.toJson()],
    'ocorrencias': [for (final o in ocorrencias) o.toJson()],
    'observacoes': [for (final o in observacoes) o.toJson()],
    'area': area,
  };

  Baia copiarCom({
    String? numero,
    String? cavaloId,
    StatusBaia? status,
    DateTime? ultimaLimpeza,
    List<TarefaManejo>? manejo,
    List<Ocorrencia>? ocorrencias,
    List<Observacao>? observacoes,
    String? area,
  }) => Baia(
    numero: numero ?? this.numero,
    cavaloId: cavaloId ?? this.cavaloId,
    status: status ?? this.status,
    ultimaLimpeza: ultimaLimpeza ?? this.ultimaLimpeza,
    manejo: manejo ?? this.manejo,
    ocorrencias: ocorrencias ?? this.ocorrencias,
    observacoes: observacoes ?? this.observacoes,
    area: area ?? this.area,
  );
}

class Cavalo {
  const Cavalo({
    required this.id,
    required this.nome,
    required this.registro,
    required this.sexo,
    required this.nascimento,
    required this.pelagem,
    required this.raca,
    required this.altura,
    required this.peso,
    required this.descricao,
    required this.proprietario,
    required this.criador,
    required this.pai,
    required this.mae,
    required this.fotoPerfil,
    required this.midias,
    required this.provas,
    this.principal = false,
  });

  final String id;
  final String nome;
  final String registro;
  final Sexo sexo;
  final DateTime nascimento;
  final String pelagem;
  final String raca;
  final String altura;
  final String peso;
  final String descricao;
  final Proprietario proprietario;
  final Criador criador;
  final Ancestral pai;
  final Ancestral mae;
  final String fotoPerfil;
  final List<Midia> midias;
  final List<Prova> provas;

  /// Cavalo em destaque no aplicativo do usuário.
  final bool principal;

  List<Midia> get fotos => midias.where((m) => m.tipo == TipoMidia.foto).toList();
  List<Midia> get videos => midias.where((m) => m.tipo == TipoMidia.video).toList();

  /// Iniciais usadas no selo redondo do perfil (ex.: "ISABEL TORO LEO" -> "IT").
  String get iniciais {
    final partes = nome.split(' ').where((p) => p.trim().length > 2).toList();
    final origem = partes.isEmpty ? [nome] : partes;
    if (origem.length == 1) {
      final p = origem.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return '${origem[0][0]}${origem[1][0]}'.toUpperCase();
  }

  int get vitorias => provas.where((p) => p.vitoria).length;
  int get podios => provas.where((p) => p.podio).length;

  double? get melhorTempo =>
      provas.isEmpty ? null : provas.map((p) => p.tempoSegundos).reduce((a, b) => a < b ? a : b);

  double? get tempoMedio => provas.isEmpty
      ? null
      : provas.fold<double>(0, (a, p) => a + p.tempoSegundos) / provas.length;

  /// Média das 5 provas mais recentes (indicador de forma atual).
  double? get tempoMedioRecente {
    if (provas.isEmpty) return null;
    final ordenadas = [...provas]..sort((a, b) => b.data.compareTo(a.data));
    final ultimas = ordenadas.take(5).toList();
    return ultimas.fold<double>(0, (a, p) => a + p.tempoSegundos) / ultimas.length;
  }

  Ancestral get genealogia => Ancestral(
    nome: nome,
    registro: registro,
    pelagem: pelagem,
    pai: pai,
    mae: mae,
  );

  /// Linha do tempo esportiva: provas mais recentes primeiro.
  List<Prova> get provasRecentes {
    final lista = [...provas]..sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }

  factory Cavalo.fromJson(Map<String, dynamic> j) => Cavalo(
    id: j['id'] as String? ?? '',
    nome: j['nome'] as String? ?? '',
    registro: j['registro'] as String? ?? '',
    sexo: Sexo.porNome(j['sexo'] as String?),
    nascimento: _data(j['nascimento']),
    pelagem: j['pelagem'] as String? ?? '',
    raca: j['raca'] as String? ?? 'Quarto de Milha',
    altura: j['altura'] as String? ?? '',
    peso: j['peso'] as String? ?? '',
    descricao: j['descricao'] as String? ?? '',
    proprietario: Proprietario.fromJson(
      (j['proprietario'] as Map<String, dynamic>?) ?? const {},
    ),
    criador: Criador.fromJson((j['criador'] as Map<String, dynamic>?) ?? const {}),
    pai: Ancestral.fromJson((j['pai'] as Map<String, dynamic>?) ?? const {}),
    mae: Ancestral.fromJson((j['mae'] as Map<String, dynamic>?) ?? const {}),
    fotoPerfil: j['fotoPerfil'] as String? ?? '',
    midias: [
      for (final m in (j['midias'] as List? ?? const []))
        Midia.fromJson(m as Map<String, dynamic>),
    ],
    provas: [
      for (final p in (j['provas'] as List? ?? const []))
        Prova.fromJson(p as Map<String, dynamic>),
    ],
    principal: j['principal'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'registro': registro,
    'sexo': sexo.name,
    'nascimento': _iso(nascimento),
    'pelagem': pelagem,
    'raca': raca,
    'altura': altura,
    'peso': peso,
    'descricao': descricao,
    'proprietario': proprietario.toJson(),
    'criador': criador.toJson(),
    'pai': pai.toJson(),
    'mae': mae.toJson(),
    'fotoPerfil': fotoPerfil,
    'midias': [for (final m in midias) m.toJson()],
    'provas': [for (final p in provas) p.toJson()],
    'principal': principal,
  };

  Cavalo copiarCom({
    String? id,
    String? nome,
    String? registro,
    Sexo? sexo,
    DateTime? nascimento,
    String? pelagem,
    String? raca,
    String? altura,
    String? peso,
    String? descricao,
    Proprietario? proprietario,
    Criador? criador,
    Ancestral? pai,
    Ancestral? mae,
    String? fotoPerfil,
    List<Midia>? midias,
    List<Prova>? provas,
    bool? principal,
  }) => Cavalo(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    registro: registro ?? this.registro,
    sexo: sexo ?? this.sexo,
    nascimento: nascimento ?? this.nascimento,
    pelagem: pelagem ?? this.pelagem,
    raca: raca ?? this.raca,
    altura: altura ?? this.altura,
    peso: peso ?? this.peso,
    descricao: descricao ?? this.descricao,
    proprietario: proprietario ?? this.proprietario,
    criador: criador ?? this.criador,
    pai: pai ?? this.pai,
    mae: mae ?? this.mae,
    fotoPerfil: fotoPerfil ?? this.fotoPerfil,
    midias: midias ?? this.midias,
    provas: provas ?? this.provas,
    principal: principal ?? this.principal,
  );
}
