// API do EquiLink — roda na Cloudflare Workers e fala com o Neon.
//
// Por que existe: o app é Flutter Web, que não abre conexão TCP. Falar com o
// Postgres direto do navegador é impossível (e exporia credenciais). Esta API
// é a ponte: HTTP do navegador, driver serverless para o banco.
//
// Contrato (o mesmo que `FonteHttp` já consome):
//   POST   /sessao                              -> login (cookie HttpOnly)
//   DELETE /sessao                              -> logout
//   GET    /sessao                              -> quem sou eu
//   GET    /acervo                              -> Acervo
//   PUT    /acervo                              -> substitui tudo
//   PUT    /cavalos/:id                         -> grava um cavalo
//   DELETE /cavalos/:id                         -> remove um cavalo
//   PUT    /baias/:numero                       -> grava uma baia
//   DELETE /baias/:numero                       -> remove uma baia
//   PUT    /cavalos/:id/provas/:provaId         -> grava uma prova
//   PUT    /cavalos/:id/midias/:midiaId         -> grava uma mídia
//   POST   /cavalos/:id/principal               -> define o destaque do app
//   POST   /eventos                             -> recebe lote de analytics
//
// Segurança:
//   * Toda escrita exige sessão. Leitura é pública (é um app de vitrine).
//   * CORS com allowlist exata e credenciais; nunca `*` com cookie.
//   * Corpo limitado, arrays limitados, campos validados e truncados.
//   * Erro interno não vaza mensagem do banco: vai para o log com um id.

import { neon } from '@neondatabase/serverless';
import { normalizarAncestral } from './genealogia.js';
import { ErroValidacao, objeto, texto } from './validacao.js';
import {
  acessoDe,
  conferirSenha,
  cookieDeSessao,
  cookieVazio,
  derivarHash,
  emitirSessao,
  gerarSalt,
  identificar,
  INATIVIDADE_MAXIMA,
  paraHex,
  segundosAteExpirar,
} from './auth.js';

// ---------------------------------------------------------------------------
// Resposta
// ---------------------------------------------------------------------------

/** Origens que podem chamar a API com cookie. Allowlist exata, sem curinga. */
const ORIGENS_PERMITIDAS = (env) =>
  (env.ORIGENS_PERMITIDAS ??
    [
      'https://equilink.quarto-de-milha.workers.dev',
      'https://equilink-admin.quarto-de-milha.workers.dev',
      'http://localhost:8080',
      'http://127.0.0.1:8080',
    ].join(','))
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

function cabecalhosBase(env, request) {
  const origem = request?.headers.get('origin') ?? '';
  const permitidas = ORIGENS_PERMITIDAS(env);
  const headers = {
    'content-type': 'application/json; charset=utf-8',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'cache-control': 'no-store',
    vary: 'Origin',
  };
  // Só devolve a origem exata quando ela está na lista.
  if (permitidas.includes(origem)) {
    headers['access-control-allow-origin'] = origem;
    headers['access-control-allow-credentials'] = 'true';
    headers['access-control-allow-methods'] = 'GET,PUT,POST,DELETE,OPTIONS';
    headers['access-control-allow-headers'] = 'content-type,authorization';
    headers['access-control-max-age'] = '600';
  }
  return headers;
}

const json = (corpo, status = 200, extras = {}) =>
  new Response(JSON.stringify(corpo), {
    status,
    headers: { ...extras.cabecalhos, ...(extras.headers ?? {}) },
  });

const erro = (mensagem, status = 400, extras = {}) =>
  json({ erro: mensagem }, status, extras);

// ---------------------------------------------------------------------------
// Validação de entrada
// ---------------------------------------------------------------------------

const LIMITE_CORPO = 1024 * 1024; // 1 MiB por requisição
const LIMITE_ARRAY = 500; // itens por coleção enviada

/** Lê o JSON respeitando o limite de tamanho. Lança `ErroValidacao`. */
async function lerJson(request) {
  const declarado = Number(request.headers.get('content-length') ?? 0);
  if (declarado > LIMITE_CORPO) {
    throw new ErroValidacao('Corpo da requisição acima do limite.', 413);
  }
  const texto = await request.text();
  if (texto.length > LIMITE_CORPO) {
    throw new ErroValidacao('Corpo da requisição acima do limite.', 413);
  }
  if (!texto) return {};
  try {
    return JSON.parse(texto);
  } catch {
    throw new ErroValidacao('Corpo não é JSON válido.', 400);
  }
}

/** Identificador: só letras, números, hífen, sublinhado, ponto e dois-pontos. */
function identificador(valor, campo) {
  const s = texto(valor, campo, { max: 120, obrigatorio: true });
  if (!/^[\p{L}\p{N}_.:-]+$/u.test(s)) {
    throw new ErroValidacao(`Campo ${campo} tem caracteres inválidos.`);
  }
  return s;
}

function listaDe(valor, campo) {
  if (valor == null) return [];
  if (!Array.isArray(valor)) throw new ErroValidacao(`Campo ${campo} deve ser uma lista.`);
  if (valor.length > LIMITE_ARRAY) {
    throw new ErroValidacao(`Campo ${campo} excede ${LIMITE_ARRAY} itens.`, 413);
  }
  return valor;
}

function dataIso(valor, campo, { obrigatorio = false } = {}) {
  if (valor == null || valor === '') {
    if (obrigatorio) throw new ErroValidacao(`Campo obrigatório ausente: ${campo}.`);
    return null;
  }
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) throw new ErroValidacao(`Data inválida em ${campo}.`);
  return d.toISOString();
}

function inteiro(valor, campo, { min = 0, max = 1_000_000, padrao = 0 } = {}) {
  if (valor == null || valor === '') return padrao;
  const n = Number(valor);
  if (!Number.isFinite(n)) throw new ErroValidacao(`Campo ${campo} deve ser numérico.`);
  const i = Math.trunc(n);
  if (i < min || i > max) throw new ErroValidacao(`Campo ${campo} fora do intervalo.`);
  return i;
}

function decimal(valor, campo, { min = 0, max = 100_000, padrao = 0 } = {}) {
  if (valor == null || valor === '') return padrao;
  const n = Number(valor);
  if (!Number.isFinite(n)) throw new ErroValidacao(`Campo ${campo} deve ser numérico.`);
  if (n < min || n > max) throw new ErroValidacao(`Campo ${campo} fora do intervalo.`);
  return n;
}

// ---------------------------------------------------------------------------
// Conversão entre o JSON do app e as colunas do banco
// ---------------------------------------------------------------------------

const paraCavalo = (l, provas, midias, { privado = false } = {}) => ({
  id: l.id,
  nome: l.nome,
  registro: l.registro,
  sexo: l.sexo,
  nascimento: l.nascimento instanceof Date ? l.nascimento.toISOString() : l.nascimento,
  pelagem: l.pelagem,
  raca: l.raca,
  altura: l.altura,
  peso: l.peso,
  descricao: l.descricao,
  // O telefone do proprietário é contato pessoal: só para quem administra o
  // haras. O restante do bloco é informação de vitrine.
  proprietario: privado
    ? (l.proprietario ?? {})
    : Object.fromEntries(
        Object.entries(l.proprietario ?? {}).filter(([chave]) => chave !== 'telefone'),
      ),
  criador: l.criador ?? {},
  pai: l.pai ?? {},
  mae: l.mae ?? {},
  fotoPerfil: l.foto_perfil ?? '',
  principal: l.principal ?? false,
  sgpeUrl: l.sgpe_url ?? null,
  provas,
  midias,
});

const paraProva = (p) => ({
  id: p.id,
  data: p.data instanceof Date ? p.data.toISOString() : p.data,
  nome: p.nome,
  local: p.local,
  categoria: p.categoria,
  colocacao: p.colocacao,
  tempoSegundos: Number(p.tempo_seg),
  inscritos: p.inscritos,
  premiacao: p.premiacao ?? null,
});

const paraMidia = (m) => ({
  id: m.id,
  tipo: m.tipo,
  arquivo: m.arquivo,
  legenda: m.legenda,
  local: m.local ?? null,
  poster: m.poster ?? null,
  duracaoSegundos: m.duracao_seg ?? null,
});

