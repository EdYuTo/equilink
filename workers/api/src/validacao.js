// Validação da entrada: o que vem do cliente nunca chega cru ao banco.

export class ErroValidacao extends Error {
  constructor(mensagem, status = 400) {
    super(mensagem);
    this.status = status;
  }
}

/** Texto curto, sem controle, truncado. */
export function texto(valor, campo, { max = 500, obrigatorio = false, padrao = '' } = {}) {
  if (valor == null || valor === '') {
    if (obrigatorio) throw new ErroValidacao(`Campo obrigatório ausente: ${campo}.`);
    return padrao;
  }
  if (typeof valor !== 'string' && typeof valor !== 'number') {
    throw new ErroValidacao(`Campo ${campo} deve ser texto.`);
  }
  const s = String(valor).replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
  if (obrigatorio && !s) throw new ErroValidacao(`Campo obrigatório ausente: ${campo}.`);
  return s.slice(0, max);
}

export function objeto(valor, campo) {
  if (valor == null) return {};
  if (typeof valor !== 'object' || Array.isArray(valor)) {
    throw new ErroValidacao(`Campo ${campo} deve ser um objeto.`);
  }
  return valor;
}
