// Testes da autenticação: senha, sessão e autorização.
//
// Rodam no Node puro (`node --test`), sem rede e sem banco — exercitam as
// funções puras que o Worker usa. A verificação contra o banco real é feita no
// navegador e por curl no deploy; aqui o objetivo é pegar regressão de lógica
// antes de publicar.

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  base64ParaBytes,
  bytesParaBase64,
  conferirSenha,
  cookieDeSessao,
  cookieRenovado,
  derivarHash,
  emitirSessao,
  gerarSalt,
  hashIp,
  iguaisEmTempoConstante,
  lerCookie,
  lerSessao,
  segundosAteExpirar,
} from '../src/auth.js';

const SEGREDO = 'segredo-de-teste-nao-use-em-producao';
const PEPPER = 'pepper-de-teste';

test('hash de senha confere com a mesma senha e falha com outra', async () => {
  const salt = gerarSalt();
  const hash = await derivarHash('senha-correta', salt, 100000, PEPPER);

  assert.equal(await conferirSenha('senha-correta', { hash, salt, iteracoes: 100000 }, PEPPER), true);
  assert.equal(await conferirSenha('senha-errada', { hash, salt, iteracoes: 100000 }, PEPPER), false);
});

test('pepper errado invalida a senha certa', async () => {
  const salt = gerarSalt();
  const hash = await derivarHash('senha-correta', salt, 100000, PEPPER);

  // Sem o pepper do servidor, o dump do banco não autentica.
  assert.equal(await conferirSenha('senha-correta', { hash, salt, iteracoes: 100000 }, 'outro-pepper'), false);
  assert.equal(await conferirSenha('senha-correta', { hash, salt, iteracoes: 100000 }, undefined), false);
});

test('salt diferente gera hash diferente para a mesma senha', async () => {
  const a = await derivarHash('mesma-senha', gerarSalt(), 100000, PEPPER);
  const b = await derivarHash('mesma-senha', gerarSalt(), 100000, PEPPER);
  assert.notEqual(a, b);
});

test('registro ausente ou incompleto nunca autentica', async () => {
  assert.equal(await conferirSenha('x', null, PEPPER), false);
  assert.equal(await conferirSenha('x', {}, PEPPER), false);
  assert.equal(await conferirSenha('x', { hash: 'abc' }, PEPPER), false);
});

test('sessão emitida é aceita e preserva o usuário', async () => {
  const valor = await emitirSessao('eduardo', SEGREDO);
  const sessao = await lerSessao(valor, SEGREDO);

  assert.equal(sessao.usuarioId, 'eduardo');
  assert.ok(sessao.expiraEm > Date.now());
});

test('sessão adulterada é recusada', async () => {
  const valor = await emitirSessao('eduardo', SEGREDO);
  const [corpo, assinatura] = valor.split('.');

  // Troca o usuário mantendo a assinatura antiga.
  const outroCorpo = bytesParaBase64(new TextEncoder().encode('{"u":"invasor","e":9999999999}'));
  const forjada = `${outroCorpo}.${assinatura}`;
  assert.equal(await lerSessao(forjada, SEGREDO), null);

  // Assinatura alterada.
  assert.equal(await lerSessao(`${corpo}.${assinatura.slice(0, -2)}xy`, SEGREDO), null);
});

test('sessão assinada com outro segredo é recusada', async () => {
  const valor = await emitirSessao('eduardo', SEGREDO);
  assert.equal(await lerSessao(valor, 'outro-segredo'), null);
});

test('sessão vencida é recusada', async () => {
  const agora = Date.now();
  const valor = await emitirSessao('eduardo', SEGREDO, agora - 9 * 60 * 60 * 1000);
  assert.equal(await lerSessao(valor, SEGREDO, agora), null);
});

test('sem segredo configurado, nenhuma sessão vale', async () => {
  const valor = await emitirSessao('eduardo', SEGREDO);
  assert.equal(await lerSessao(valor, ''), null);
  assert.equal(await lerSessao(valor, undefined), null);
});

