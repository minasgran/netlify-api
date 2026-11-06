-- Conta do painel (email + senha). TROQUE EMAIL e SENHA antes de rodar. A senha fica guardada como hash.
INSERT INTO public.acesso_painel (id, email, senha)
VALUES (1, 'SEU_EMAIL_AQUI', crypt('SUA_SENHA_AQUI', gen_salt('bf')))
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, senha = EXCLUDED.senha;
