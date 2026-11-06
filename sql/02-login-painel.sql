-- Substitui login_painel: valida nome + senha no servidor e NAO devolve mais a senha da conta do painel.
DROP FUNCTION IF EXISTS public.login_painel(text, text);
CREATE OR REPLACE FUNCTION public.login_painel(p_usuario text, p_senha text)
RETURNS TABLE(r_nome text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare e record;
begin
    select * into e from encarregados x
     where lower(regexp_replace(trim(x.nome), '\s+', ' ', 'g')) = lower(regexp_replace(trim(p_usuario), '\s+', ' ', 'g'))
     limit 1;
    if not found then return; end if;
    if e.senha_hash is not null then
        if e.senha_hash <> crypt(p_senha, e.senha_hash) then return; end if;
    elsif lower(regexp_replace(trim(e.nome), '\s+', ' ', 'g')) <> lower(regexp_replace(trim(p_senha), '\s+', ' ', 'g')) then
        return;
    end if;
    return query select e.nome;
end $function$;