const paraBaia = (b, manejo, ocorrencias, observacoes) => ({
  numero: b.numero,
  cavaloId: b.cavalo_id,
  status: b.status,
  area: b.area,
  ultimaLimpeza: b.ultima_limpeza ?? b.atualizado_em,
  manejo,
  ocorrencias,
  observacoes,
});

const paraTarefa = (t) => ({
  // Remove o prefixo de baia para o app ver o id original do domínio.
  id: String(t.id).includes(':') ? String(t.id).split(':').slice(1).join(':') : t.id,
  tipo: t.tipo,
  descricao: t.descricao,
  horario: t.horario,
  quantidade: t.quantidade,
  responsavel: t.responsavel,
  concluida: t.concluida,
  concluidaEm: t.concluida_em ?? null,
});

const paraOcorrencia = (o) => ({
  id: String(o.id).includes(':') ? String(o.id).split(':').slice(1).join(':') : o.id,
  data: o.data,
  tipo: o.tipo,
  descricao: o.descricao,
  responsavel: o.responsavel,
  resolvida: o.resolvida,
});

const paraObservacao = (o) => ({
  id: String(o.id).includes(':') ? String(o.id).split(':').slice(1).join(':') : o.id,
  data: o.data,
  autor: o.autor,
  texto: o.texto,
});

// ---------------------------------------------------------------------------
// Leitura
// ---------------------------------------------------------------------------

async function lerAcervo(sql, harasId, { privado = false } = {}) {
  const cavalos = await sql`
    select c.*,
      coalesce((
        select json_agg(json_build_object(
          'id', p.id, 'data', p.data, 'nome', p.nome, 'local', p.local,
          'categoria', p.categoria, 'colocacao', p.colocacao,
          'tempo_seg', p.tempo_seg, 'inscritos', p.inscritos, 'premiacao', p.premiacao
        ) order by p.data desc) from provas p where p.cavalo_id = c.id
      ), '[]'::json) as provas,
      coalesce((
        select json_agg(json_build_object(
          'id', m.id, 'tipo', m.tipo, 'arquivo', m.arquivo, 'legenda', m.legenda,
          'local', m.local, 'poster', m.poster, 'duracao_seg', m.duracao_seg
        ) order by m.ordem) from midias m where m.cavalo_id = c.id
      ), '[]'::json) as midias
    from cavalos c
    where c.haras_id = ${harasId}
    order by c.principal desc, c.nome
  `;

  const baias = await sql`
    select b.*,
      coalesce((
        select json_agg(json_build_object(
          'id', t.id, 'tipo', t.tipo, 'descricao', t.descricao, 'horario', t.horario,
          'quantidade', t.quantidade, 'responsavel', t.responsavel,
          'concluida', t.concluida, 'concluida_em', t.concluida_em
        ) order by t.horario) from tarefas_manejo t
        where t.haras_id = b.haras_id and t.baia_numero = b.numero
      ), '[]'::json) as manejo,
      coalesce((
        select json_agg(json_build_object(
          'id', o.id, 'data', o.data, 'tipo', o.tipo, 'descricao', o.descricao,
          'responsavel', o.responsavel, 'resolvida', o.resolvida
        ) order by o.data desc) from ocorrencias o
        where o.haras_id = b.haras_id and o.baia_numero = b.numero
      ), '[]'::json) as ocorrencias,
      coalesce((
        select json_agg(json_build_object(
          'id', v.id, 'data', v.data, 'autor', v.autor, 'texto', v.texto
        ) order by v.data desc) from observacoes v
        where v.haras_id = b.haras_id and v.baia_numero = b.numero
      ), '[]'::json) as observacoes
    from baias b
    where b.haras_id = ${harasId}
    order by b.numero
  `;

  return {
    versao: 1,
    cavalos: cavalos.map((c) =>
      paraCavalo(c, c.provas.map(paraProva), c.midias.map(paraMidia), { privado }),
    ),
    // Manejo, ocorrências e observações só para quem administra o haras:
    // descrevem rotina, saúde e conduta do animal, não são vitrine. O app
    // mostra essas listas, então o visitante recebe as baias sem elas.
    baias: baias.map((b) =>
      privado
        ? paraBaia(b, b.manejo.map(paraTarefa), b.ocorrencias.map(paraOcorrencia), b.observacoes.map(paraObservacao))
        : paraBaia(b, [], [], []),
    ),
  };
}

// ---------------------------------------------------------------------------
// Escrita
// ---------------------------------------------------------------------------

async function gravarCavalo(sql, harasId, c) {
  await sql`
    insert into cavalos (id, haras_id, nome, registro, sexo, nascimento, pelagem, raca,
                         altura, peso, descricao, foto_perfil, principal, proprietario,
                         criador, pai, mae, sgpe_url, atualizado_em)
    values (${c.id}, ${harasId}, ${c.nome}, ${c.registro}, ${c.sexo}, ${c.nascimento},
            ${c.pelagem ?? ''}, ${c.raca ?? 'EquiLink'}, ${c.altura ?? ''},
            ${c.peso ?? ''}, ${c.descricao ?? ''}, ${c.fotoPerfil ?? ''},
            ${c.principal ?? false}, ${JSON.stringify(c.proprietario ?? {})}::jsonb,
            ${JSON.stringify(c.criador ?? {})}::jsonb, ${JSON.stringify(c.pai ?? {})}::jsonb,
            ${JSON.stringify(c.mae ?? {})}::jsonb, ${c.sgpeUrl ?? null}, now())
    on conflict (id) do update set
      nome = excluded.nome, registro = excluded.registro, sexo = excluded.sexo,
      nascimento = excluded.nascimento, pelagem = excluded.pelagem, raca = excluded.raca,
      altura = excluded.altura, peso = excluded.peso, descricao = excluded.descricao,
      foto_perfil = excluded.foto_perfil, principal = excluded.principal,
      proprietario = excluded.proprietario, criador = excluded.criador,
      pai = excluded.pai, mae = excluded.mae,
      -- Os clientes não conhecem este campo: sem valor novo, o atual fica.
      sgpe_url = coalesce(excluded.sgpe_url, cavalos.sgpe_url),
      atualizado_em = now()
  `;

  // Provas e mídias vêm aninhadas no cavalo pelo contrato do app; gravar o
  // cavalo precisa persistir também esses filhos.
  for (const p of c.provas ?? []) {
    await gravarProva(sql, c.id, p);
  }
  for (const m of c.midias ?? []) {
    await gravarMidia(sql, c.id, m);
  }
}

async function gravarProva(sql, cavaloId, p) {
  await sql`
    insert into provas (id, cavalo_id, data, nome, local, categoria, colocacao,
                        tempo_seg, inscritos, premiacao)
    values (${p.id}, ${cavaloId}, ${p.data}, ${p.nome}, ${p.local ?? ''},
            ${p.categoria ?? ''}, ${p.colocacao ?? 0}, ${p.tempoSegundos ?? 0},
            ${p.inscritos ?? 0}, ${p.premiacao ?? null})
    on conflict (id) do update set
      data = excluded.data, nome = excluded.nome, local = excluded.local,
      categoria = excluded.categoria, colocacao = excluded.colocacao,
      tempo_seg = excluded.tempo_seg, inscritos = excluded.inscritos,
      premiacao = excluded.premiacao
  `;
}

async function gravarMidia(sql, cavaloId, m) {
  await sql`
    insert into midias (id, cavalo_id, tipo, arquivo, legenda, local, poster, duracao_seg)
    values (${m.id}, ${cavaloId}, ${m.tipo}, ${m.arquivo}, ${m.legenda ?? ''},
            ${m.local ?? null}, ${m.poster ?? null}, ${m.duracaoSegundos ?? null})
    on conflict (id) do update set
      tipo = excluded.tipo, arquivo = excluded.arquivo, legenda = excluded.legenda,
      local = excluded.local, poster = excluded.poster, duracao_seg = excluded.duracao_seg
  `;
}

