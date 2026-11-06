
CREATE TABLE IF NOT EXISTS public.pesagens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ts timestamp with time zone NOT NULL DEFAULT now(),
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  produto text NOT NULL DEFAULT 'Geral'::text,
  encarregado text NOT NULL DEFAULT 'Nao Informado'::text,
  peso numeric NOT NULL,
  CONSTRAINT pesagens_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.peso_atual (
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  peso numeric NOT NULL,
  atualizado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT peso_atual_pkey PRIMARY KEY (fabrica)
);
CREATE TABLE IF NOT EXISTS public.encarregados (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nome text NOT NULL UNIQUE,
  senha_hash text,
  CONSTRAINT encarregados_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.produtos (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nome text NOT NULL UNIQUE,
  CONSTRAINT produtos_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.selecoes (
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  encarregado text NOT NULL DEFAULT ''::text,
  produto text NOT NULL DEFAULT ''::text,
  encarregado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT selecoes_pkey PRIMARY KEY (fabrica)
);
CREATE TABLE IF NOT EXISTS public.leituras_ihm (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ts timestamp with time zone NOT NULL DEFAULT now(),
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  temperatura numeric,
  frequencia numeric,
  CONSTRAINT leituras_ihm_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.motivos_parada (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  codigo text NOT NULL,
  descricao text NOT NULL,
  ativo boolean NOT NULL DEFAULT true,
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT motivos_parada_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.paradas (
  id uuid NOT NULL,
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  inicio timestamp with time zone NOT NULL,
  fim timestamp with time zone,
  motivo_id uuid,
  motivo text,
  encarregado text NOT NULL DEFAULT 'Nao Informado'::text,
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT paradas_pkey PRIMARY KEY (id),
  CONSTRAINT paradas_motivo_id_fkey FOREIGN KEY (motivo_id) REFERENCES public.motivos_parada(id)
);
CREATE TABLE IF NOT EXISTS public.push_inscricoes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  endpoint text NOT NULL UNIQUE,
  p256dh text NOT NULL,
  auth text NOT NULL,
  papel text NOT NULL CHECK (papel = ANY (ARRAY['encarregado'::text, 'fixo'::text])),
  encarregado text,
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT push_inscricoes_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.acesso_painel (
  id integer NOT NULL DEFAULT 1 CHECK (id = 1),
  email text NOT NULL,
  senha text NOT NULL,
  CONSTRAINT acesso_painel_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.turnos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  fabrica integer NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  numero integer NOT NULL,
  inicio timestamp with time zone NOT NULL,
  fim timestamp with time zone NOT NULL,
  encarregado text NOT NULL DEFAULT ''::text,
  produto text NOT NULL DEFAULT ''::text,
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT turnos_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.acesso_admin (
  id integer NOT NULL DEFAULT 1 CHECK (id = 1),
  email text NOT NULL,
  senha_hash text NOT NULL,
  CONSTRAINT acesso_admin_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.leituras_materia_prima (
  id uuid NOT NULL,
  ts timestamp with time zone NOT NULL,
  fabrica smallint NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  campo text NOT NULL,
  valor double precision NOT NULL,
  criado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT leituras_materia_prima_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.eficiencia_turnos (
  fabrica smallint NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  inicio timestamp with time zone NOT NULL,
  fim timestamp with time zone NOT NULL,
  numero integer,
  produto text,
  encarregado text,
  mp_calcitico double precision,
  mp_dolomitico double precision,
  mp_total double precision,
  tempo_func_s double precision,
  tempo_turno_s double precision,
  produto_acabado double precision,
  t_h_func double precision,
  t_h_turno double precision,
  eficiencia_pct double precision,
  salvo_em timestamp with time zone NOT NULL DEFAULT now(),
  pa_t_h_func double precision,
  pa_t_h_turno double precision,
  CONSTRAINT eficiencia_turnos_pkey PRIMARY KEY (fabrica, inicio)
);
CREATE TABLE IF NOT EXISTS public.config_balanca (
  fabrica smallint NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  intervalo_ms integer NOT NULL DEFAULT 1000 CHECK (intervalo_ms >= 50 AND intervalo_ms <= 60000),
  fator double precision NOT NULL DEFAULT 1,
  atualizado_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT config_balanca_pkey PRIMARY KEY (fabrica)
);
CREATE TABLE IF NOT EXISTS public.config_banco (
  id integer NOT NULL DEFAULT 1 CHECK (id = 1),
  limite_mb integer NOT NULL DEFAULT 500,
  aviso_pct integer NOT NULL DEFAULT 80,
  CONSTRAINT config_banco_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.acumulado_mp_turnos (
  turno_id uuid NOT NULL,
  fabrica smallint NOT NULL CHECK (fabrica >= 1 AND fabrica <= 4),
  inicio timestamp with time zone NOT NULL,
  fim timestamp with time zone NOT NULL,
  valores jsonb NOT NULL DEFAULT '{}'::jsonb,
  salvo_em timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT acumulado_mp_turnos_pkey PRIMARY KEY (turno_id)
);-- Funcoes exportadas do Supabase (pg_get_functiondef). Requer pgcrypto (crypt/gen_salt).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.medias_diarias_ihm(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone)
 RETURNS TABLE(dia date, media_temperatura numeric, media_frequencia numeric, n_temperatura bigint, n_frequencia bigint)
 LANGUAGE sql
 STABLE
AS $function$
    select (l.ts at time zone 'America/Sao_Paulo')::date as dia,
           round(avg(l.temperatura) filter (where l.temperatura is not null and coalesce(l.frequencia, 1) <> 0), 2),
           round(avg(l.frequencia), 2),
           count(l.temperatura) filter (where l.temperatura is not null and coalesce(l.frequencia, 1) <> 0),
           count(l.frequencia)
    from leituras_ihm l
    where l.fabrica = p_fabrica and l.ts >= p_de and l.ts < p_ate
    group by 1
    order by 1
$function$
;

CREATE OR REPLACE FUNCTION public.leituras_ihm_agregadas(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone, p_minutos integer)
 RETURNS TABLE(ts timestamp with time zone, temperatura numeric, frequencia numeric)
 LANGUAGE sql
 STABLE
AS $function$
    select date_bin(make_interval(mins => greatest(p_minutos, 1)), l.ts, p_de) as ts,
           round(avg(l.temperatura), 2) as temperatura,
           round(avg(l.frequencia), 2) as frequencia
    from leituras_ihm l
    where l.fabrica = p_fabrica and l.ts >= p_de and l.ts < p_ate
    group by 1
    order by 1
$function$
;

CREATE OR REPLACE FUNCTION public.limitar_fixos()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    if new.papel = 'fixo' and (select count(*) from push_inscricoes where papel = 'fixo' and endpoint <> new.endpoint) >= 3 then
        raise exception 'Ja existem 3 contas fixas cadastradas';
    end if;
    return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.selecoes_marcar_encarregado()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    if tg_op = 'INSERT' or new.encarregado is distinct from old.encarregado then
        new.encarregado_em := now();
    end if;
    return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.virar_turno_selecoes()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    agora_local timestamp := now() at time zone 'America/Sao_Paulo';
    inicio_turno timestamptz;
begin
    inicio_turno := (date_trunc('day', agora_local) + make_interval(hours => (extract(hour from agora_local)::int / 6) * 6))
                    at time zone 'America/Sao_Paulo';
    update selecoes set encarregado = ''
     where encarregado_em < inicio_turno and coalesce(encarregado, '') <> '';
end $function$
;

CREATE OR REPLACE FUNCTION public.trocar_senha_admin(p_email text, p_senha_atual text, p_nova text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
    if not validar_admin(p_email, p_senha_atual) then return 'admin_invalido'; end if;
    if length(coalesce(p_nova, '')) < 4 then return 'senha_curta'; end if;
    update acesso_admin set senha_hash = crypt(p_nova, gen_salt('bf')) where id = 1;
    return 'ok';
end $function$
;

CREATE OR REPLACE FUNCTION public.definir_nomes_turno(p_id uuid, p_encarregado text, p_produto text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t turnos;
begin
    update turnos set encarregado = coalesce(p_encarregado, ''), produto = coalesce(p_produto, '')
     where id = p_id returning * into t;
    if t.id is null then return; end if;
    if coalesce(p_encarregado, '') <> '' then
        update pesagens set encarregado = p_encarregado where fabrica = t.fabrica and ts >= t.inicio and ts < t.fim;
    end if;
    if coalesce(p_produto, '') <> '' then
        update pesagens set produto = p_produto where fabrica = t.fabrica and ts >= t.inicio and ts < t.fim;
    end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.turnos_medias(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone)
 RETURNS TABLE(id uuid, numero integer, inicio timestamp with time zone, fim timestamp with time zone, encarregado text, produto text, media_temperatura double precision, media_frequencia double precision, n_leituras bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select t.id, t.numero, t.inicio, t.fim, t.encarregado, t.produto,
           avg(l.temperatura)::double precision, avg(l.frequencia)::double precision, count(l.ts)
      from turnos t
      left join leituras_ihm l
             on l.fabrica = t.fabrica and l.ts >= t.inicio and l.ts < t.fim and l.frequencia >= 1
     where t.fabrica = p_fabrica and t.inicio < p_ate and t.fim > p_de
     group by t.id
     order by t.inicio
$function$
;

CREATE OR REPLACE FUNCTION public.validar_admin(p_email text, p_senha text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare ok boolean;
begin
    select (lower(trim(p_email)) = a.email and a.senha_hash = crypt(p_senha, a.senha_hash))
      into ok from acesso_admin a where a.id = 1;
    return coalesce(ok, false);
end $function$
;

CREATE OR REPLACE FUNCTION public.login_painel(p_usuario text, p_senha text)
 RETURNS TABLE(r_nome text, r_email text, r_senha text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare e record;
begin
    select * into e from encarregados x
     where lower(regexp_replace(trim(x.nome), '\\s+', ' ', 'g')) = lower(regexp_replace(trim(p_usuario), '\\s+', ' ', 'g'))
     limit 1;
    if not found then return; end if;
    if e.senha_hash is not null then
        if e.senha_hash <> crypt(p_senha, e.senha_hash) then return; end if;
    elsif lower(regexp_replace(trim(e.nome), '\\s+', ' ', 'g')) <> lower(regexp_replace(trim(p_senha), '\\s+', ' ', 'g')) then
        return;
    end if;
    return query select e.nome, a.email, a.senha from acesso_painel a where a.id = 1;
end $function$
;

CREATE OR REPLACE FUNCTION public.definir_senha_encarregado(p_admin_email text, p_admin_senha text, p_nome text, p_senha text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
    if not validar_admin(p_admin_email, p_admin_senha) then return 'admin_invalido'; end if;
    if length(coalesce(p_senha, '')) < 4 then return 'senha_curta'; end if;
    update encarregados set senha_hash = crypt(p_senha, gen_salt('bf')) where lower(trim(nome)) = lower(trim(p_nome));
    if not found then return 'nao_encontrado'; end if;
    return 'ok';
end $function$
;

CREATE OR REPLACE FUNCTION public.renomear_encarregado(p_admin_email text, p_admin_senha text, p_nome_atual text, p_nome_novo text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare t record; novo text := regexp_replace(trim(coalesce(p_nome_novo, '')), '\\s+', ' ', 'g');
begin
    if not validar_admin(p_admin_email, p_admin_senha) then return 'admin_invalido'; end if;
    if novo = '' then return 'nome_invalido'; end if;
    if not exists (select 1 from encarregados where lower(trim(nome)) = lower(trim(p_nome_atual))) then return 'nao_encontrado'; end if;
    if exists (select 1 from encarregados where lower(trim(nome)) = lower(novo) and lower(trim(nome)) <> lower(trim(p_nome_atual))) then return 'nome_existe'; end if;
    for t in select c.table_name from information_schema.columns c
              join information_schema.tables tb on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
             where c.table_schema = 'public' and c.column_name = 'encarregado' loop
        execute format('update public.%I set encarregado = $1 where lower(trim(encarregado)) = lower(trim($2))', t.table_name) using novo, p_nome_atual;
    end loop;
    update encarregados set nome = novo where lower(trim(nome)) = lower(trim(p_nome_atual));
    return 'ok';
end $function$
;

CREATE OR REPLACE FUNCTION public.inicio_turno_fabrica(p_ts timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
AS $function$
    select (date_trunc('day', p_ts at time zone 'America/Sao_Paulo')
            + (floor(extract(hour from p_ts at time zone 'America/Sao_Paulo') / 6))::int * interval '6 hours')
           at time zone 'America/Sao_Paulo'
$function$
;

CREATE OR REPLACE FUNCTION public.lote_do_turno(p_fabrica integer, p_inicio timestamp with time zone, p_fim timestamp with time zone)
 RETURNS TABLE(r_numero integer, r_produto text, r_encarregado text)
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
    v_num int; v_prod text; v_enc text; v_prod2 text; v_enc2 text;
begin
    begin
        execute format(
            'select t.numero::int, t.produto::text, t.encarregado::text from turnos_medias(%L, %L, %L) t '
            || 'where t.inicio >= %L::timestamptz - interval ''1 minute'' and t.inicio < %L::timestamptz '
            || 'order by t.inicio limit 1',
            p_fabrica, p_inicio, p_fim, p_inicio, p_fim)
        into v_num, v_prod, v_enc;
    exception when others then
        v_num := null; v_prod := null; v_enc := null;
    end;

    if coalesce(v_prod, '') = '' or coalesce(v_enc, '') = '' then
        select p.produto, p.encarregado into v_prod2, v_enc2
          from pesagens p
         where p.fabrica = p_fabrica and p.ts >= p_inicio and p.ts < p_fim
         group by p.produto, p.encarregado
         order by count(*) desc
         limit 1;
        v_prod := coalesce(nullif(v_prod, ''), v_prod2);
        v_enc  := coalesce(nullif(v_enc, ''),  v_enc2);
    end if;

    return query select v_num, v_prod, v_enc;
end $function$
;

CREATE OR REPLACE FUNCTION public.calcular_eficiencia(p_fabrica integer, p_inicio timestamp with time zone, p_fim timestamp with time zone)
 RETURNS TABLE(mp_calcitico double precision, mp_dolomitico double precision, mp_total double precision, tempo_func_s double precision, tempo_turno_s double precision, produto_acabado double precision, t_h_func double precision, t_h_turno double precision, eficiencia_pct double precision)
 LANGUAGE plpgsql
 STABLE
AS $function$
#variable_conflict use_column
declare
    v_ate   timestamptz := least(p_fim, now());
    v_calc  double precision;
    v_dolo  double precision;
    v_mp    double precision;
    v_func  double precision;
    v_turno double precision;
    v_pa    double precision;
begin
    if v_ate < p_inicio then v_ate := p_inicio; end if;

    -- materia-prima consumida (calcitico + dolomitico)
    v_calc := consumo_materia_prima(p_fabrica, 'calcitico',  p_inicio, v_ate);
    v_dolo := consumo_materia_prima(p_fabrica, 'dolomitico', p_inicio, v_ate);
    v_mp   := v_calc + v_dolo;

    -- tempo decorrido do turno (s)
    v_turno := extract(epoch from (v_ate - p_inicio));

    -- tempo em funcionamento (s): cada leitura de frequencia >= 1 vale ate a proxima leitura (no maximo 2 min)
    select coalesce(sum(extract(epoch from (least(coalesce(x.prox, v_ate), x.ts + interval '2 minutes') - x.ts))), 0)
      into v_func
      from (select l.ts, l.frequencia, lead(l.ts) over (order by l.ts) as prox
              from leituras_ihm l
             where l.fabrica = p_fabrica and l.ts >= p_inicio and l.ts < v_ate) x
     where x.frequencia >= 1;

    -- produto acabado (kg) = pesagens do indicador Alfa no turno
    select coalesce(sum(p.peso), 0) into v_pa
      from pesagens p
     where p.fabrica = p_fabrica and p.ts >= p_inicio and p.ts < v_ate;

    return query select
        v_calc, v_dolo, v_mp, v_func, v_turno, v_pa,
        case when v_func  > 0 then (v_mp / 1000::double precision) / (v_func  / 3600::double precision) end,
        case when v_turno > 0 then (v_mp / 1000::double precision) / (v_turno / 3600::double precision) end,
        case when v_mp    > 0 then v_pa / v_mp * 100::double precision end;
end $function$
;

CREATE OR REPLACE FUNCTION public.consumo_materia_prima(p_fabrica integer, p_campo text, p_de timestamp with time zone, p_ate timestamp with time zone)
 RETURNS double precision
 LANGUAGE sql
 STABLE
AS $function$
    select coalesce(sum(
               case when x.ant is null then 0
                    when x.valor >= x.ant then x.valor - x.ant      -- subiu: consumo
                    when x.valor < x.ant * 0.5 then x.valor         -- reset (zerou): o novo valor e consumo desde o zero
                    else 0                                          -- queda pequena: ruido da IHM, nao conta
               end), 0)::double precision
      from (
            select l.ts, l.valor, lag(l.valor) over (order by l.ts) as ant
              from leituras_materia_prima l
             where l.fabrica = p_fabrica and l.campo = p_campo
               and l.ts >= p_de and l.ts < p_ate
           ) x
$function$
;

CREATE OR REPLACE FUNCTION public.materias_primas_agrupadas(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone, p_agrupar text)
 RETURNS TABLE(grupo timestamp with time zone, campo text, valor double precision, ts timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
#variable_conflict use_column
begin
    if p_agrupar in ('turno', 'dia') then
        return query
        select g.grupo, g.campo, g.valor, g.ts
          from (
                select distinct on (k.grupo, k.campo) k.grupo, k.campo, k.valor, k.ts
                  from (
                        select case when p_agrupar = 'dia'
                                    then date_trunc('day', l.ts at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'
                                    else inicio_turno_fabrica(l.ts) end as grupo,
                               l.campo, l.valor, l.ts
                          from leituras_materia_prima l
                         where l.fabrica = p_fabrica and l.ts >= p_de and l.ts < p_ate
                       ) k
                 order by k.grupo, k.campo, k.ts desc
               ) g
         order by g.grupo, g.campo;
    else
        return query
        select p_ate, d.campo, d.valor, d.ts
          from (
                select distinct on (l.campo) l.campo, l.valor, l.ts
                  from leituras_materia_prima l
                 where l.fabrica = p_fabrica and l.ts < p_ate
                 order by l.campo, l.ts desc
               ) d
         order by d.campo;
    end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.uso_banco()
 RETURNS TABLE(usado_mb double precision, limite_mb integer, pct double precision, aviso_pct integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select (pg_database_size(current_database()) / 1048576.0)::double precision,
           c.limite_mb,
           ((pg_database_size(current_database()) / 1048576.0) / c.limite_mb * 100)::double precision,
           c.aviso_pct
      from config_banco c where c.id = 1
$function$
;

CREATE OR REPLACE FUNCTION public.garantir_turno(p_fabrica integer)
 RETURNS SETOF turnos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    agora_local timestamp := now() at time zone 'America/Sao_Paulo';
    ini timestamptz;
begin
    ini := (date_trunc('day', agora_local) + make_interval(hours => (extract(hour from agora_local)::int / 6) * 6))
           at time zone 'America/Sao_Paulo';
    insert into turnos (fabrica, numero, inicio, fim, encarregado, produto)
    select p_fabrica,
           coalesce((select max(numero) from turnos where fabrica = p_fabrica), 0) + 1,
           ini, ini + interval '6 hours', '',
           coalesce((select produto from turnos where fabrica = p_fabrica order by inicio desc limit 1), '')
    on conflict (fabrica, inicio) do nothing;
    return query select * from turnos
                  where fabrica = p_fabrica and inicio >= ini and inicio < ini + interval '6 hours'
                  order by inicio desc limit 1;
end $function$
;

CREATE OR REPLACE FUNCTION public.novo_lote(p_fabrica integer, p_produto text)
 RETURNS SETOF turnos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    agora timestamptz := now();
    v_ini timestamptz;
    cur turnos;
    nv turnos;
    fim_turno timestamptz;
    prod text := coalesce(p_produto, '');
begin
    if p_fabrica is null or p_fabrica < 1 or p_fabrica > 4 then raise exception 'fabrica invalida'; end if;
    perform 1 from garantir_turno(p_fabrica);
    v_ini := inicio_turno_fabrica(agora);
    select * into cur from turnos
     where fabrica = p_fabrica and inicio >= v_ini and inicio < v_ini + interval '6 hours'
     order by inicio desc limit 1;
    if cur.id is null then raise exception 'lote atual nao encontrado'; end if;

    if cur.inicio > agora - interval '30 seconds' then
        -- clique duplo / lote acabou de abrir: so ajusta o produto dele
        update turnos set produto = prod where id = cur.id returning * into nv;
    else
        fim_turno := cur.fim;
        update turnos set fim = agora where id = cur.id;
        insert into turnos (fabrica, numero, inicio, fim, encarregado, produto)
        values (p_fabrica,
                coalesce((select max(numero) from turnos where fabrica = p_fabrica), 0) + 1,
                agora, fim_turno, coalesce(cur.encarregado, ''), prod)
        returning * into nv;
    end if;

    insert into selecoes (fabrica, encarregado, produto)
    values (p_fabrica, coalesce(cur.encarregado, ''), prod)
    on conflict (fabrica) do update set produto = excluded.produto;

    if prod <> '' then
        update pesagens set produto = prod where fabrica = p_fabrica and ts >= nv.inicio and ts < nv.fim;
    end if;
    return next nv;
end $function$
;

CREATE OR REPLACE FUNCTION public.fechar_eficiencia_turnos(p_dias integer DEFAULT 2)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_ini timestamptz;
    v_fim timestamptz;
    f int;
    n int := 0;
    e record;
    l record;
    seg record;
begin
    v_ini := inicio_turno_fabrica(now() - make_interval(days => greatest(p_dias, 1)));
    while v_ini <= now() loop
        v_fim := v_ini + interval '6 hours';
        for f in 1..4 loop
            for seg in
                select t.inicio as s_ini, least(t.fim, v_fim) as s_fim
                  from turnos t
                 where t.fabrica = f and t.inicio >= v_ini and t.inicio < v_fim
                union all
                select v_ini, v_fim
                 where not exists (select 1 from turnos t where t.fabrica = f and t.inicio >= v_ini and t.inicio < v_fim)
                order by 1
            loop
                -- lote em andamento tambem e salvo (calcular_eficiencia ja limita em agora) e fica sendo atualizado a cada chamada ate o lote fechar
                select * into e from calcular_eficiencia(f, seg.s_ini, seg.s_fim);
                if coalesce(e.mp_total, 0) > 0 or coalesce(e.produto_acabado, 0) > 0 or coalesce(e.tempo_func_s, 0) > 0 then
                    select * into l from lote_do_turno(f, seg.s_ini, seg.s_fim);
                    insert into eficiencia_turnos as t (
                        fabrica, inicio, fim, numero, produto, encarregado,
                        mp_calcitico, mp_dolomitico, mp_total, tempo_func_s, tempo_turno_s,
                        produto_acabado, t_h_func, t_h_turno, eficiencia_pct, pa_t_h_func, pa_t_h_turno, salvo_em)
                    values (
                        f, seg.s_ini, seg.s_fim, l.r_numero, l.r_produto, l.r_encarregado,
                        e.mp_calcitico, e.mp_dolomitico, e.mp_total, e.tempo_func_s, e.tempo_turno_s,
                        e.produto_acabado, e.t_h_func, e.t_h_turno, e.eficiencia_pct,
                        case when e.tempo_func_s  > 0 then (e.produto_acabado / 1000::double precision) / (e.tempo_func_s  / 3600::double precision) end,
                        case when e.tempo_turno_s > 0 then (e.produto_acabado / 1000::double precision) / (e.tempo_turno_s / 3600::double precision) end,
                        now())
                    on conflict (fabrica, inicio) do update set
                        fim = excluded.fim, numero = excluded.numero, produto = excluded.produto, encarregado = excluded.encarregado,
                        mp_calcitico = excluded.mp_calcitico, mp_dolomitico = excluded.mp_dolomitico, mp_total = excluded.mp_total,
                        tempo_func_s = excluded.tempo_func_s, tempo_turno_s = excluded.tempo_turno_s,
                        produto_acabado = excluded.produto_acabado, t_h_func = excluded.t_h_func, t_h_turno = excluded.t_h_turno,
                        eficiencia_pct = excluded.eficiencia_pct, pa_t_h_func = excluded.pa_t_h_func, pa_t_h_turno = excluded.pa_t_h_turno, salvo_em = now();
                    n := n + 1;
                end if;
            end loop;
        end loop;
        v_ini := v_fim;
    end loop;
    return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.eficiencia_turno_atual()
 RETURNS TABLE(fabrica integer, inicio timestamp with time zone, fim timestamp with time zone, numero integer, produto text, encarregado text, mp_calcitico double precision, mp_dolomitico double precision, mp_total double precision, tempo_func_s double precision, tempo_turno_s double precision, produto_acabado double precision, t_h_func double precision, t_h_turno double precision, eficiencia_pct double precision)
 LANGUAGE plpgsql
 STABLE
AS $function$
#variable_conflict use_column
declare
    v_fim timestamptz := inicio_turno_fabrica(now()) + interval '6 hours';
    v_ini timestamptz;
    f int;
    e record;
    l record;
begin
    for f in 1..4 loop
        v_ini := inicio_lote_atual(f);
        select * into e from calcular_eficiencia(f, v_ini, v_fim);
        select * into l from lote_do_turno(f, v_ini, v_fim);
        return query select f, v_ini, v_fim, l.r_numero, l.r_produto, l.r_encarregado,
            e.mp_calcitico, e.mp_dolomitico, e.mp_total, e.tempo_func_s, e.tempo_turno_s,
            e.produto_acabado, e.t_h_func, e.t_h_turno, e.eficiencia_pct;
    end loop;
end $function$
;

CREATE OR REPLACE FUNCTION public.mp_valores_ate(p_fabrica integer, p_ate timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
    select coalesce(jsonb_object_agg(x.campo, x.valor), '{}'::jsonb)
      from (select distinct on (l.campo) l.campo, l.valor
              from leituras_materia_prima l
             where l.fabrica = p_fabrica and l.ts < p_ate
               and l.ts >= inicio_turno_fabrica(p_ate - interval '1 second')   -- valor do TURNO (a regra do zeramento zera no inicio de cada turno)
             order by l.campo, l.ts desc) x
$function$
;

CREATE OR REPLACE FUNCTION public.materias_primas_turno(p_fabrica integer)
 RETURNS TABLE(campo text, consumo double precision)
 LANGUAGE plpgsql
 STABLE
AS $function$
#variable_conflict use_column
declare
    v_ini timestamptz := inicio_lote_atual(p_fabrica);
begin
    return query
    select c.nome, consumo_materia_prima(p_fabrica, c.nome, v_ini, now() + interval '1 minute')
      from unnest(array['calcitico','dolomitico','amido','materia_prima_1','materia_prima_2','oleo','oleo_ensacadeira','bateladas']) as c(nome)
     where exists (select 1 from leituras_materia_prima l where l.fabrica = p_fabrica and l.campo = c.nome);
end $function$
;

CREATE OR REPLACE FUNCTION public.inicio_lote_atual(p_fabrica integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
    v_slot timestamptz := inicio_turno_fabrica(now());
    v_ini  timestamptz;
begin
    begin
        execute format(
            'select max(t.inicio::timestamptz) from turnos_medias(%L, %L, %L) t '
            || 'where t.inicio >= %L::timestamptz - interval ''1 minute'' and t.inicio <= now() + interval ''1 minute''',
            p_fabrica, v_slot, v_slot + interval '6 hours', v_slot)
        into v_ini;
    exception when others then
        v_ini := null;
    end;
    return greatest(coalesce(v_ini, v_slot), v_slot);
end $function$
;

CREATE OR REPLACE FUNCTION public.salvar_acumulado_mp_turnos(p_dias integer DEFAULT 3)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
    with ins as (
        insert into acumulado_mp_turnos as a (turno_id, fabrica, inicio, fim, valores, salvo_em)
        select t.id, t.fabrica, t.inicio, t.fim, mp_valores_ate(t.fabrica, t.fim), now()
          from turnos t
         where t.fim <= now()
           and t.fim > now() - make_interval(days => greatest(p_dias, 1))
           and exists (select 1 from leituras_materia_prima l where l.fabrica = t.fabrica and l.ts < t.fim)
        on conflict (turno_id) do update
           set valores = excluded.valores, fim = excluded.fim, salvo_em = now()
         where now() < a.fim + interval '2 hours'
        returning 1)
    select count(*) into n from ins;
    return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.acumulado_mp_lotes(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone)
 RETURNS TABLE(id uuid, numero integer, inicio timestamp with time zone, fim timestamp with time zone, encarregado text, produto text, valores jsonb, salvo boolean, salvo_em timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
    select t.id, t.numero::int, t.inicio, t.fim, t.encarregado::text, t.produto::text,
           coalesce(s.valores, mp_valores_ate(t.fabrica, least(t.fim, now()))),
           (s.turno_id is not null), s.salvo_em
      from turnos t
      left join acumulado_mp_turnos s on s.turno_id = t.id
     where t.fabrica = p_fabrica and t.inicio < p_ate and t.fim > p_de
     order by t.inicio
$function$
;

CREATE OR REPLACE FUNCTION public.materias_primas_periodo(p_fabrica integer, p_de timestamp with time zone, p_ate timestamp with time zone, p_agrupar text DEFAULT 'total'::text, p_produto text DEFAULT NULL::text)
 RETURNS TABLE(grupo timestamp with time zone, rotulo text, campo text, valor double precision)
 LANGUAGE sql
 STABLE
AS $function$
    with leit as (
        -- desde o inicio do turno de p_de, para saber o valor que o turno ja tinha acumulado
        select l.campo, l.ts, l.valor
          from leituras_materia_prima l
         where l.fabrica = p_fabrica and l.ts >= inicio_turno_fabrica(p_de) and l.ts < p_ate
           and l.campo in ('calcitico','dolomitico','amido','materia_prima_1','materia_prima_2','oleo','oleo_ensacadeira','bateladas')
    ),
    delta as (
        -- dentro do turno o valor so sobe; uma leitura menor que o maior valor ja lido no turno nao soma (evita contar duas vezes)
        select x.campo, x.ts, greatest(x.valor - coalesce(x.maximo, 0), 0) as d
          from (select campo, ts, valor,
                       max(valor) over (partition by campo, inicio_turno_fabrica(ts) order by ts
                                        rows between unbounded preceding and 1 preceding) as maximo
                  from leit) x
         where x.ts >= p_de
    ),
    lote as (
        select d.campo, d.ts, d.d, coalesce(t.produto, '') as produto, coalesce(t.encarregado, '') as encarregado
          from delta d
          left join lateral (select tt.produto, tt.encarregado from turnos tt
                              where tt.fabrica = p_fabrica and d.ts >= tt.inicio and d.ts < tt.fim
                              order by tt.inicio desc limit 1) t on true
    )
    select case p_agrupar
               when 'hora'  then date_trunc('hour',  l.ts at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'
               when 'dia'   then date_trunc('day',   l.ts at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'
               when 'mes'   then date_trunc('month', l.ts at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'
               when 'ano'   then date_trunc('year',  l.ts at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'
               when 'turno' then inicio_turno_fabrica(l.ts)
               else p_de end as grupo,
           case p_agrupar
               when 'encarregado' then coalesce(nullif(l.encarregado, ''), '(sem nome)')
               when 'produto'     then coalesce(nullif(l.produto, ''), '(sem produto)')
               else null end as rotulo,
           l.campo,
           sum(l.d)::double precision as valor
      from lote l
     where (p_produto is null or p_produto = '' or l.produto = p_produto)
     group by 1, 2, 3
     order by 1, 2, 3
$function$
;
