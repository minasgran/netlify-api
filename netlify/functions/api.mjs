// MINASGRAN - API no Netlify DB com a mesma forma da API REST que o painel e os programas ja usavam.
//   /rest/v1/<tabela>   GET (select, filtros eq/gt/gte/lt/lte/neq/is, order, limit, offset, Range)
//                       POST (insert ou upsert com on_conflict + Prefer), PATCH, DELETE (exigem filtro)
//   /rest/v1/rpc/<fn>   POST (argumentos nomeados p_*)
//   /auth/v1/token      ?grant_type=password | refresh_token
// Variaveis de ambiente (Netlify > Site settings > Environment variables):
//   AUTH_SECRET    segredo para assinar os tokens do painel (texto longo e aleatorio)
//   SERVICE_KEY    chave dos programas da fabrica (index.js e ihm.js); acesso total
// O banco (NETLIFY_DATABASE_URL) e configurado automaticamente pelo Netlify DB.

import { getDatabase } from '@netlify/database';
import { createHmac, timingSafeEqual } from 'node:crypto';

const db = getDatabase();

const TABELAS = new Set([
    'pesagens', 'peso_atual', 'encarregados', 'produtos', 'selecoes', 'leituras_ihm',
    'motivos_parada', 'paradas', 'push_inscricoes', 'turnos', 'leituras_materia_prima',
    'eficiencia_turnos', 'config_balanca', 'config_banco', 'acumulado_mp_turnos'
    // acesso_painel e acesso_admin NAO sao expostas pela API
]);
const ID_OK = /^[a-z_][a-z0-9_]*$/;
const ACESSO_SEG = 60 * 60;                 // access token: 1 hora
const REFRESH_SEG = 30 * 24 * 3600;         // refresh token: 30 dias
const MAX_LINHAS = 10000;

// ---------- utilitarios ----------
function json(obj, status = 200) {
    return new Response(obj === undefined ? null : JSON.stringify(obj), {
        status, headers: { 'Content-Type': 'application/json' }
    });
}
const erro = (status, msg) => json({ message: msg }, status);
const ident = (nome) => {
    if (!ID_OK.test(nome)) throw Object.assign(new Error('nome invalido: ' + nome), { status: 400 });
    return '"' + nome + '"';
};
const valorParam = (v) => (v !== null && typeof v === 'object') ? JSON.stringify(v) : v;

// ---------- tokens (HMAC-SHA256) ----------
const b64u = (s) => Buffer.from(s).toString('base64url');
function assinar(payload) {
    const corpo = b64u(JSON.stringify(payload));
    const sig = createHmac('sha256', process.env.AUTH_SECRET || '').update(corpo).digest('base64url');
    return corpo + '.' + sig;
}
function verificar(token, tipo) {
    if (!token || !process.env.AUTH_SECRET) return null;
    const [corpo, sig] = String(token).split('.');
    if (!corpo || !sig) return null;
    const esperado = createHmac('sha256', process.env.AUTH_SECRET).update(corpo).digest('base64url');
    const a = Buffer.from(sig), b = Buffer.from(esperado);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
    let p;
    try { p = JSON.parse(Buffer.from(corpo, 'base64url').toString('utf8')); } catch (e) { return null; }
    if (p.typ !== tipo || !p.exp || p.exp < Date.now() / 1000) return null;
    return p;
}
function emitirSessao(sub) {
    const agora = Math.floor(Date.now() / 1000);
    return {
        access_token: assinar({ typ: 'access', sub, exp: agora + ACESSO_SEG }),
        refresh_token: assinar({ typ: 'refresh', sub, exp: agora + REFRESH_SEG }),
        token_type: 'bearer',
        expires_in: ACESSO_SEG
    };
}

// quem esta chamando? 'service' (programas), 'painel' (token) ou null
function autenticar(req) {
    const auth = req.headers.get('authorization') || '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!token) return null;
    if (process.env.SERVICE_KEY && token === process.env.SERVICE_KEY) return 'service';
    if (verificar(token, 'access')) return 'painel';
    return null;
}

// ---------- filtros estilo PostgREST ----------
const RESERVADOS = new Set(['select', 'order', 'limit', 'offset', 'on_conflict']);
const OPS = { eq: '=', neq: '<>', gt: '>', gte: '>=', lt: '<', lte: '<=' };

