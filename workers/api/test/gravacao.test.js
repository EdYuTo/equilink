// EQL-041: o id de cavalo, prova e mídia é único no banco inteiro. Gravar pelo
// cavalo B não pode mudar a linha do cavalo A, nem o cavalo de outro haras.
// O comportamento real foi conferido numa branch do Neon; aqui fica o contrato:
// a atualização é condicionada ao dono, e nenhuma linha gravada vira 409.

import test from 'node:test';
import assert from 'node:assert/strict';

import { gravarCavalo, gravarMidia, gravarProva, gravarProvasEmLote } from '../src/gravacao.js';
import { ErroValidacao } from '../src/validacao.js';

/** `sql` falso: guarda o texto das consultas e devolve as linhas pedidas. */
function sqlFalso(respostas) {
  const consultas = [];
  const sql = (partes) => {
    consultas.push(partes.join('?'));
    return Promise.resolve(respostas.shift() ?? []);
  };
  return { sql, consultas };
}

const prova = { id: 'p1', data: '2026-01-01', nome: 'Copa', tempoSegundos: 17 };
const midia = { id: 'm1', tipo: 'foto', arquivo: 'https://x/y.jpg' };
const cavalo = { id: 'c1', nome: 'A', registro: 'P1', sexo: 'macho', nascimento: '2020-01-01' };

test('prova de outro cavalo: nada muda e a resposta é 409', async () => {
  const { sql, consultas } = sqlFalso([[]]);
  await assert.rejects(gravarProva(sql, 'c1', prova), (e) => e instanceof ErroValidacao && e.status === 409);
  assert.match(consultas[0], /where provas\.cavalo_id = excluded\.cavalo_id/);
});

test('prova do próprio cavalo grava normalmente', async () => {
  const { sql } = sqlFalso([[{ id: 'p1' }]]);
  await gravarProva(sql, 'c1', prova);
});

test('mídia de outro cavalo: nada muda e a resposta é 409', async () => {
  const { sql, consultas } = sqlFalso([[]]);
  await assert.rejects(gravarMidia(sql, 'c1', midia), (e) => e.status === 409);
  assert.match(consultas[0], /where midias\.cavalo_id = excluded\.cavalo_id/);
});

test('cavalo de outro haras: nada muda, nem as provas aninhadas', async () => {
  const { sql, consultas } = sqlFalso([[]]);
  await assert.rejects(
    gravarCavalo(sql, 'haras-b', { ...cavalo, provas: [prova] }),
    (e) => e.status === 409,
  );
  assert.match(consultas[0], /where cavalos\.haras_id = excluded\.haras_id/);
  assert.equal(consultas.length, 1, 'não chega a gravar as provas');
});

test('cavalo do próprio haras grava também provas e mídias', async () => {
  const { sql, consultas } = sqlFalso([[{ id: 'c1' }], [{ id: 'p1' }], [{ id: 'm1' }]]);
  await gravarCavalo(sql, 'haras-a', { ...cavalo, provas: [prova], midias: [midia] });
  assert.equal(consultas.length, 3);
});

test('lote ignora id de outro cavalo e conta só o que gravou', async () => {
  const { sql, consultas } = sqlFalso([[{ id: 'p2' }]]);
  const n = await gravarProvasEmLote(sql, 'c1', [prova, { ...prova, id: 'p2' }]);
  assert.equal(n, 1);
  assert.match(consultas[0], /where provas\.cavalo_id = excluded\.cavalo_id/);
});
