// Leitura do SGP com páginas de exemplo no formato real (estrutura copiada de
// páginas públicas de 2026-11-12; nomes e números inventados).

import test from 'node:test';
import assert from 'node:assert/strict';

import { ErroSgp, lerBusca, lerPerfil, provasDoSgp } from '../src/sgp.js';

const busca = `<table><thead><tr><th>Nome</th><th>Registro</th><th>Nascimento</th></tr></thead>
<tr>
  <td><b><a href="?page=horse_profile&id=111">CAVALO TESTE FEP</a></b></td>
  <td class="ninp">P123456</td><td class="ninp">01-02-2020</td></tr>
<tr>
  <td><b><a href="?page=horse_profile&id=222">CAVALO TESTE FEP</a></b></td>
  <td class="ninp">P999999</td><td class="ninp">05-06-2019</td></tr>
<tr>
  <td><b><a href="?page=horse_profile&amp;id=333">CAVALO TESTE</a></b></td>
  <td class="ninp">P123456</td><td class="ninp">01-02-2020</td></tr>
</table>`;

const linha = (tempo, pos, evt, categ, categoria, prova, data) => `<tr>
\t<td class="ninp"></td>
\t\t<td><a href="?page=comp_profile&id=9" ><b>COMPETIDOR FICTICIO</b></a></td><td>${tempo}</td><td>${pos}</td>
\t\t<td><a href="?page=mainres&evt=${evt}&categ=${categ}">${categoria}</a></td><td>${prova}</td>
\t\t<td class="ninp">${data}</td></tr>`;

const perfil = (linhas) => `<h1>Perfil do Cavalo</h1><h3 class="nmb"><a href="assets/img/cert.jpg"><img src="m.jpg"/></a> CAVALO TESTE FEP </a> <a href="https://seqm.com.br/ranking/animal/1/detalhes" title="Ver Cavalo na ABQM">(P123456)</a> </h3>
<p><b>Nascimento: </b>01-02-2020 <b>Proprietário: </b> PESSOA FICTICIA</p>
<table class="graphtable" cellspacing="0" cellpadding="5" id="tb1"><thead><tr><th class="ninp">Ordem</th><th>Competidor</th><th>Tempo</th><th>Pos</th><th>Categoria</th><th>Prova</th><th class="ninp">Data</th></tr></thead><tbody>${linhas}</tbody></table>`;

const comTresPassadas = perfil(
  linha('16.511', '3º', 8948, 141300, 'Três Tambores - GP ABQM', '18º Copa dos Campeões ABQM', '18-10-2026') +
    linha('SAT', '', 8455, 131812, 'Três Tambores - Tira Teima', 'Rock Star Buckle 2026', '30-05-2026') +
    linha('17.020', '12º', 8455, 131812, 'Três Tambores - Tira Teima', 'Rock Star Buckle 2026', '30-05-2026'),
);

/** fetch falso: devolve páginas por trecho da URL e guarda as chamadas. */
function falso(paginas) {
  const chamadas = [];
  const buscar = async (url, init) => {
    chamadas.push({ url, init });
    const chave = Object.keys(paginas).find((k) => url.includes(k));
    if (!chave) return new Response('não', { status: 404 });
    // Como o SGP: ISO-8859-1.
    const bytes = Uint8Array.from([...paginas[chave]].map((c) => c.charCodeAt(0)));
    return new Response(bytes, { status: 200 });
  };
  return { buscar, chamadas };
}

test('a busca lê id, nome, registro e nascimento', () => {
  assert.deepEqual(lerBusca(busca), [
    { id: 111, nome: 'CAVALO TESTE FEP', registro: 'P123456', nascimento: '01-02-2020' },
    { id: 222, nome: 'CAVALO TESTE FEP', registro: 'P999999', nascimento: '05-06-2019' },
    { id: 333, nome: 'CAVALO TESTE', registro: 'P123456', nascimento: '01-02-2020' },
  ]);
});