function montarFiltros(params, binds) {
    const cond = [];
    for (const [col, raw] of params) {
        if (RESERVADOS.has(col)) continue;
        const i = raw.indexOf('.');
        if (i < 0) throw Object.assign(new Error('filtro invalido: ' + col), { status: 400 });
        const op = raw.slice(0, i), val = raw.slice(i + 1);
        const c = ident(col);
        if (op === 'is') {
            if (val === 'null') cond.push(c + ' IS NULL');
            else if (val === 'true') cond.push(c + ' IS TRUE');
            else if (val === 'false') cond.push(c + ' IS FALSE');
            else throw Object.assign(new Error('is.' + val + ' nao suportado'), { status: 400 });
        } else if (OPS[op]) {
            binds.push(val);
            cond.push(c + ' ' + OPS[op] + ' $' + binds.length);
        } else {
            throw Object.assign(new Error('operador nao suportado: ' + op), { status: 400 });
        }
    }
    return cond;
}

function montarSelect(params) {
    const s = params.get('select');
    if (!s || s === '*') return '*';
    return s.split(',').map((c) => ident(c.trim())).join(', ');
}

function montarOrder(params) {
    const o = params.get('order');
    if (!o) return '';
    return ' ORDER BY ' + o.split(',').map((p) => {
        const [c, dir] = p.split('.');
        const d = dir === 'desc' ? ' DESC' : ' ASC';
        return ident(c) + d;
    }).join(', ');
}

// intervalo: Range: de-ate (com Range-Unit: items) ou limit/offset na URL
function paginacao(req, params) {
    let limit = null, offset = 0;
    const range = req.headers.get('range');
    if (range && /^\d+-\d+$/.test(range.trim())) {
        const [de, ate] = range.trim().split('-').map(Number);
        offset = de; limit = ate - de + 1;
    }
    if (params.get('limit')) limit = Number(params.get('limit'));
    if (params.get('offset')) offset = Number(params.get('offset'));
    if (limit === null || limit > MAX_LINHAS) limit = MAX_LINHAS;
    return { limit, offset };
}

// ---------- operacoes ----------
async function lerTabela(tabela, params, req) {
    const binds = [];
    const cond = montarFiltros(params, binds);
    const { limit, offset } = paginacao(req, params);
    let sql = 'SELECT ' + montarSelect(params) + ' FROM ' + ident(tabela);
    if (cond.length) sql += ' WHERE ' + cond.join(' AND ');
    sql += montarOrder(params);
    binds.push(limit); sql += ' LIMIT $' + binds.length;
    binds.push(offset); sql += ' OFFSET $' + binds.length;
    return db.sql.unsafe(sql, binds.map(valorParam));
}

async function gravarTabela(tabela, params, req, metodo, corpo) {
    const prefer = req.headers.get('prefer') || '';
    const retornar = prefer.includes('return=representation');
    const fim = retornar ? ' RETURNING *' : '';

    if (metodo === 'POST') {
        const linhas = Array.isArray(corpo) ? corpo : [corpo];
        if (!linhas.length) return null;
        const cols = [...new Set(linhas.flatMap((l) => Object.keys(l)))];
        const colsSql = cols.map(ident);
        const binds = [];
        const tuplas = linhas.map((l) => '(' + cols.map((c) => {
            if (!(c in l)) return 'DEFAULT';
            binds.push(valorParam(l[c]));
            return '$' + binds.length;
        }).join(', ') + ')');
        let sql = 'INSERT INTO ' + ident(tabela) + ' (' + colsSql.join(', ') + ') VALUES ' + tuplas.join(', ');
        const alvo = params.get('on_conflict');
        if (alvo) {
            const chave = alvo.split(',').map((c) => ident(c.trim()));
            const resto = cols.filter((c) => !alvo.split(',').map((x) => x.trim()).includes(c));
            if (/ignore-duplicates/.test(prefer) || !resto.length) sql += ' ON CONFLICT (' + chave.join(', ') + ') DO NOTHING';
            else sql += ' ON CONFLICT (' + chave.join(', ') + ') DO UPDATE SET ' + resto.map((c) => ident(c) + ' = EXCLUDED.' + ident(c)).join(', ');
        }
        return db.sql.unsafe(sql + fim, binds);
    }

    // PATCH e DELETE exigem filtro (evita apagar/alterar a tabela inteira)
    const binds = [];
    const cond = montarFiltros(params, binds);
    if (!cond.length) throw Object.assign(new Error('PATCH/DELETE exigem filtro'), { status: 400 });
    if (metodo === 'DELETE') {
        return db.sql.unsafe('DELETE FROM ' + ident(tabela) + ' WHERE ' + cond.join(' AND ') + fim, binds);
    }
    // PATCH: os valores do SET sao $1..$n; os do WHERE sao renumerados a partir de n+1
    const sets = Object.keys(corpo || {});
    if (!sets.length) return null;
    const nSet = sets.length;
    const setTxt = sets.map((c, i) => ident(c) + ' = $' + (i + 1)).join(', ');
    const whereTxt = cond.map((t) => t.replace(/\$(\d+)/g, (_, n) => '$' + (Number(n) + nSet))).join(' AND ');
    const valsSet = sets.map((c) => valorParam(corpo[c]));
    return db.sql.unsafe('UPDATE ' + ident(tabela) + ' SET ' + setTxt + ' WHERE ' + whereTxt + fim, [...valsSet, ...binds]);
}

