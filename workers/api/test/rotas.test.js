// Roteamento do Worker com o banco simulado: o `fetch` global faz o papel do
// endpoint HTTP do Neon, então a requisição percorre `rotear` inteiro — papel,
// validação e o `catch` que traduz o erro — sem rede e sem banco.

import test from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/index.js';
import { emitirSessao } from '../src/auth.js';

const SEGREDO = 'segredo-de-teste-nao-use-em-producao';
const HARAS = '00000000-0000-4000-8000-000000000001';
const env = {
  DATABASE_URL: 'postgresql://teste:teste@ep-teste.us-east-2.aws.neon.tech/neondb',
  SESSION_SECRET: SEGREDO,
};

/**
 * Troca o `fetch` global por um Neon falso. `responder(consulta)` devolve as
 * linhas (lista de objetos) ou `{ falha: {...} }` para simular erro do banco.
 */
function bancoFalso(t, papel, responder = () => []) {
  const consultas = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (_url, init) => {
    const { query } = JSON.parse(init.body);
    consultas.push(query);
    const resposta = query.includes('haras_do_usuario')
      ? (papel ? [{ haras_id: HARAS, papel }] : [])
      : responder(query);
    if (resposta?.falha) {
      return new Response(JSON.stringify(resposta.falha), { status: 400 });
    }
    const nomes = Object.keys(resposta[0] ?? {});
    return Response.json({
      fields: nomes.map((name) => ({ name, dataTypeID: 25 })),
      rows: resposta.map((l) => nomes.map((n) => l[n])),
    });
  };
  t.after(() => {
    globalThis.fetch = original;
  });
  return consultas;
}

async function pedir(caminho, { metodo = 'GET', corpo, logado = true } = {}) {
  const headers = new Headers();
  if (logado) headers.set('cookie', `equilink_sessao=${await emitirSessao('ana', SEGREDO)}`);
  if (corpo) headers.set('content-type', 'application/json');
  const resposta = await worker.fetch(
    new Request(`https://api.teste${caminho}`, {
      method: metodo,
      headers,
      body: corpo ? JSON.stringify(corpo) : undefined,
    }),
    env,
  );
  return { status: resposta.status, corpo: await resposta.json() };
}

// EQL-005 -------------------------------------------------------------------

test('GET /eventos: leitor recebe 403 e o banco não é lido', async (t) => {
  const consultas = bancoFalso(t, 'leitor');
  const r = await pedir('/eventos');
  assert.equal(r.status, 403);
  assert.equal(r.corpo.erro, 'Seu papel não permite esta operação.');
  assert.ok(!consultas.some((q) => q.includes('eventos_analiticos')));
});

test('GET /eventos: operador lê a telemetria', async (t) => {
  bancoFalso(t, 'operador', () => []);
  const r = await pedir('/eventos');
  assert.equal(r.status, 200);
  assert.deepEqual(r.corpo, { eventos: [] });
});

test('GET /eventos: anônimo continua recebendo 401', async (t) => {
  bancoFalso(t, null);
  const r = await pedir('/eventos', { logado: false });
  assert.equal(r.status, 401);
  assert.equal(r.corpo.erro, 'Autenticação necessária para ler a telemetria.');
});
