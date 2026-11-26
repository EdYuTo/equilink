-- EquiLink — autenticação e controle de acesso
--
-- Idempotente: pode rodar mais de uma vez.
--
-- Modelo:
--   * `usuario_haras` (já existente) diz a qual haras o usuário tem acesso e
--     com que papel. É a fonte da verdade da autorização — o token só carrega
--     a identidade e a sessão; o papel é lido do banco a cada requisição, para
--     que revogar acesso valha imediatamente.
--   * `credenciais` guarda o hash da senha (PBKDF2-HMAC-SHA256, 210 mil
--     iterações, salt por usuário). Nunca a senha.
--   * `tentativas_login` alimenta o bloqueio por tentativa repetida. O IP é
--     guardado só como hash, para não acumular dado pessoal.

-- ---------------------------------------------------------------------------
-- Senha
-- ---------------------------------------------------------------------------

create table if not exists credenciais (
  usuario_id   text primary key,
  hash         text not null,          -- PBKDF2 em base64
  salt         text not null,          -- salt em base64
  iteracoes    integer not null default 210000,
  criado_em    timestamptz not null default now(),
  trocado_em   timestamptz,
  -- Senha provisória: obriga a troca no primeiro acesso.
  provisoria   boolean not null default false
);

-- ---------------------------------------------------------------------------
-- Bloqueio por tentativa repetida
-- ---------------------------------------------------------------------------

create table if not exists tentativas_login (
  ip_hash    text not null,             -- HMAC-SHA256 do IP com chave própria (hashIp), de mão única
  usuario_id text not null default '',
  quando     timestamptz not null default now(),
  sucesso    boolean not null default false
);

create index if not exists tentativas_ip_idx on tentativas_login (ip_hash, quando desc);
create index if not exists tentativas_usuario_idx on tentativas_login (usuario_id, quando desc);

-- ---------------------------------------------------------------------------
-- Consulta de acesso: haras e papel de um usuário
-- ---------------------------------------------------------------------------

-- Devolve uma linha por haras acessível. Usada a cada requisição autenticada.
create or replace function haras_do_usuario(p_usuario text)
returns table (haras_id uuid, papel text)
language sql
stable
as $$
  select uh.haras_id, uh.papel
  from usuario_haras uh
  where uh.usuario_id = p_usuario
  order by uh.haras_id
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Papéis: quem pode escrever
-- ---------------------------------------------------------------------------

-- `leitor` só lê. `operador` escreve cavalos, provas, mídias e manejo.
-- `proprietario` também remove registros e mexe em configuração.
create or replace function papel_pode_escrever(p_papel text)
returns boolean
language sql
immutable
as $$
  select p_papel in ('proprietario', 'operador');
$$;

create or replace function papel_pode_remover(p_papel text)
returns boolean
language sql
immutable
as $$
  select p_papel = 'proprietario';
$$;

-- ---------------------------------------------------------------------------
-- Privacidade: telefone do proprietário não é dado público
-- ---------------------------------------------------------------------------
--
-- O acervo é servido ao app anônimo. `proprietario.telefone` é dado de contato
-- do dono do animal: fica fora da resposta pública e só aparece para quem tem
-- acesso ao haras.
comment on column cavalos.proprietario is
  'Contato do proprietário. `telefone` é privado: só é servido a usuário autenticado do haras.';