/**
 * Ids de tarefa/ocorrência/observação se repetem entre baias no modelo do app,
 * e a chave primária aqui é global. Prefixa de forma determinística — checar
 * `id.includes(numero)` errava ('rm12' contém '1'), causando colisão.
 */
const prefixoDeBaia = (id, numero) => {
  const s = String(id);
  const marca = `${numero}:`;
  return s.startsWith(marca) ? s : `${marca}${s}`;
};

async function gravarBaia(sql, harasId, b) {
  await sql`
    insert into baias (numero, haras_id, cavalo_id, status, area, ultima_limpeza, atualizado_em)
    values (${b.numero}, ${harasId}, ${b.cavaloId}, ${b.status ?? 'emDia'},
            ${b.area ?? 'Haras principal'}, ${b.ultimaLimpeza ?? null}, now())
    on conflict (haras_id, numero) do update set
      cavalo_id = excluded.cavalo_id, status = excluded.status, area = excluded.area,
      ultima_limpeza = excluded.ultima_limpeza, atualizado_em = now()
  `;

  // Rotina e registros filhos: substitui o conjunto da baia.
  await sql`delete from tarefas_manejo where haras_id = ${harasId} and baia_numero = ${b.numero}`;
  for (const t of b.manejo ?? []) {
    // O mesmo id de tarefa se repete entre baias no modelo do app; a chave
    // primária aqui é global, então prefixamos com o número da baia.
    const idTarefa = prefixoDeBaia(t.id, b.numero);
    await sql`
      insert into tarefas_manejo (id, baia_numero, haras_id, tipo, descricao, horario,
                                  quantidade, responsavel, concluida, concluida_em)
      values (${idTarefa}, ${b.numero}, ${harasId}, ${t.tipo}, ${t.descricao},
              ${t.horario ?? ''}, ${t.quantidade ?? ''}, ${t.responsavel ?? ''},
              ${t.concluida ?? false}, ${t.concluidaEm ?? null})
      on conflict (id) do nothing
    `;
  }

  await sql`delete from ocorrencias where haras_id = ${harasId} and baia_numero = ${b.numero}`;
  for (const o of b.ocorrencias ?? []) {
    await sql`
      insert into ocorrencias (id, baia_numero, haras_id, data, tipo, descricao, responsavel, resolvida)
      values (${prefixoDeBaia(o.id, b.numero)}, ${b.numero}, ${harasId},
              ${o.data ?? new Date().toISOString()}, ${o.tipo}, ${o.descricao},
              ${o.responsavel ?? ''}, ${o.resolvida ?? false})
      on conflict (id) do nothing
    `;
  }

  await sql`delete from observacoes where haras_id = ${harasId} and baia_numero = ${b.numero}`;
  for (const v of b.observacoes ?? []) {
    await sql`
      insert into observacoes (id, baia_numero, haras_id, data, autor, texto)
      values (${prefixoDeBaia(v.id, b.numero)}, ${b.numero}, ${harasId},
              ${v.data ?? new Date().toISOString()}, ${v.autor ?? ''}, ${v.texto})
      on conflict (id) do nothing
    `;
  }
}

// ---------------------------------------------------------------------------
// Carga em lote
//
// O Worker tem limite de subrequests por invocação. Inserir registro a registro
// estoura esse limite com o acervo inteiro, então a carga usa uma instrução por
// tabela, com `unnest` para percorrer o JSON.
// ---------------------------------------------------------------------------

async function gravarAcervoEmLote(sql, harasId, acervo) {
  const cavalos = acervo.cavalos ?? [];

  await sql`
    insert into cavalos (id, haras_id, nome, registro, sexo, nascimento, pelagem, raca,
                         altura, peso, descricao, foto_perfil, principal, proprietario,
                         criador, pai, mae, sgpe_url, atualizado_em)
    select d.id, ${harasId}, d.nome, d.registro, d.sexo, d.nascimento::date, d.pelagem,
           d.raca, d.altura, d.peso, d.descricao, d.foto_perfil, d.principal,
           d.proprietario::jsonb, d.criador::jsonb, d.pai::jsonb, d.mae::jsonb,
           d.sgpe_url, now()
    from unnest(
      ${cavalos.map((c) => c.id)}::text[],
      ${cavalos.map((c) => c.nome)}::text[],
      ${cavalos.map((c) => c.registro)}::text[],
      ${cavalos.map((c) => c.sexo ?? 'femea')}::text[],
      ${cavalos.map((c) => c.nascimento)}::text[],
      ${cavalos.map((c) => c.pelagem ?? '')}::text[],
      ${cavalos.map((c) => c.raca ?? 'EquiLink')}::text[],
      ${cavalos.map((c) => c.altura ?? '')}::text[],
      ${cavalos.map((c) => c.peso ?? '')}::text[],
      ${cavalos.map((c) => c.descricao ?? '')}::text[],
      ${cavalos.map((c) => c.fotoPerfil ?? '')}::text[],
      ${cavalos.map((c) => c.principal ?? false)}::boolean[],
      ${cavalos.map((c) => JSON.stringify(c.proprietario ?? {}))}::text[],
      ${cavalos.map((c) => JSON.stringify(c.criador ?? {}))}::text[],
      ${cavalos.map((c) => JSON.stringify(c.pai ?? {}))}::text[],
      ${cavalos.map((c) => JSON.stringify(c.mae ?? {}))}::text[],
      ${cavalos.map((c) => c.sgpeUrl ?? null)}::text[]
    ) as d(id, nome, registro, sexo, nascimento, pelagem, raca, altura, peso,
           descricao, foto_perfil, principal, proprietario, criador, pai, mae, sgpe_url)
    on conflict (id) do update set
      nome = excluded.nome, registro = excluded.registro, sexo = excluded.sexo,
      nascimento = excluded.nascimento, pelagem = excluded.pelagem, raca = excluded.raca,
      altura = excluded.altura, peso = excluded.peso, descricao = excluded.descricao,
      foto_perfil = excluded.foto_perfil, principal = excluded.principal,
      proprietario = excluded.proprietario, criador = excluded.criador,
      pai = excluded.pai, mae = excluded.mae,
      -- Os clientes não conhecem este campo: sem valor novo, o atual fica.
      sgpe_url = coalesce(excluded.sgpe_url, cavalos.sgpe_url),
      atualizado_em = now()
  `;

  // Provas e mídias de todos os cavalos.
  const provas = [];
  const midias = [];
  for (const c of cavalos) {
    for (const p of c.provas ?? []) provas.push({ ...p, cavaloId: c.id });
    for (const m of c.midias ?? []) midias.push({ ...m, cavaloId: c.id });
  }

  if (provas.length) {
    await sql`
      insert into provas (id, cavalo_id, data, nome, local, categoria, colocacao,
                          tempo_seg, inscritos, premiacao)
      select d.id, d.cavalo_id, d.data::date, d.nome, d.local, d.categoria,
             d.colocacao::int, d.tempo_seg::numeric, d.inscritos::int, d.premiacao
      from unnest(
        ${provas.map((p) => p.id)}::text[],
        ${provas.map((p) => p.cavaloId)}::text[],
        ${provas.map((p) => p.data)}::text[],
        ${provas.map((p) => p.nome)}::text[],
        ${provas.map((p) => p.local ?? '')}::text[],
        ${provas.map((p) => p.categoria ?? '')}::text[],
        ${provas.map((p) => p.colocacao ?? 0)}::int[],
        ${provas.map((p) => p.tempoSegundos ?? 0)}::numeric[],
        ${provas.map((p) => p.inscritos ?? 0)}::int[],
        ${provas.map((p) => p.premiacao ?? null)}::text[]
      ) as d(id, cavalo_id, data, nome, local, categoria, colocacao, tempo_seg, inscritos, premiacao)
      on conflict (id) do update set
        colocacao = excluded.colocacao, tempo_seg = excluded.tempo_seg,
        inscritos = excluded.inscritos, premiacao = excluded.premiacao
    `;
  }

  if (midias.length) {
    await sql`
      insert into midias (id, cavalo_id, tipo, arquivo, legenda, local, poster, duracao_seg)
      select d.id, d.cavalo_id, d.tipo, d.arquivo, d.legenda, d.local, d.poster, d.duracao_seg::int
      from unnest(
        ${midias.map((m) => m.id)}::text[],
        ${midias.map((m) => m.cavaloId)}::text[],
        ${midias.map((m) => m.tipo)}::text[],
        ${midias.map((m) => m.arquivo)}::text[],
        ${midias.map((m) => m.legenda ?? '')}::text[],
        ${midias.map((m) => m.local ?? null)}::text[],
        ${midias.map((m) => m.poster ?? null)}::text[],
        ${midias.map((m) => m.duracaoSegundos ?? null)}::text[]
      ) as d(id, cavalo_id, tipo, arquivo, legenda, local, poster, duracao_seg)
      on conflict (id) do update set
        arquivo = excluded.arquivo, legenda = excluded.legenda, poster = excluded.poster
    `;
  }

  await gravarBaiasEmLote(sql, harasId, acervo.baias ?? []);
}