test('cookie de sessão é HttpOnly, Secure e SameSite=Strict', async () => {
  const valor = await emitirSessao('eduardo', SEGREDO);
  const cookie = cookieDeSessao(valor, { seguro: true });

  assert.match(cookie, /HttpOnly/);
  assert.match(cookie, /Secure/);
  assert.match(cookie, /SameSite=Strict/);
  assert.match(cookie, /Path=\//);
});

test('logout gera cookie vencido', async () => {
  const { cookieVazio } = await import('../src/auth.js');
  assert.match(cookieVazio(true), /Max-Age=0/);
});

test('leitura de cookie ignora outros pares', () => {
  assert.equal(lerCookie('a=1; equilink_sessao=valor; b=2'), 'valor');
  assert.equal(lerCookie('outro=1'), null);
  assert.equal(lerCookie(null), null);
});

test('comparação em tempo constante acerta igualdade e diferença', () => {
  assert.equal(iguaisEmTempoConstante('abc', 'abc'), true);
  assert.equal(iguaisEmTempoConstante('abc', 'abd'), false);
  assert.equal(iguaisEmTempoConstante('abc', 'abcd'), false);
  assert.equal(iguaisEmTempoConstante('', ''), true);
});

test('base64 vai e volta', () => {
  assert.equal(base64ParaBytes(bytesParaBase64(new Uint8Array([1, 2, 3]))).join(','), '1,2,3');
});

// EQL-001: o hash antigo era o hex de "ip:SESSION_SECRET", reversível.
test('hash de IP é de mão única e não carrega o IP nem o segredo', async () => {
  const env = { SESSION_SECRET: 'segredo-de-sessao-123' };
  const hash = await hashIp('200.1.2.3', env);
  assert.match(hash, /^[0-9a-f]{64}$/);
  const decodificado = Buffer.from(hash, 'hex').toString('latin1');
  assert.ok(!decodificado.includes('200.1.2.3'));
  assert.ok(!decodificado.includes('segredo-de-sessao-123'));
  assert.ok(!hash.includes(Buffer.from('segredo-de-sessao-123').toString('hex')));
  // Estável para o mesmo IP (o bloqueio precisa contar), diferente entre IPs.
  assert.equal(await hashIp('200.1.2.3', env), hash);
  assert.notEqual(await hashIp('200.1.2.4', env), hash);
  // Com chave própria, muda; e trocar o segredo de sessão não muda essa chave.
  const proprio = await hashIp('200.1.2.3', { SESSION_SECRET: 'x', IP_HASH_SECRET: 'k' });
  assert.notEqual(proprio, hash);
  assert.equal(await hashIp('200.1.2.3', { SESSION_SECRET: 'y', IP_HASH_SECRET: 'k' }), proprio);
});

// EQL-002: a renovação mantém a sessão viva com uso, sem passar do teto de 8 h.
test('cookie renovado reinicia a inatividade e mantém o teto de 8 h', async () => {
  const t0 = Date.now();
  const original = await lerSessao(await emitirSessao('igor', SEGREDO, t0), SEGREDO, t0 + 50 * 60 * 1000);
  assert.ok(original.renovavel);

  const t1 = t0 + 50 * 60 * 1000;
  const cookie = await cookieRenovado(original, SEGREDO, { agora: t1 });
  const valor = /equilink_sessao=([^;]+)/.exec(cookie)[1];
  const maxAge = Number(/Max-Age=(\d+)/.exec(cookie)[1]);
  assert.equal(maxAge, Math.floor((original.expiraEm - t1) / 1000), 'Max-Age é o que falta do teto');

  // 100 min depois do login, mas 50 desde a renovação: ainda vale.
  const depois = await lerSessao(valor, SEGREDO, t0 + 100 * 60 * 1000);
  assert.equal(depois?.usuarioId, 'igor');
  assert.equal(depois.expiraEm, original.expiraEm, 'o teto não anda');

  // Mesmo renovando sempre, passadas 8 h a sessão acaba.
  let s = original;
  let agora = t1;
  while (agora < t0 + 8 * 3600 * 1000) {
    const c = await cookieRenovado(s, SEGREDO, { agora });
    agora += 30 * 60 * 1000;
    s = await lerSessao(/equilink_sessao=([^;]+)/.exec(c)[1], SEGREDO, agora);
    if (!s) break;
  }
  assert.equal(s, null);
  assert.ok(agora <= t0 + 8 * 3600 * 1000 + 30 * 60 * 1000);
});

test('sessão cai depois de 1 hora sem uso', async () => {
  const agora = Date.now();
  const valor = await emitirSessao('eduardo', SEGREDO, agora);

  // 59 minutos depois: válida.
  const quase = await lerSessao(valor, SEGREDO, agora + 59 * 60 * 1000);
  assert.equal(quase?.usuarioId, 'eduardo');

  // 61 minutos depois: a inatividade encerra, mesmo dentro das 8 h.
  const tarde = await lerSessao(valor, SEGREDO, agora + 61 * 60 * 1000);
  assert.equal(tarde, null);
});

test('uso recente renova o prazo de inatividade', async () => {
  const agora = Date.now();
  // Sessão emitida há 50 minutos, com último uso há 50 minutos.
  const valor = await emitirSessao('eduardo', SEGREDO, agora - 50 * 60 * 1000);

  // 20 minutos depois do login (70 min no total), mas 20 min desde o uso:
  // a sessão emitida agora não é válida, mas uma renovada seria.
  const renovada = await emitirSessao('eduardo', SEGREDO, agora);
  const sessao = await lerSessao(renovada, SEGREDO, agora + 30 * 60 * 1000);
  assert.equal(sessao?.usuarioId, 'eduardo');
});

test('sessão antiga sem marca de último uso é recusada', async () => {
  // Cookie emitido antes da regra de inatividade não tem o campo `a`.
  const corpo = bytesParaBase64(new TextEncoder().encode(
    JSON.stringify({ u: 'eduardo', e: Math.floor(Date.now() / 1000) + 3600 }),
  ));
  const chave = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(SEGREDO),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const assinatura = btoa(String.fromCharCode(...new Uint8Array(
    await crypto.subtle.sign('HMAC', chave, new TextEncoder().encode(
      JSON.stringify({ u: 'eduardo', e: Math.floor(Date.now() / 1000) + 3600 }),
    )),
  ))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  assert.equal(await lerSessao(`${corpo}.${assinatura}`, SEGREDO), null);
});

test('segundos até expirar conta a partir do último uso', async () => {
  const agora = Date.now();
  const sessao = {
    usuarioId: 'eduardo',
    ultimoUso: agora - 30 * 60 * 1000,
    expiraEm: agora + 7 * 60 * 60 * 1000,
  };
  // 30 minutos usados de 60: restam 30.
  assert.equal(segundosAteExpirar(sessao, agora), 30 * 60);
  // Depois do limite, zero e nunca negativo.
  assert.equal(segundosAteExpirar(sessao, agora + 90 * 60 * 1000), 0);
});