async function chamarRpc(nome, params, req, corpo) {
    if (!ID_OK.test(nome)) throw Object.assign(new Error('funcao invalida'), { status: 400 });
    const args = corpo && typeof corpo === 'object' && !Array.isArray(corpo) ? corpo : {};
    const chaves = Object.keys(args);
    chaves.forEach((k) => { if (!/^p_[a-z0-9_]+$/.test(k)) throw Object.assign(new Error('argumento invalido: ' + k), { status: 400 }); });
    const binds = chaves.map((k) => valorParam(args[k]));
    const lista = chaves.map((k, i) => k + ' := $' + (i + 1)).join(', ');
    let sql = 'SELECT * FROM ' + nome + '(' + lista + ')';
    const { limit, offset } = paginacao(req, params);
    if (params.get('limit') || params.get('offset') || req.headers.get('range')) {
        binds.push(limit, offset);
        sql = 'SELECT * FROM (' + sql + ') q LIMIT $' + (binds.length - 1) + ' OFFSET $' + binds.length;
    }
    return db.sql.unsafe(sql, binds);
}

// login do painel: validar nome do encarregado + senha (no servidor, sem devolver senhas)
async function loginPainel(corpo) {
    const linhas = await db.sql.unsafe('SELECT r_nome FROM login_painel($1, $2)', [corpo.p_usuario || '', corpo.p_senha || '']);
    if (!linhas.length) return [];
    return [{ r_nome: linhas[0].r_nome, ...emitirSessao('encarregado:' + linhas[0].r_nome) }];
}

// ---------- entrada ----------
export default async (req) => {
    try {
        const url = new URL(req.url);
        const caminho = url.pathname;
        const params = url.searchParams;

        // /auth/v1/token
        if (caminho.startsWith('/auth/v1/token')) {
            if (req.method !== 'POST') return erro(405, 'metodo nao permitido');
            const corpo = await req.json().catch(() => ({}));
            const tipo = params.get('grant_type');
            if (tipo === 'refresh_token') {
                const p = verificar(corpo.refresh_token, 'refresh');
                if (!p) return erro(400, 'sessao invalida');
                return json(emitirSessao(p.sub));
            }
            if (tipo === 'password') {
                // conta do painel: email + senha (senha guardada como hash bcrypt em acesso_painel)
                const ok = await db.sql.unsafe(
                    'SELECT 1 FROM acesso_painel WHERE id = 1 AND lower(email) = lower($1) AND senha = crypt($2, senha)',
                    [String(corpo.email || '').trim(), String(corpo.password || '')]
                );
                if (!ok.length) return erro(400, 'credenciais invalidas');
                return json(emitirSessao('painel:' + String(corpo.email).trim().toLowerCase()));
            }
            return erro(400, 'grant_type invalido');
        }

        if (!caminho.startsWith('/rest/v1/')) return erro(404, 'nao encontrado');
        const alvo = caminho.slice('/rest/v1/'.length).replace(/\/+$/, '');

        // login por nome de encarregado: publico (valida a senha no servidor)
        if (alvo === 'rpc/login_painel' && req.method === 'POST') {
            return json(await loginPainel(await req.json().catch(() => ({}))));
        }

        const quem = autenticar(req);
        if (!quem) return erro(401, 'nao autorizado');

        if (alvo.startsWith('rpc/')) {
            if (req.method !== 'POST') return erro(405, 'use POST');
            const linhas = await chamarRpc(alvo.slice(4), params, req, await req.json().catch(() => ({})));
            return json(linhas);
        }

        if (!TABELAS.has(alvo)) return erro(404, 'tabela nao existe ou nao e exposta: ' + alvo);

        if (req.method === 'GET') return json(await lerTabela(alvo, params, req));

        if (['POST', 'PATCH', 'DELETE'].includes(req.method)) {
            const corpo = req.method === 'DELETE' ? null : await req.json().catch(() => null);
            const r = await gravarTabela(alvo, params, req, req.method, corpo);
            const prefer = req.headers.get('prefer') || '';
            if (prefer.includes('return=representation')) return json(r || [], req.method === 'POST' ? 201 : 200);
            return new Response(null, { status: req.method === 'POST' ? 201 : 204 });
        }
        return erro(405, 'metodo nao permitido');
    } catch (e) {
        const status = e.status || 500;
        console.error('api:', e.message);
        return erro(status, e.message);
    }
};

export const config = { path: ['/rest/v1/*', '/auth/v1/token'] };