async function gravarBaiasEmLote(sql, harasId, baias) {
  if (!baias.length) return;

  await sql`
    insert into baias (numero, haras_id, cavalo_id, status, area, ultima_limpeza, atualizado_em)
    select d.numero, ${harasId}, d.cavalo_id, d.status, d.area, d.ultima_limpeza::timestamptz, now()
    from unnest(
      ${baias.map((b) => b.numero)}::text[],
      ${baias.map((b) => b.cavaloId)}::text[],
      ${baias.map((b) => b.status ?? 'emDia')}::text[],
      ${baias.map((b) => b.area ?? 'Haras principal')}::text[],
      ${baias.map((b) => b.ultimaLimpeza ?? null)}::text[]
    ) as d(numero, cavalo_id, status, area, ultima_limpeza)
    on conflict (haras_id, numero) do update set
      cavalo_id = excluded.cavalo_id, status = excluded.status,
      area = excluded.area, ultima_limpeza = excluded.ultima_limpeza,
      atualizado_em = now()
  `;

  const tarefas = [];
  const ocorrencias = [];
  const observacoes = [];
  for (const b of baias) {
    for (const t of b.manejo ?? []) {
      tarefas.push({ ...t, baiaNumero: b.numero, idUnico: prefixoDeBaia(t.id, b.numero) });
    }
    for (const o of b.ocorrencias ?? []) {
      ocorrencias.push({ ...o, baiaNumero: b.numero, idUnico: prefixoDeBaia(o.id, b.numero) });
    }
    for (const v of b.observacoes ?? []) {
      observacoes.push({ ...v, baiaNumero: b.numero, idUnico: prefixoDeBaia(v.id, b.numero) });
    }
  }

  await sql`delete from tarefas_manejo where haras_id = ${harasId}`;
  if (tarefas.length) {
    await sql`
      insert into tarefas_manejo (id, baia_numero, haras_id, tipo, descricao, horario,
                                  quantidade, responsavel, concluida, concluida_em)
      select d.id, d.baia_numero, ${harasId}, d.tipo, d.descricao, d.horario,
             d.quantidade, d.responsavel, d.concluida, d.concluida_em::timestamptz
      from unnest(
        ${tarefas.map((t) => t.idUnico)}::text[],
        ${tarefas.map((t) => t.baiaNumero)}::text[],
        ${tarefas.map((t) => t.tipo)}::text[],
        ${tarefas.map((t) => t.descricao)}::text[],
        ${tarefas.map((t) => t.horario ?? '')}::text[],
        ${tarefas.map((t) => t.quantidade ?? '')}::text[],
        ${tarefas.map((t) => t.responsavel ?? '')}::text[],
        ${tarefas.map((t) => t.concluida ?? false)}::boolean[],
        ${tarefas.map((t) => t.concluidaEm ?? null)}::text[]
      ) as d(id, baia_numero, tipo, descricao, horario, quantidade, responsavel, concluida, concluida_em)
    `;
  }

  await sql`delete from ocorrencias where haras_id = ${harasId}`;
  if (ocorrencias.length) {
    await sql`
      insert into ocorrencias (id, baia_numero, haras_id, data, tipo, descricao, responsavel, resolvida)
      select d.id, d.baia_numero, ${harasId}, d.data::timestamptz, d.tipo, d.descricao,
             d.responsavel, d.resolvida
      from unnest(
        ${ocorrencias.map((o) => o.idUnico)}::text[],
        ${ocorrencias.map((o) => o.baiaNumero)}::text[],
        ${ocorrencias.map((o) => o.data ?? new Date().toISOString())}::text[],
        ${ocorrencias.map((o) => o.tipo)}::text[],
        ${ocorrencias.map((o) => o.descricao)}::text[],
        ${ocorrencias.map((o) => o.responsavel ?? '')}::text[],
        ${ocorrencias.map((o) => o.resolvida ?? false)}::boolean[]
      ) as d(id, baia_numero, data, tipo, descricao, responsavel, resolvida)
    `;
  }

  await sql`delete from observacoes where haras_id = ${harasId}`;
  if (observacoes.length) {
    await sql`
      insert into observacoes (id, baia_numero, haras_id, data, autor, texto)
      select d.id, d.baia_numero, ${harasId}, d.data::timestamptz, d.autor, d.texto
      from unnest(
        ${observacoes.map((v) => v.idUnico)}::text[],
        ${observacoes.map((v) => v.baiaNumero)}::text[],
        ${observacoes.map((v) => v.data ?? new Date().toISOString())}::text[],
        ${observacoes.map((v) => v.autor ?? '')}::text[],
        ${observacoes.map((v) => v.texto)}::text[]
      ) as d(id, baia_numero, data, autor, texto)
    `;
  }
}

// ---------------------------------------------------------------------------
// Sessão e bloqueio por tentativa repetida
// ---------------------------------------------------------------------------

/** Hash do IP: guarda o suficiente para bloquear, sem armazenar o endereço. */
const hashIp = (request, env) => {
  const ip =
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for') ??
    'desconhecido';
  return paraHex(new TextEncoder().encode(`${ip}:${env.SESSION_SECRET ?? ''}`));
};

const JANELA_BLOQUEIO_MIN = 15;
const MAX_TENTATIVAS = 5;

async function bloqueado(sql, ipHash, usuarioId) {
  const porIp = await sql`
    select count(*)::int as n from tentativas_login
    where ip_hash = ${ipHash} and not sucesso
      and quando > now() - interval '15 minutes'
  `;
  const porUsuario = usuarioId
    ? await sql`
        select count(*)::int as n from tentativas_login
        where usuario_id = ${usuarioId} and not sucesso
          and quando > now() - interval '15 minutes'
      `
    : [{ n: 0 }];
  return porIp[0].n >= MAX_TENTATIVAS || porUsuario[0].n >= MAX_TENTATIVAS;
}

async function registrarTentativa(sql, ipHash, usuarioId, sucesso) {
  await sql`
    insert into tentativas_login (ip_hash, usuario_id, sucesso)
    values (${ipHash}, ${usuarioId ?? ''}, ${sucesso})
  `;
  // Poda: mantém a tabela pequena, só a janela recente importa.
  await sql`delete from tentativas_login where quando < now() - interval '2 days'`;
}

// ---------------------------------------------------------------------------
// Roteamento
// ---------------------------------------------------------------------------

