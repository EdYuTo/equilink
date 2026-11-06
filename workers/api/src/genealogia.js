import { ErroValidacao, objeto, texto } from './validacao.js';

/** Gerações aceitas acima do animal. Limita o tamanho de uma árvore enviada pelo cliente. */
export const MAX_GERACOES = 5;

function dataOpcional(valor, campo) {
  if (valor == null || valor === '') return null;
  if (typeof valor !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(valor)) {
    throw new ErroValidacao(`Campo ${campo} deve ser uma data AAAA-MM-DD.`);
  }
  return valor;
}

function numeroOpcional(valor, campo, { inteiro = false } = {}) {
  if (valor == null) return null;
  if (typeof valor !== 'number' || !Number.isFinite(valor) || valor < 0 || (inteiro && !Number.isInteger(valor))) {
    throw new ErroValidacao(`Campo ${campo} deve ser um número válido.`);
  }
  return valor;
}

/**
 * Valida um ancestral e os ascendentes dele, preservando a árvore inteira.
 *
 * Ausente vira nome e registro em branco, o formato que o banco já guarda. Passar
 * do limite é recusado, porque cortar a árvore apagaria dados sem aviso.
 */
export function normalizarAncestral(bruto, campo, geracao = 1) {
  if (geracao > MAX_GERACOES) {
    throw new ErroValidacao(`Campo ${campo} passa de ${MAX_GERACOES} gerações.`);
  }
  const a = objeto(bruto, campo);
  const saida = {
    nome: texto(a.nome, `${campo}.nome`, { max: 120 }),
    registro: texto(a.registro, `${campo}.registro`, { max: 40 }),
  };
  const pelagem = texto(a.pelagem, `${campo}.pelagem`, { max: 60 });
  if (pelagem) saida.pelagem = pelagem;
  const nascimento = dataOpcional(a.nascimento, `${campo}.nascimento`);
  if (nascimento) saida.nascimento = nascimento;
  const premiacaoProvas = numeroOpcional(a.premiacaoProvas, `${campo}.premiacaoProvas`);
  if (premiacaoProvas != null) saida.premiacaoProvas = premiacaoProvas;
  const premiacaoReprodutor = numeroOpcional(a.premiacaoReprodutor, `${campo}.premiacaoReprodutor`);
  if (premiacaoReprodutor != null) saida.premiacaoReprodutor = premiacaoReprodutor;
  const filhos = numeroOpcional(a.filhosPremiados, `${campo}.filhosPremiados`, { inteiro: true });
  if (filhos != null) saida.filhosPremiados = filhos;
  const fonte = texto(a.fonte, `${campo}.fonte`, { max: 30 });
  if (fonte) saida.fonte = fonte;
  const atualizadoEm = dataOpcional(a.atualizadoEm, `${campo}.atualizadoEm`);
  if (atualizadoEm) saida.atualizadoEm = atualizadoEm;
  if (a.pai != null) saida.pai = normalizarAncestral(a.pai, `${campo}.pai`, geracao + 1);
  if (a.mae != null) saida.mae = normalizarAncestral(a.mae, `${campo}.mae`, geracao + 1);
  return saida;
}