test('o perfil vira uma prova por passada, sem dados de pessoas', () => {
  const r = lerPerfil(comTresPassadas, 111);
  assert.equal(r.nome, 'CAVALO TESTE FEP');
  assert.equal(r.registro, 'P123456');
  assert.deepEqual(r.provas[0], {
    id: 'sgp-111-8948-141300',
    data: '2026-10-18',
    nome: '18º Copa dos Campeões ABQM',
    local: '',
    categoria: 'Três Tambores - GP ABQM',
    colocacao: 3,
    tempoSegundos: 16.511,
    inscritos: 0,
    premiacao: null,
    fonte: 'SGP',
  });
  assert.ok(!JSON.stringify(r).includes('FICTICIO'));
});

test('passada sem tempo nem colocação fica com zero', () => {
  const sat = lerPerfil(comTresPassadas, 111).provas[1];
  assert.equal(sat.tempoSegundos, 0);
  assert.equal(sat.colocacao, 0);
});

test('duas passadas na mesma categoria ganham ids diferentes e estáveis', () => {
  const ids = lerPerfil(comTresPassadas, 111).provas.map((p) => p.id);
  assert.deepEqual(ids, ['sgp-111-8948-141300', 'sgp-111-8455-131812', 'sgp-111-8455-131812-2']);
});

test('cavalo sem passadas devolve lista vazia', () => {
  assert.deepEqual(lerPerfil(perfil(''), 111).provas, []);
});

test('página que mudou de formato falha em vez de devolver lixo', () => {
  assert.throws(() => lerPerfil('<html>outra coisa</html>', 111), ErroSgp);
  const semData = perfil(linha('16.511', '3º', 1, 2, 'X', 'Y', 'ontem'));
  assert.throws(() => lerPerfil(semData, 111), ErroSgp);
});

test('só aceita o cavalo com nome e registro iguais aos nossos', async () => {
  const { buscar, chamadas } = falso({ 'page=search': busca, 'horse_profile&id=111': comTresPassadas });
  const r = await provasDoSgp({ nome: 'Cavalo Teste FEP', registro: 'p 123.456' }, buscar);
  assert.equal(r.encontrado, true);
  assert.equal(r.url, 'https://www.sgpsistema.com/?page=horse_profile&id=111');
  assert.equal(r.provas.length, 3);
  assert.ok(r.provas.every((p) => p.id.startsWith('sgp-111-')), 'id leva o cavalo do SGP');
  assert.equal(chamadas.length, 2);
  assert.match(chamadas[0].url, /page=search&search=Cavalo%20Teste%20FEP$/);
  assert.equal(chamadas[0].init.cf.cacheTtl, 3600);
});

test('nome igual com outro registro não é o nosso cavalo', async () => {
  const { buscar, chamadas } = falso({ 'page=search': busca });
  const r = await provasDoSgp({ nome: 'CAVALO TESTE FEP', registro: 'P000001' }, buscar);
  assert.equal(r.encontrado, false);
  assert.equal(chamadas.length, 1, 'não abre perfil nenhum');
});

test('sem registro nem chega a consultar o SGP', async () => {
  const { buscar, chamadas } = falso({});
  const r = await provasDoSgp({ nome: 'CAVALO TESTE FEP', registro: '' }, buscar);
  assert.equal(r.encontrado, false);
  assert.equal(chamadas.length, 0);
});

test('perfil que não confere com a busca é recusado', async () => {
  const outro = comTresPassadas.replace('(P123456)', '(P555555)');
  const { buscar } = falso({ 'page=search': busca, 'horse_profile&id=111': outro });
  await assert.rejects(provasDoSgp({ nome: 'CAVALO TESTE FEP', registro: 'P123456' }, buscar), ErroSgp);
});

test('erro HTTP do SGP vira ErroSgp', async () => {
  const buscar = async () => new Response('fora', { status: 503 });
  await assert.rejects(provasDoSgp({ nome: 'CAVALO TESTE FEP', registro: 'P123456' }, buscar), ErroSgp);
});
