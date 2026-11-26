// Erros previsíveis do banco, traduzidos para o operador (EQL-012).
//
// Sem esta tradução, um registro repetido ou um valor fora do tipo da coluna
// virava 500 "Falha interna", e o operador não tinha como saber o que corrigir.
// A mensagem devolvida nunca repete o texto do Postgres: ele traz SQL, nome de
// coluna e o valor recusado.

/** Mensagem por restrição de unicidade; o nome é o padrão do Postgres. */
const DUPLICADOS = new Map([
  // `unique (haras_id, registro)` em deploy/schema.sql.
  ['cavalos_haras_id_registro_key', 'Já existe um cavalo com este registro.'],
]);

/**
 * Status e mensagem para um erro do banco, ou `null` quando não é previsível
 * (esse continua 500 com id de erro).
 */
export function erroDoBanco(e) {
  switch (e?.code) {
    case '23505': // unique_violation
      return { status: 409, mensagem: DUPLICADOS.get(e.constraint) ?? 'Registro duplicado.' };
    case '22P02': // invalid_text_representation
      return { status: 400, mensagem: 'Valor em formato inválido.' };
    default:
      return null;
  }
}
