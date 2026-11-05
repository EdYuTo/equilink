import { ErroValidacao, objeto, texto } from './validacao.js';

/** Gerações aceitas acima do animal. Limita o tamanho de uma árvore enviada pelo cliente. */
export const MAX_GERACOES = 5;

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
  if (a.pai != null) saida.pai = normalizarAncestral(a.pai, `${campo}.pai`, geracao + 1);
  if (a.mae != null) saida.mae = normalizarAncestral(a.mae, `${campo}.mae`, geracao + 1);
  return saida;
}
