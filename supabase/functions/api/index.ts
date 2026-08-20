// =====================================================================
//  LIVRARIA INSPIRE — PRESENCE
//  Edge Function: "api"
//  Versao 1.0
//
//  Responsavel pelas acoes que exigem poder de administrador no
//  sistema de contas: criar usuario, trocar senha de qualquer pessoa,
//  reenviar link de recuperacao e excluir conta.
//
//  Todo o resto do sistema (pedidos, estoque, vendas, catalogo)
//  roda direto no banco, protegido por RLS.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY     = Deno.env.get("SUPABASE_ANON_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

/** Confirma que quem chamou esta logado e e administrador aprovado. */
async function requireAdmin(req: Request) {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace("Bearer ", "").trim();
  if (!token) return { error: "Faca login para continuar." };

  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error } = await asUser.auth.getUser();
  if (error || !userData?.user) return { error: "Sessao expirada. Entre novamente." };

  const { data: profile } = await admin
    .from("profiles")
    .select("id, full_name, role, status")
    .eq("id", userData.user.id)
    .single();

  if (!profile || profile.role !== "admin" || profile.status !== "aprovado") {
    return { error: "Esta acao e exclusiva da administracao." };
  }
  return { user: userData.user, profile };
}

async function log(actorId: string, actorName: string, action: string, entityId: string | null, details: unknown) {
  await admin.from("activity_log").insert({
    actor_id: actorId,
    actor_name: actorName,
    action,
    entity: "profiles",
    entity_id: entityId,
    details,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  // aceita tanto /api/rota quanto /rota
  const path = url.pathname.replace(/^\/api/, "").replace(/\/+$/, "") || "/";

  if (path === "/" || path === "/health") {
    return json({ ok: true, service: "inspire-presence-api", version: "1.0" });
  }

  let body: Record<string, any> = {};
  try { body = await req.json(); } catch { body = {}; }

  const guard = await requireAdmin(req);
  if ("error" in guard) return json({ error: guard.error }, 403);
  const { user, profile } = guard as any;

  try {
    switch (path) {
      // -----------------------------------------------------------------
      // Cria um usuario ja aprovado (atalho da administracao)
      // -----------------------------------------------------------------
      case "/create-user": {
        const { email, password, full_name, whatsapp, role, unit_id } = body;
        if (!email || !password) return json({ error: "Informe e-mail e senha." }, 400);
        if (String(password).length < 8) return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);

        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: full_name ?? "", whatsapp: whatsapp ?? "" },
        });
        if (error) return json({ error: error.message }, 400);

        const newId = data.user!.id;
        await admin.from("profiles").upsert({
          id: newId,
          full_name: full_name ?? "",
          email,
          whatsapp: whatsapp ?? "",
          role: role ?? null,
          unit_id: role === "igreja" || role === "ponto" ? unit_id ?? null : null,
          status: role ? "aprovado" : "pendente",
          approved_at: role ? new Date().toISOString() : null,
          approved_by: role ? user.id : null,
        });

        await log(user.id, profile.full_name, "usuario_criado", newId, { email, role });
        return json({ ok: true, user_id: newId });
      }

      // -----------------------------------------------------------------
      // Define uma nova senha para qualquer usuario
      // -----------------------------------------------------------------
      case "/set-password": {
        const { user_id, password } = body;
        if (!user_id || !password) return json({ error: "Informe o usuario e a nova senha." }, 400);
        if (String(password).length < 8) return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);

        const { error } = await admin.auth.admin.updateUserById(user_id, { password });
        if (error) return json({ error: error.message }, 400);

        await log(user.id, profile.full_name, "senha_redefinida", user_id, {});
        return json({ ok: true });
      }

      // -----------------------------------------------------------------
      // Gera link de recuperacao de senha para enviar por WhatsApp
      // -----------------------------------------------------------------
      case "/recovery-link": {
        const { email, redirect_to } = body;
        if (!email) return json({ error: "Informe o e-mail." }, 400);

        const { data, error } = await admin.auth.admin.generateLink({
          type: "recovery",
          email,
          options: redirect_to ? { redirectTo: redirect_to } : undefined,
        });
        if (error) return json({ error: error.message }, 400);

        await log(user.id, profile.full_name, "link_recuperacao", null, { email });
        return json({ ok: true, link: data.properties?.action_link });
      }

      // -----------------------------------------------------------------
      // Confirma o e-mail de um usuario manualmente
      // -----------------------------------------------------------------
      case "/confirm-email": {
        const { user_id } = body;
        if (!user_id) return json({ error: "Informe o usuario." }, 400);
        const { error } = await admin.auth.admin.updateUserById(user_id, { email_confirm: true });
        if (error) return json({ error: error.message }, 400);
        await log(user.id, profile.full_name, "email_confirmado", user_id, {});
        return json({ ok: true });
      }

      // -----------------------------------------------------------------
      // Exclui definitivamente uma conta
      // -----------------------------------------------------------------
      case "/delete-user": {
        const { user_id } = body;
        if (!user_id) return json({ error: "Informe o usuario." }, 400);
        if (user_id === user.id) return json({ error: "Voce nao pode excluir a propria conta." }, 400);

        const { error } = await admin.auth.admin.deleteUser(user_id);
        if (error) return json({ error: error.message }, 400);

        await log(user.id, profile.full_name, "usuario_excluido", user_id, {});
        return json({ ok: true });
      }

      default:
        return json({ error: "Rota nao encontrada." }, 404);
    }
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