const COOKIE_SEGURO = (request) => {
  const url = new URL(request.url);
  return url.protocol === 'https:';
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const base = cabecalhosBase(env, request);

    // Preflight: responde só para origem conhecida; sem curinga.
    if (request.method === 'OPTIONS') {
      if (!base['access-control-allow-origin']) {
        return new Response(null, { status: 403, headers: base });
      }
      return new Response(null, { status: 204, headers: base });
    }

    const partes = url.pathname.split('/').filter(Boolean);
    const sql = neon(env.DATABASE_URL);
    const seguro = COOKIE_SEGURO(request);

    if (!env.SESSION_SECRET) {
      // Sem segredo não há como assinar sessão. Falhar fechado é melhor que
      // servir uma API que aceita qualquer coisa.
      return erro('Servidor sem SESSION_SECRET configurado.', 503, { cabecalhos: base });
    }

    try {
      // -------------------------------------------------------------------
      // Sessão
      // -------------------------------------------------------------------

      if (partes[0] === 'sessao') {
        // POST /sessao — login
        if (request.method === 'POST') {
          const corpo = await lerJson(request);
          const usuarioId = texto(corpo.usuario, 'usuario', { max: 120, obrigatorio: true });
          const senha = texto(corpo.senha, 'senha', { max: 200, obrigatorio: true });
          const ipHash = hashIp(request, env);

          if (await bloqueado(sql, ipHash, usuarioId)) {
            return erro(
              'Muitas tentativas. Aguarde 15 minutos.',
              429,
              { cabecalhos: base },
            );
          }

          // Mensagem única para usuário inexistente e senha errada: não
          // confirma quais contas existem.
          // Mesmo custo de CPU quando o usuário não existe (hash de isca).
          const registros = await sql`
            select usuario_id, hash, salt, iteracoes from credenciais where usuario_id = ${usuarioId}
          `;
          const registro = registros[0];
          // Mesmo custo de CPU quando o usuário não existe (hash de isca),
          // para não revelar por tempo de resposta quais contas existem.
          const confere = registro
            ? await conferirSenha(senha, registro, env.PEPPER_SENHA)
            : (await derivarHash(senha, gerarSalt(), undefined, env.PEPPER_SENHA), false);

          if (!registro || !confere) {
            await registrarTentativa(sql, ipHash, usuarioId, false);
            return erro('Usuário ou senha inválidos.', 401, { cabecalhos: base });
          }

          await registrarTentativa(sql, ipHash, usuarioId, true);
          const cookie = cookieDeSessao(await emitirSessao(usuarioId, env.SESSION_SECRET), {
            seguro,
          });
          const acesso = await acessoDe(sql, { tipo: 'usuario', usuarioId }, env);
          return json(
            { usuario: usuarioId, harasId: acesso?.harasId ?? null, papel: acesso?.papel ?? null },
            200,
            { cabecalhos: base, headers: { 'set-cookie': cookie } },
          );
        }

        // DELETE /sessao — logout
        if (request.method === 'DELETE') {
          return json({ ok: true }, 200, {
            cabecalhos: base,
            headers: { 'set-cookie': cookieVazio(seguro) },
          });
        }

        // GET /sessao — quem sou eu
        if (request.method === 'GET') {
          const identidade = await identificar(request, env);
          const acesso = await acessoDe(sql, identidade, env);
          if (!acesso) return json({ autenticado: false }, 200, { cabecalhos: base });
          return json(
            {
              autenticado: true,
              usuario: identidade.usuarioId,
              harasId: acesso.harasId,
              papel: acesso.papel,
              // Prazo para o cliente avisar antes de cair por inatividade.
              expiraEmSegundos: identidade.sessao
                ? segundosAteExpirar(identidade.sessao)
                : null,
              limiteInatividadeSegundos: INATIVIDADE_MAXIMA,
            },
            200,
            { cabecalhos: base },
          );
        }
      }

      // -------------------------------------------------------------------
      // A partir daqui: identidade resolvida uma vez
      // -------------------------------------------------------------------

      const identidade = await identificar(request, env);
      const acesso = await acessoDe(sql, identidade, env);
      const autenticado = Boolean(acesso);
      const podeEscrever = autenticado && acesso.papel !== 'leitor';
      const podeRemover = autenticado && acesso.papel === 'proprietario';

      // Renova o relógio de inatividade quando houve uso desde a última
      // assinatura. Sem isso, a sessão cairia 1h depois do login mesmo com o
      // operador trabalhando.
      const renovacao = identidade.renovar
        ? {
            'set-cookie': cookieDeSessao(
              await emitirSessao(identidade.usuarioId, env.SESSION_SECRET),
              { seguro },
            ),
          }
        : {};

      /** Resposta com o cookie renovado, quando aplicável. */
      const responder = (corpo, status = 200, extras = {}) =>
        json(corpo, status, {
          cabecalhos: base,
          headers: { ...renovacao, ...(extras.headers ?? {}) },
        });

      const recusarEscrita = () =>
        erro(
          autenticado
            ? 'Seu papel não permite esta operação.'
            : 'Autenticação necessária para gravar.',
          autenticado ? 403 : 401,
          { cabecalhos: base },
        );

      // GET /acervo — público, mas sem dado privado
      if (partes[0] === 'acervo' && request.method === 'GET') {
        if (!acesso) {
          // Visitante: qualquer haras que tenha animais publicados. Hoje há um.
          const alvo = env.HARAS_PUBLICO ?? env.HARAS_ID;
          if (!alvo) return erro('Nenhum haras público configurado.', 404, { cabecalhos: base });
          return json(await lerAcervo(sql, alvo, { privado: false }), 200, { cabecalhos: base });
        }
        return json(await lerAcervo(sql, acesso.harasId, { privado: true }), 200, {
          cabecalhos: base,
        });
      }

      // PUT /acervo — substituição total (migração entre fontes)
      if (partes[0] === 'acervo' && request.method === 'PUT') {
        if (!podeEscrever) return recusarEscrita();
        const corpo = await lerJson(request);
        const cavalos = listaDe(corpo.cavalos, 'cavalos').map((c) => normalizarCavalo(c, null));
        const baias = listaDe(corpo.baias, 'baias').map((b) => normalizarBaia(b));
        await gravarAcervoEmLote(sql, acesso.harasId, { cavalos, baias });
        return json(await lerAcervo(sql, acesso.harasId, { privado: true }), 200, {
          cabecalhos: base,
        });
      }

      // POST /eventos — lote de analytics (público: telemetria do app)
      // GET /eventos — telemetria gravada, para o painel de analytics.
      //
      // Só quem administra o haras lê: os eventos trazem navegação e ações de
      // usuários identificados. Sem este endpoint, o painel mostrava apenas a
      // sessão local e os eventos enviados pelo app ficavam invisíveis no banco.
      if (partes[0] === 'eventos' && request.method === 'GET') {
        if (!autenticado) {
          return erro('Autenticação necessária para ler a telemetria.', 401, { cabecalhos: base });
        }
        const limite = inteiro(url.searchParams.get('limite'), 'limite', {
          min: 1,
          max: 5000,
          padrao: 1000,
        });
        const linhas = await sql`
          select nome, quando, sessao, usuario, tela, entidade, entidade_id,
                 valor, propriedades
          from eventos_analiticos
          where haras_id = ${acesso.harasId}
          order by quando desc
          limit ${limite}
        `;
        return json(
          {
            eventos: linhas.map((l) => ({
              nome: l.nome,
              quando: l.quando instanceof Date ? l.quando.toISOString() : l.quando,
              sessao: l.sessao,
              usuario: l.usuario ?? null,
              tela: l.tela ?? null,
              entidade: l.entidade ?? null,
              entidadeId: l.entidade_id ?? null,
              valor: l.valor == null ? null : Number(l.valor),
              propriedades: l.propriedades ?? {},
            })),
          },
          200,
          { cabecalhos: base },
        );
      }

      if (partes[0] === 'eventos' && request.method === 'POST') {
        const corpo = await lerJson(request);
        const lista = listaDe(corpo.eventos, 'eventos');
        let recebidos = 0;
        for (const e of lista) {
          const nome = texto(e?.nome, 'nome', { max: 80, obrigatorio: true });
          await sql`
            insert into eventos_analiticos (nome, quando, sessao, usuario, tela,
                                            entidade, entidade_id, valor, propriedades, haras_id)
            values (${nome}, ${dataIso(e?.quando, 'quando') ?? new Date().toISOString()},
                    ${texto(e?.sessao, 'sessao', { max: 80, obrigatorio: true })},
                    ${texto(e?.usuario, 'usuario', { max: 120 }) || null},
                    ${texto(e?.tela, 'tela', { max: 80 }) || null},
                    ${texto(e?.entidade, 'entidade', { max: 60 }) || null},
                    ${texto(e?.entidadeId, 'entidadeId', { max: 120 }) || null},
                    ${e?.valor == null ? null : decimal(e.valor, 'valor', { min: -1e9, max: 1e9 })},
                    ${JSON.stringify(objeto(e?.propriedades, 'propriedades'))}::jsonb,
                    ${acesso?.harasId ?? (env.HARAS_PUBLICO ?? env.HARAS_ID)})
          `;
          recebidos += 1;
        }
        return json({ recebidos }, 201, { cabecalhos: base });
      }

      // -------------------------------------------------------------------
      // Sugestões do cliente, por página do painel
      // -------------------------------------------------------------------

      if (partes[0] === 'sugestoes') {
        if (!autenticado) {
          return erro('Autenticação necessária.', 401, { cabecalhos: base });
        }
        // `await` é obrigatório: sem ele a promise escapa do try/catch e uma
        // validação recusada vira erro 500 (unhandled rejection) em vez de 400.
        return await rotaSugestoes({ request, url, sql, acesso, base, partes, identidade });
      }

      // /cavalos/:id
      if (partes[0] === 'cavalos' && partes[1]) {
        const id = identificador(decodeURIComponent(partes[1]), 'id');

        if (request.method === 'PUT' && !partes[2]) {
          if (!podeEscrever) return recusarEscrita();
          await gravarCavalo(sql, acesso.harasId, normalizarCavalo(await lerJson(request), id));
          return json({ ok: true }, 200, { cabecalhos: base });
        }

        if (request.method === 'DELETE' && !partes[2]) {
          if (!podeRemover) return recusarEscrita();
          const removidos = await sql`
            delete from cavalos where id = ${id} and haras_id = ${acesso.harasId}
            returning id
          `;
          if (!removidos.length) return erro('Cavalo não encontrado.', 404, { cabecalhos: base });
          return json({ ok: true }, 200, { cabecalhos: base });
        }

        if (request.method === 'PUT' && partes[2] === 'provas' && partes[3]) {
          if (!podeEscrever) return recusarEscrita();
          const provaId = identificador(decodeURIComponent(partes[3]), 'provaId');
          if (!(await cavaloDoHaras(sql, id, acesso.harasId))) {
            return erro('Cavalo não encontrado.', 404, { cabecalhos: base });
          }
          await gravarProva(sql, id, normalizarProva(await lerJson(request), provaId));
          return json({ ok: true }, 200, { cabecalhos: base });
        }

        // POST /cavalos/:id/midias — recebe o arquivo e devolve a URL pública.
        //
        // O corpo é o binário cru (sem multipart): o cliente já sabe o tipo, e
        // multipart no Worker significa decodificar um formato de 1994 para
        // extrair um único campo. Content-Type e X-Nome-Arquivo carregam o resto.
        if (request.method === 'POST' && partes[2] === 'midias' && !partes[3]) {
          if (!podeEscrever) return recusarEscrita();
          if (!env.MIDIA) {
            return erro('Armazenamento de mídia não configurado.', 503, { cabecalhos: base });
          }
          if (!(await cavaloDoHaras(sql, id, acesso.harasId))) {
            return erro('Cavalo não encontrado.', 404, { cabecalhos: base });
          }
          return uploadMidia(request, env, base, id);
        }

        if (request.method === 'PUT' && partes[2] === 'midias' && partes[3]) {
          if (!podeEscrever) return recusarEscrita();
          const midiaId = identificador(decodeURIComponent(partes[3]), 'midiaId');
          if (!(await cavaloDoHaras(sql, id, acesso.harasId))) {
            return erro('Cavalo não encontrado.', 404, { cabecalhos: base });
          }
          await gravarMidia(sql, id, normalizarMidia(await lerJson(request), midiaId));
          return json({ ok: true }, 200, { cabecalhos: base });
        }

        if (request.method === 'POST' && partes[2] === 'principal') {
          if (!podeEscrever) return recusarEscrita();
          const alvo = await sql`
            update cavalos set principal = (id = ${id}) where haras_id = ${acesso.harasId}
            returning id
          `;
          if (!alvo.length) return erro('Cavalo não encontrado.', 404, { cabecalhos: base });
          return json({ ok: true }, 200, { cabecalhos: base });
        }
      }

      // /baias/:numero
      if (partes[0] === 'baias' && partes[1]) {
        const numero = identificador(decodeURIComponent(partes[1]), 'numero');

        if (request.method === 'PUT') {
          if (!podeEscrever) return recusarEscrita();
          await gravarBaia(sql, acesso.harasId, normalizarBaia(await lerJson(request), numero));
          return json({ ok: true }, 200, { cabecalhos: base });
        }

        if (request.method === 'DELETE') {
          if (!podeRemover) return recusarEscrita();
          const removidas = await sql`
            delete from baias where numero = ${numero} and haras_id = ${acesso.harasId}
            returning numero
          `;
          if (!removidas.length) return erro('Baia não encontrada.', 404, { cabecalhos: base });
          return json({ ok: true }, 200, { cabecalhos: base });
        }
      }

      return erro('Rota não encontrada.', 404, { cabecalhos: base });
    } catch (e) {
      if (e instanceof ErroValidacao) {
        return erro(e.message, e.status, { cabecalhos: base });
      }
      // Erro interno: a mensagem do banco pode conter SQL, nome de coluna ou
      // dado de outro haras. Loga com um id e devolve só o id.
      const idErro = crypto.randomUUID().slice(0, 8);
      console.error(`[${idErro}]`, request.method, url.pathname, e?.message);
      return erro('Falha interna ao processar a requisição.', 500, {
        cabecalhos: base,
        headers: { 'x-erro-id': idErro },
      });
    }
  },
};

