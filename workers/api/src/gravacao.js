// Escrita de cavalos, provas e mídias.
//
// Os ids de cavalo, prova e mídia são chave primária do banco inteiro, não de
// um haras ou de um cavalo. Um `on conflict (id) do update` sem condição deixa
// uma gravação pelo cavalo B sobrescrever a prova do cavalo A, ou o cavalo de
// outro haras (EQL-041). Toda atualização aqui confere o dono da linha
// existente: se não for o mesmo, nada muda e a gravação é recusada com 409.

import { ErroValidacao } from './validacao.js';

const recusar = (mensagem) => {
  throw new ErroValidacao(mensagem, 409);
};

export async function gravarCavalo(sql, harasId, c) {
  const gravados = await sql`
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
    where cavalos.haras_id = excluded.haras_id
    returning id
  `;
  if (!gravados.length) recusar('Este id de cavalo já está em uso em outro haras.');

  // Provas e mídias vêm aninhadas no cavalo pelo contrato do app; gravar o
  // cavalo precisa persistir também esses filhos.
  for (const p of c.provas ?? []) {
    await gravarProva(sql, c.id, p);
  }
  for (const m of c.midias ?? []) {
    await gravarMidia(sql, c.id, m);
  }
}

export async function gravarProva(sql, cavaloId, p) {
  const gravadas = await sql`
    insert into provas (id, cavalo_id, data, nome, local, categoria, colocacao,
                        tempo_seg, inscritos, premiacao, fonte)
    values (${p.id}, ${cavaloId}, ${p.data}, ${p.nome}, ${p.local ?? ''},
            ${p.categoria ?? ''}, ${p.colocacao ?? 0}, ${p.tempoSegundos ?? 0},
            ${p.inscritos ?? 0}, ${p.premiacao ?? null}, ${p.fonte ?? null})
    on conflict (id) do update set
      data = excluded.data, nome = excluded.nome, local = excluded.local,
      categoria = excluded.categoria, colocacao = excluded.colocacao,
      tempo_seg = excluded.tempo_seg, inscritos = excluded.inscritos,
      premiacao = excluded.premiacao, fonte = coalesce(excluded.fonte, provas.fonte)
    where provas.cavalo_id = excluded.cavalo_id
    returning id
  `;
  if (!gravadas.length) recusar(`A prova ${p.id} pertence a outro cavalo.`);
}

/**
 * Grava um lote de provas de um cavalo numa instrução só.
 * Um id que já pertence a outro cavalo não é tocado; o lote segue com o resto.
 * Devolve quantas linhas foram gravadas.
 */
export async function gravarProvasEmLote(sql, cavaloId, provas) {
  if (!provas.length) return 0;
  const linhas = await sql`
    insert into provas (id, cavalo_id, data, nome, local, categoria, colocacao,
                        tempo_seg, inscritos, premiacao, fonte)
    select d.id, ${cavaloId}, d.data::date, d.nome, d.local, d.categoria,
           d.colocacao::int, d.tempo_seg::numeric, d.inscritos::int, d.premiacao, d.fonte
    from unnest(
      ${provas.map((p) => p.id)}::text[],
      ${provas.map((p) => p.data)}::text[],
      ${provas.map((p) => p.nome)}::text[],
      ${provas.map((p) => p.local ?? '')}::text[],
      ${provas.map((p) => p.categoria ?? '')}::text[],
      ${provas.map((p) => p.colocacao ?? 0)}::int[],
      ${provas.map((p) => p.tempoSegundos ?? 0)}::numeric[],
      ${provas.map((p) => p.inscritos ?? 0)}::int[],
      ${provas.map((p) => p.premiacao ?? null)}::text[],
      ${provas.map((p) => p.fonte ?? null)}::text[]
    ) as d(id, data, nome, local, categoria, colocacao, tempo_seg, inscritos, premiacao, fonte)
    on conflict (id) do update set
      data = excluded.data, nome = excluded.nome, local = excluded.local,
      categoria = excluded.categoria, colocacao = excluded.colocacao,
      tempo_seg = excluded.tempo_seg, inscritos = excluded.inscritos,
      premiacao = excluded.premiacao, fonte = coalesce(excluded.fonte, provas.fonte)
    where provas.cavalo_id = excluded.cavalo_id
    returning id
  `;
  return linhas.length;
}

export async function gravarMidia(sql, cavaloId, m) {
  const gravadas = await sql`
    insert into midias (id, cavalo_id, tipo, arquivo, legenda, local, poster, duracao_seg)
    values (${m.id}, ${cavaloId}, ${m.tipo}, ${m.arquivo}, ${m.legenda ?? ''},
            ${m.local ?? null}, ${m.poster ?? null}, ${m.duracaoSegundos ?? null})
    on conflict (id) do update set
      tipo = excluded.tipo, arquivo = excluded.arquivo, legenda = excluded.legenda,
      local = excluded.local, poster = excluded.poster, duracao_seg = excluded.duracao_seg
    where midias.cavalo_id = excluded.cavalo_id
    returning id
  `;
  if (!gravadas.length) recusar(`A mídia ${m.id} pertence a outro cavalo.`);
}
