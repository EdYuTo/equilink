// Leitura do histórico de provas de um cavalo no SGP (sgpsistema.com).
//
// Só páginas públicas que um visitante abre: a busca e o perfil do cavalo.
// Duas leituras por importação, sob demanda de quem tem permissão de escrita,
// e com cache de 1 hora na Cloudflare para um segundo clique não ir ao SGP.
// Nada do competidor, proprietário ou criador é lido: só a passada.

export const SGP = 'https://www.sgpsistema.com/';
const AGENTE = 'EquiLink/1.0 (importação pontual de provas)';
const CACHE_SEGUNDOS = 3600;

export class ErroSgp extends Error {}

/** Nome comparável: sem acento, maiúsculo, só letras e números. */
export function normalizarNome(t) {
  return (t ?? '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim();
}

/** Registro comparável: "P 398.739" e "p398739" viram "P398739". */
export const normalizarRegistro = (r) => (r ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');

const entidades = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
function limpo(html) {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&(#\d+|#x[0-9a-f]+|\w+);/gi, (m, e) => {
      if (e[0] === '#') {
        const n = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return Number.isFinite(n) ? String.fromCodePoint(n) : m;
      }
      return entidades[e.toLowerCase()] ?? m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}

/** Linhas da busca por nome: id do SGP, nome, registro e nascimento. */
export function lerBusca(html) {
  const linhas = [];
  const re = /<tr>\s*<td><b><a href="\?page=horse_profile&(?:amp;)?id=(\d+)">([\s\S]*?)<\/a><\/b><\/td>\s*<td[^>]*>([\s\S]*?)<\/td>\s*<td[^>]*>([\s\S]*?)<\/td>/g;
  for (const m of html.matchAll(re)) {
    linhas.push({ id: Number(m[1]), nome: limpo(m[2]), registro: limpo(m[3]), nascimento: limpo(m[4]) });
  }
  return linhas;
}

/** `18-10-2026` → `2026-10-18`; qualquer outra coisa → null. */
function dataDoSgp(t) {
  const m = /^(\d{2})-(\d{2})-(\d{4})$/.exec(t);
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
}

/**
 * Perfil do cavalo: nome e registro do cabeçalho e uma prova por passada.
 * Passada sem tempo válido (como "SAT") vira tempo 0; sem colocação, 0.
 * O id leva o id do cavalo no SGP: o id de prova é único no banco inteiro, e
 * dois cavalos correm na mesma categoria.
 */
export function lerPerfil(html, sgpId) {
  const cabecalho = /<h3 class="nmb">([\s\S]*?)<\/h3>/.exec(html);
  if (!cabecalho) throw new ErroSgp('A página do SGP mudou: cabeçalho do cavalo não encontrado.');
  const titulo = /^(.*?)\s*\(([^)]+)\)\s*$/.exec(limpo(cabecalho[1]));
  if (!titulo) throw new ErroSgp('A página do SGP mudou: nome e registro não encontrados.');

  const provas = [];
  const vistos = new Map();
  const tabela = /<table class="graphtable"[^>]*id="tb1"[^>]*>([\s\S]*?)<\/table>/.exec(html);
  if (tabela) {
    for (const tr of tabela[1].split(/<tr[\s>]/).slice(1)) {
      const celulas = [...tr.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/g)].map((m) => m[1]);
      // Ordem, Competidor, Tempo, Pos, Categoria, Prova, Data.
      if (celulas.length < 7) continue;
      const link = /\?page=mainres&(?:amp;)?evt=(\d+)&(?:amp;)?categ=(\d+)/.exec(celulas[4]);
      const data = dataDoSgp(limpo(celulas[6]));
      if (!link || !data) throw new ErroSgp('A página do SGP mudou: linha de prova sem evento ou data.');
      const tempoTexto = limpo(celulas[2]);
      const tempo = /^\d+(\.\d+)?$/.test(tempoTexto) ? Number(tempoTexto) : 0;
      const colocacao = Number(/^(\d+)/.exec(limpo(celulas[3]))?.[1] ?? 0);
      const base = `sgp-${sgpId}-${link[1]}-${link[2]}`;
      const n = (vistos.get(base) ?? 0) + 1;
      vistos.set(base, n);
      provas.push({
        id: n === 1 ? base : `${base}-${n}`,
        data,
        nome: limpo(celulas[5]).slice(0, 120),
        local: '',
        categoria: limpo(celulas[4]).slice(0, 60),
        colocacao: colocacao <= 999 ? colocacao : 0,
        tempoSegundos: tempo <= 100000 ? tempo : 0,
        inscritos: 0,
        premiacao: null,
        fonte: 'SGP',
      });
    }
  }
  return { nome: titulo[1], registro: titulo[2], provas };
}

/** O SGP serve ISO-8859-1. */
async function ler(consulta, buscar) {
  const resposta = await buscar(SGP + '?' + consulta, {
    headers: { 'user-agent': AGENTE },
    cf: { cacheTtl: CACHE_SEGUNDOS, cacheEverything: true },
  });
  if (!resposta.ok) throw new ErroSgp(`O SGP respondeu ${resposta.status}.`);
  return new TextDecoder('latin1').decode(await resposta.arrayBuffer());
}

/**
 * Procura o cavalo no SGP pelo nome e devolve as passadas dele.
 * Só aceita o cavalo se nome **e** registro baterem: no SGP há homônimos, e o
 * mesmo registro com outro nome é outro animal. A busca por registro do SGP
 * parou de responder em 2026-11; por isso a busca é pelo nome.
 */
export async function provasDoSgp({ nome, registro }, buscar = fetch) {
  const alvoNome = normalizarNome(nome);
  const alvoRegistro = normalizarRegistro(registro);
  if (!alvoNome || !alvoRegistro) {
    return { encontrado: false, motivo: 'O cavalo precisa de nome e registro para ser procurado no SGP.' };
  }
  const candidatos = lerBusca(await ler('page=search&search=' + encodeURIComponent(nome.trim()), buscar))
    .filter((c) => normalizarNome(c.nome) === alvoNome && normalizarRegistro(c.registro) === alvoRegistro);
  if (candidatos.length !== 1) {
    return {
      encontrado: false,
      motivo: candidatos.length
        ? 'Há mais de um cavalo com esse nome e registro no SGP.'
        : 'Nenhum cavalo com esse nome e registro no SGP.',
    };
  }
  const id = candidatos[0].id;
  const perfil = lerPerfil(await ler(`page=horse_profile&id=${id}`, buscar), id);
  if (normalizarNome(perfil.nome) !== alvoNome || normalizarRegistro(perfil.registro) !== alvoRegistro) {
    throw new ErroSgp('O perfil do SGP não confere com o cavalo procurado.');
  }
  return { encontrado: true, url: `${SGP}?page=horse_profile&id=${id}`, provas: perfil.provas };
}