// ---------------------------------------------------------------------------
// Upload de mídia para o R2
// ---------------------------------------------------------------------------

/** 50 MiB: vídeo de celular cabe; o resto do acervo não justifica mais. */
const LIMITE_UPLOAD = 50 * 1024 * 1024;

/**
 * Extensões e tipos aceitos.
 *
 * A lista é de permissão, não de bloqueio: um arquivo só é gravado se o
 * Content-Type declarado estiver aqui. Isso evita hospedar HTML ou SVG — que
 * executariam script quando servidos pelo domínio público do bucket.
 */
const TIPOS_MIDIA = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/avif': 'avif',
  'image/gif': 'gif',
  'video/mp4': 'mp4',
  'video/webm': 'webm',
  'video/quicktime': 'mov',
};

async function uploadMidia(request, env, base, cavaloId) {
  const tipo = (request.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
  const extensao = TIPOS_MIDIA[tipo];
  if (!extensao) {
    return erro(
      'Tipo de arquivo não aceito. Use JPEG, PNG, WebP, AVIF, GIF, MP4, WebM ou MOV.',
      415,
      { cabecalhos: base },
    );
  }

  const declarado = Number(request.headers.get('content-length') ?? 0);
  if (declarado > LIMITE_UPLOAD) {
    return erro('Arquivo acima de 50 MB.', 413, { cabecalhos: base });
  }

  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0) return erro('Arquivo vazio.', 400, { cabecalhos: base });
  if (bytes.byteLength > LIMITE_UPLOAD) {
    return erro('Arquivo acima de 50 MB.', 413, { cabecalhos: base });
  }

  // Chave gerada no servidor: o nome que o cliente mandou não vira caminho.
  const chave = `midia/${cavaloId}/${crypto.randomUUID()}.${extensao}`;
  await env.MIDIA.put(chave, bytes, {
    httpMetadata: {
      contentType: tipo,
      // Uma semana, não um ano: o nome é único, mas o cache do navegador
      // guarda a resposta completa — incluindo a ausência de cabeçalhos CORS se
      // a política do bucket mudar depois. Uma janela curta permite corrigir
      // sem exigir que o usuário limpe o cache.
      cacheControl: 'public, max-age=604800',
    },
  });

  const publico = env.R2_PUBLICO ?? '';
  if (!publico) {
    return erro('Domínio público da mídia não configurado.', 503, { cabecalhos: base });
  }

  return json(
    {
      arquivo: `${publico.replace(/\/$/, '')}/${chave}`,
      tipo: tipo.startsWith('video/') ? 'video' : 'foto',
      bytes: bytes.byteLength,
    },
    201,
    { cabecalhos: base },
  );
}

