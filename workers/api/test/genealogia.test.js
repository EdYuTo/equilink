// A genealogia precisa sobreviver a qualquer escrita de cavalo: pelagem, avós e
// gerações seguintes voltam exatamente como o cliente enviou.

import test from 'node:test';
import assert from 'node:assert/strict';

import { MAX_GERACOES, normalizarAncestral } from '../src/genealogia.js';
import { ErroValidacao } from '../src/validacao.js';

const arvore = {
  nome: 'SLICK BY DESIGN',
  registro: 'AQHA 5037395',
  pelagem: 'Preto',
  pai: {
    nome: 'DESIGNER RED',
    registro: 'AQHA 3419023',
    pai: { nome: 'ON THE MONEY RED', registro: 'AQHA 1518661' },
    mae: { nome: 'PIN A ROSE ON.ME', registro: 'AQHA 1530831' },
  },
  mae: { nome: 'DREAMS OF BLUE', registro: 'AQHA 3475024' },
};

test('a árvore completa volta igual', () => {
  assert.deepEqual(normalizarAncestral(arvore, 'pai'), arvore);
});

test('ancestral simples não ganha campos vazios', () => {
  assert.deepEqual(normalizarAncestral({ nome: 'A', registro: 'B' }, 'pai'), { nome: 'A', registro: 'B' });
});

test('ausente ou vazio vira nome e registro em branco, como já é gravado hoje', () => {
  for (const vazio of [undefined, null, {}]) {
    assert.deepEqual(normalizarAncestral(vazio, 'pai'), { nome: '', registro: '' });
  }
});

test('campos desconhecidos não chegam ao banco, em nenhuma geração', () => {
  const saida = normalizarAncestral(
    { nome: 'A', registro: 'B', extra: 1, pai: { nome: 'C', registro: 'D', extra: 2 } },
    'pai',
  );
  assert.deepEqual(saida, { nome: 'A', registro: 'B', pai: { nome: 'C', registro: 'D' } });
});

test('o erro aponta o campo aninhado', () => {
  assert.throws(
    () => normalizarAncestral({ nome: 'A', pai: { nome: { x: 1 } } }, 'pai'),
    (e) => e instanceof ErroValidacao && e.message.includes('pai.pai.nome'),
  );
});

test('progenitor que não é objeto é recusado', () => {
  assert.throws(() => normalizarAncestral({ nome: 'A', mae: 'B' }, 'pai'), ErroValidacao);
  assert.throws(() => normalizarAncestral({ nome: 'A', mae: ['B'] }, 'pai'), ErroValidacao);
});

test('aceita até o limite de gerações e recusa além dele', () => {
  const pilha = (n) => (n === 0 ? undefined : { nome: 'X', registro: 'Y', ...(n > 1 ? { pai: pilha(n - 1) } : {}) });
  assert.doesNotThrow(() => normalizarAncestral(pilha(MAX_GERACOES), 'pai'));
  assert.throws(() => normalizarAncestral(pilha(MAX_GERACOES + 1), 'pai'), ErroValidacao);
});
