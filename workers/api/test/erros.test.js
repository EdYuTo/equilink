// EQL-012: erro previsível do banco vira status e mensagem para o operador,
// nunca o texto do Postgres (que traz SQL, coluna e valores).

import test from 'node:test';
import assert from 'node:assert/strict';

import { erroDoBanco } from '../src/erros.js';
import { pareceUuid } from '../src/validacao.js';

test('registro repetido no haras vira 409 com mensagem do cavalo', () => {
  assert.deepEqual(
    erroDoBanco({ code: '23505', constraint: 'cavalos_haras_id_registro_key', message: 'x' }),
    { status: 409, mensagem: 'Já existe um cavalo com este registro.' },
  );
});

test('outra violação de unicidade vira 409 genérico', () => {
  assert.deepEqual(erroDoBanco({ code: '23505', constraint: 'sugestoes_pkey' }), {
    status: 409,
    mensagem: 'Registro duplicado.',
  });
  assert.equal(erroDoBanco({ code: '23505' }).status, 409);
});

test('representação inválida vira 400 sem repetir o texto do banco', () => {
  const r = erroDoBanco({ code: '22P02', message: 'invalid input syntax for type uuid: "abc"' });
  assert.equal(r.status, 400);
  assert.doesNotMatch(r.mensagem, /uuid|syntax|abc/);
});

test('erro sem código conhecido não é traduzido', () => {
  assert.equal(erroDoBanco({ code: '40P01' }), null);
  assert.equal(erroDoBanco(new Error('qualquer')), null);
  assert.equal(erroDoBanco(null), null);
  assert.equal(erroDoBanco(undefined), null);
});

test('pareceUuid aceita só o formato canônico', () => {
  assert.equal(pareceUuid('3f2a9c1e-7b4d-4e8a-9c0f-1a2b3c4d5e6f'), true);
  assert.equal(pareceUuid('3F2A9C1E-7B4D-4E8A-9C0F-1A2B3C4D5E6F'), true);
  assert.equal(pareceUuid('abc'), false);
  assert.equal(pareceUuid('3f2a9c1e7b4d4e8a9c0f1a2b3c4d5e6f0'), false);
  assert.equal(pareceUuid(' 3f2a9c1e-7b4d-4e8a-9c0f-1a2b3c4d5e6f'), false);
  assert.equal(pareceUuid(null), false);
});