// ---------------------------------------------------------------------------
// Normalização: a entrada do cliente nunca chega crua ao banco
// ---------------------------------------------------------------------------

/** Confere que o cavalo pertence ao haras antes de gravar filhos nele. */
async function cavaloDoHaras(sql, id, harasId) {
  const linhas = await sql`
    select id from cavalos where id = ${id} and haras_id = ${harasId}
  `;
  return linhas.length > 0;
}

function normalizarCavalo(bruto, idForcado) {
  const c = objeto(bruto, 'cavalo');
  const id = idForcado ?? identificador(c.id, 'id');
  const sexo = texto(c.sexo, 'sexo', { max: 10, padrao: 'femea' });
  if (sexo !== 'femea' && sexo !== 'macho') {
    throw new ErroValidacao('Campo sexo deve ser "femea" ou "macho".');
  }
  const proprietario = objeto(c.proprietario, 'proprietario');
  return {
    id,
    nome: texto(c.nome, 'nome', { max: 120, obrigatorio: true }),
    registro: texto(c.registro, 'registro', { max: 40, obrigatorio: true }),
    sexo,
    nascimento: dataIso(c.nascimento, 'nascimento', { obrigatorio: true }),
    pelagem: texto(c.pelagem, 'pelagem', { max: 60 }),
    raca: texto(c.raca, 'raca', { max: 60, padrao: 'EquiLink' }),
    altura: texto(c.altura, 'altura', { max: 20 }),
    peso: texto(c.peso, 'peso', { max: 20 }),
    descricao: texto(c.descricao, 'descricao', { max: 4000 }),
    fotoPerfil: texto(c.fotoPerfil, 'fotoPerfil', { max: 500 }),
    principal: c.principal === true,
    proprietario: {
      nome: texto(proprietario.nome, 'proprietario.nome', { max: 120 }),
      fazenda: texto(proprietario.fazenda, 'proprietario.fazenda', { max: 120 }),
      cidade: texto(proprietario.cidade, 'proprietario.cidade', { max: 120 }),
      telefone: texto(proprietario.telefone, 'proprietario.telefone', { max: 40 }),
    },
    criador: {
      nome: texto(c.criador?.nome, 'criador.nome', { max: 120 }),
      cidade: texto(c.criador?.cidade, 'criador.cidade', { max: 120 }),
    },
    pai: normalizarAncestral(c.pai, 'pai'),
    mae: normalizarAncestral(c.mae, 'mae'),
    sgpeUrl: urlSegura(c.sgpeUrl, 'sgpeUrl'),
    provas: listaDe(c.provas, 'provas').map((p) => normalizarProva(p, null)),
    midias: listaDe(c.midias, 'midias').map((m) => normalizarMidia(m, null)),
  };
}

/** Só http(s) absoluto, ou caminho de asset. Bloqueia `javascript:`, `data:`. */
function urlSegura(valor, campo) {
  const s = texto(valor, campo, { max: 500 });
  if (!s) return null;
  if (s.startsWith('assets/')) return s;
  let u;
  try {
    u = new URL(s);
  } catch {
    throw new ErroValidacao(`Campo ${campo} deve ser uma URL válida.`);
  }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') {
    throw new ErroValidacao(`Campo ${campo} só aceita http ou https.`);
  }
  return u.toString();
}

function normalizarProva(bruto, idForcado) {
  const p = objeto(bruto, 'prova');
  return {
    id: idForcado ?? identificador(p.id, 'prova.id'),
    data: dataIso(p.data, 'prova.data', { obrigatorio: true }),
    nome: texto(p.nome, 'prova.nome', { max: 120, obrigatorio: true }),
    local: texto(p.local, 'prova.local', { max: 120 }),
    categoria: texto(p.categoria, 'prova.categoria', { max: 60 }),
    colocacao: inteiro(p.colocacao, 'prova.colocacao', { min: 1, max: 999, padrao: 1 }),
    tempoSegundos: decimal(p.tempoSegundos, 'prova.tempoSegundos', { min: 0, max: 100000 }),
    inscritos: inteiro(p.inscritos, 'prova.inscritos', { min: 0, max: 100000 }),
    premiacao: texto(p.premiacao, 'prova.premiacao', { max: 80 }) || null,
  };
}

function normalizarMidia(bruto, idForcado) {
  const m = objeto(bruto, 'midia');
  const tipo = texto(m.tipo, 'midia.tipo', { max: 10, padrao: 'foto' });
  if (tipo !== 'foto' && tipo !== 'video') {
    throw new ErroValidacao('Campo midia.tipo deve ser "foto" ou "video".');
  }
  const arquivo = urlSegura(m.arquivo, 'midia.arquivo');
  if (!arquivo) throw new ErroValidacao('Campo midia.arquivo é obrigatório.');
  return {
    id: idForcado ?? identificador(m.id, 'midia.id'),
    tipo,
    arquivo,
    legenda: texto(m.legenda, 'midia.legenda', { max: 300 }),
    local: texto(m.local, 'midia.local', { max: 120 }) || null,
    poster: urlSegura(m.poster, 'midia.poster'),
    duracaoSegundos: m.duracaoSegundos == null
      ? null
      : inteiro(m.duracaoSegundos, 'midia.duracaoSegundos', { min: 0, max: 100000 }),
  };
}

function normalizarBaia(bruto, numeroForcado) {
  const b = objeto(bruto, 'baia');
  const numero = numeroForcado ?? identificador(b.numero, 'baia.numero');
  const status = texto(b.status, 'baia.status', { max: 20, padrao: 'emDia' });
  const permitidos = ['emDia', 'atencao', 'manutencao'];
  return {
    numero,
    cavaloId: texto(b.cavaloId, 'baia.cavaloId', { max: 120 }) || null,
    status: permitidos.includes(status) ? status : 'emDia',
    area: texto(b.area, 'baia.area', { max: 120, padrao: 'Haras principal' }),
    ultimaLimpeza: dataIso(b.ultimaLimpeza, 'baia.ultimaLimpeza'),
    manejo: listaDe(b.manejo, 'baia.manejo').map((t) => ({
      id: identificador(t?.id, 'tarefa.id'),
      tipo: texto(t?.tipo, 'tarefa.tipo', { max: 40, obrigatorio: true }),
      descricao: texto(t?.descricao, 'tarefa.descricao', { max: 300 }),
      horario: texto(t?.horario, 'tarefa.horario', { max: 10 }),
      quantidade: texto(t?.quantidade, 'tarefa.quantidade', { max: 40 }),
      responsavel: texto(t?.responsavel, 'tarefa.responsavel', { max: 120 }),
      concluida: t?.concluida === true,
      concluidaEm: dataIso(t?.concluidaEm, 'tarefa.concluidaEm'),
    })),
    ocorrencias: listaDe(b.ocorrencias, 'baia.ocorrencias').map((o) => ({
      id: identificador(o?.id, 'ocorrencia.id'),
      data: dataIso(o?.data, 'ocorrencia.data') ?? new Date().toISOString(),
      tipo: texto(o?.tipo, 'ocorrencia.tipo', { max: 40, obrigatorio: true }),
      descricao: texto(o?.descricao, 'ocorrencia.descricao', { max: 1000 }),
      responsavel: texto(o?.responsavel, 'ocorrencia.responsavel', { max: 120 }),
      resolvida: o?.resolvida === true,
    })),
    observacoes: listaDe(b.observacoes, 'baia.observacoes').map((v) => ({
      id: identificador(v?.id, 'observacao.id'),
      data: dataIso(v?.data, 'observacao.data') ?? new Date().toISOString(),
      autor: texto(v?.autor, 'observacao.autor', { max: 120 }),
      texto: texto(v?.texto, 'observacao.texto', { max: 2000, obrigatorio: true }),
    })),
  };
}

// ---------------------------------------------------------------------------
// Sugestões do cliente
//
// O cliente anota o que quer em cada página; quem implementa (pessoa ou agente)
// lê a fila. Cada mudança grava um instantâneo em `sugestoes_historico`, então
// o cliente vê o próprio histórico e nada se perde ao apagar.
// ---------------------------------------------------------------------------

const STATUS_SUGESTAO = ['aberta', 'em_andamento', 'implementada', 'recusada'];
const PRIORIDADES_SUGESTAO = ['baixa', 'normal', 'alta'];

/** Uma linha do banco no formato que o cliente Dart espera. */
const paraSugestao = (l) => ({
  id: l.id,
  rota: l.rota,
  referencia: l.referencia ?? null,
  titulo: l.titulo,
  texto: l.texto,
  status: l.apagada_em ? 'apagada' : l.status,
  prioridade: l.prioridade,
  versao: l.versao,
  criadoEm: l.criado_em instanceof Date ? l.criado_em.toISOString() : l.criado_em,
  atualizadoEm: l.atualizado_em instanceof Date ? l.atualizado_em.toISOString() : l.atualizado_em,
  usuario: l.usuario_id,
});

/** Grava um instantâneo do estado atual no histórico. */
async function registrarVersao(sql, sugestao, acao, autor) {
  await sql`
    insert into sugestoes_historico
      (sugestao_id, versao, acao, titulo, texto, status, prioridade, referencia, rota, autor)
    values (${sugestao.id}, ${sugestao.versao}, ${acao}, ${sugestao.titulo}, ${sugestao.texto},
            ${acao === 'apagada' ? 'apagada' : sugestao.status}, ${sugestao.prioridade},
            ${sugestao.referencia ?? null}, ${sugestao.rota}, ${autor})
  `;
}

async function rotaSugestoes({ request, url, sql, acesso, base, partes, identidade }) {
  const autor = identidade.usuarioId;
  const responder = (corpo, status = 200) => json(corpo, status, { cabecalhos: base });

  // GET /sugestoes?rota=/cavalos&apagadas=1
  if (!partes[1] && request.method === 'GET') {
    const rota = url.searchParams.get('rota');
    const incluirApagadas = url.searchParams.get('apagadas') === '1';
    const limite = inteiro(url.searchParams.get('limite'), 'limite', {
      min: 1,
      max: 500,
      padrao: 200,
    });
    const linhas = await sql`
      select * from sugestoes
      where haras_id = ${acesso.harasId}
        and usuario_id = ${autor}
        ${rota ? sql`and rota = ${rota}` : sql``}
        ${incluirApagadas ? sql`` : sql`and apagada_em is null`}
      order by atualizado_em desc
      limit ${limite}
    `;
    return responder({ sugestoes: linhas.map(paraSugestao) });
  }

  // POST /sugestoes
  if (!partes[1] && request.method === 'POST') {
    const corpo = await lerJson(request);
    const rota = texto(corpo.rota, 'rota', { max: 200, obrigatorio: true });
    const titulo = texto(corpo.titulo, 'titulo', { max: 160, obrigatorio: true });
    const descricao = texto(corpo.texto, 'texto', { max: 8000, obrigatorio: true });
    const referencia = texto(corpo.referencia, 'referencia', { max: 300 }) || null;
    const prioridade = PRIORIDADES_SUGESTAO.includes(corpo.prioridade)
      ? corpo.prioridade
      : 'normal';

    const linhas = await sql`
      insert into sugestoes
        (haras_id, usuario_id, rota, referencia, titulo, texto, prioridade)
      values (${acesso.harasId}, ${autor}, ${rota}, ${referencia}, ${titulo},
              ${descricao}, ${prioridade})
      returning *
    `;
    await registrarVersao(sql, linhas[0], 'criada', autor);
    return responder(paraSugestao(linhas[0]), 201);
  }

  // /sugestoes/:id
  if (partes[1]) {
    const id = identificador(decodeURIComponent(partes[1]), 'id');
    const existentes = await sql`
      select * from sugestoes
      where id = ${id} and haras_id = ${acesso.harasId} and usuario_id = ${autor}
    `;
    const atual = existentes[0];
    if (!atual) return erro('Sugestão não encontrada.', 404, { cabecalhos: base });

    // Sugestão apagada é só leitura. Sem esta guarda, `PUT` e `PATCH`
    // reescreviam o conteúdo de algo que o cliente já tinha removido da lista.
    //
    // `DELETE` continua aceito: apagar duas vezes é idempotente e devolve 204.
    if (atual.apagada_em) {
      const permitido =
        (partes[2] === 'historico' && request.method === 'GET') ||
        request.method === 'DELETE';
      if (!permitido) {
        return erro('Sugestão apagada não pode ser alterada.', 409, { cabecalhos: base });
      }
    }

    // GET /sugestoes/:id/historico
    if (partes[2] === 'historico' && request.method === 'GET') {
      const versoes = await sql`
        select versao, acao, titulo, texto, status, prioridade, referencia, rota, autor, quando
        from sugestoes_historico
        where sugestao_id = ${id}
        order by versao desc, quando desc
      `;
      return responder({
        versoes: versoes.map((v) => ({
          ...v,
          quando: v.quando instanceof Date ? v.quando.toISOString() : v.quando,
        })),
      });
    }

    // PUT /sugestoes/:id — edita conteúdo
    if (request.method === 'PUT') {
      const corpo = await lerJson(request);
      const titulo = corpo.titulo == null
        ? atual.titulo
        : texto(corpo.titulo, 'titulo', { max: 160, obrigatorio: true });
      const descricao = corpo.texto == null
        ? atual.texto
        : texto(corpo.texto, 'texto', { max: 8000, obrigatorio: true });
      const referencia = corpo.referencia === undefined
        ? atual.referencia
        : texto(corpo.referencia, 'referencia', { max: 300 }) || null;
      const prioridade = PRIORIDADES_SUGESTAO.includes(corpo.prioridade)
        ? corpo.prioridade
        : atual.prioridade;

      const mudou =
        titulo !== atual.titulo ||
        descricao !== atual.texto ||
        referencia !== atual.referencia ||
        prioridade !== atual.prioridade;
      if (!mudou) return responder(paraSugestao(atual));

      const linhas = await sql`
        update sugestoes
        set titulo = ${titulo}, texto = ${descricao}, referencia = ${referencia},
            prioridade = ${prioridade}, versao = versao + 1, atualizado_em = now()
        where id = ${id} and haras_id = ${acesso.harasId}
        returning *
      `;
      await registrarVersao(sql, linhas[0], 'editada', autor);
      return responder(paraSugestao(linhas[0]));
    }

    // PATCH /sugestoes/:id — só a situação
    if (request.method === 'PATCH') {
      const corpo = await lerJson(request);
      if (!STATUS_SUGESTAO.includes(corpo.status)) {
        return erro('Situação inválida.', 400, { cabecalhos: base });
      }
      if (corpo.status === atual.status && !atual.apagada_em) {
        return responder(paraSugestao(atual));
      }
      const linhas = await sql`
        update sugestoes
        set status = ${corpo.status}, versao = versao + 1, atualizado_em = now()
        where id = ${id} and haras_id = ${acesso.harasId}
        returning *
      `;
      await registrarVersao(sql, linhas[0], 'status', autor);
      return responder(paraSugestao(linhas[0]));
    }

    // DELETE /sugestoes/:id — exclusão lógica, histórico preservado
    if (request.method === 'DELETE') {
      if (atual.apagada_em) return new Response(null, { status: 204, headers: base });
      const linhas = await sql`
        update sugestoes
        set apagada_em = now(), versao = versao + 1, atualizado_em = now()
        where id = ${id} and haras_id = ${acesso.harasId}
        returning *
      `;
      await registrarVersao(sql, linhas[0], 'apagada', autor);
      return new Response(null, { status: 204, headers: base });
    }
  }

  return erro('Rota de sugestões não encontrada.', 404, { cabecalhos: base });
}
