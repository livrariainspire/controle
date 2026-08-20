-- =====================================================================
--  LIVRARIA INSPIRE — PRESENCE
--  Estrutura completa do banco de dados (Supabase / PostgreSQL)
--  Versao 1.0
--
--  COMO USAR: cole este arquivo inteiro no SQL Editor do Supabase
--  e clique em RUN. Pode rodar mais de uma vez sem quebrar nada.
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";
create extension if not exists "unaccent";

-- ---------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------
do $$ begin
  create type user_role   as enum ('admin','atendente','igreja','ponto');
exception when duplicate_object then null; end $$;

do $$ begin
  create type user_status as enum ('pendente','aprovado','rejeitado','inativo');
exception when duplicate_object then null; end $$;

do $$ begin
  create type unit_type   as enum ('igreja','ponto');
exception when duplicate_object then null; end $$;

do $$ begin
  create type product_type as enum ('livro','item');
exception when duplicate_object then null; end $$;

do $$ begin
  create type visibility  as enum ('igreja','ponto','ambos');
exception when duplicate_object then null; end $$;

do $$ begin
  create type order_status as enum ('fila','em_atendimento','enviado','cancelado');
exception when duplicate_object then null; end $$;


-- ---------------------------------------------------------------------
-- 2. TABELAS
-- ---------------------------------------------------------------------

-- 2.1 Unidades (Igrejas da Rede e Pontos de Partida)
create table if not exists public.units (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        unit_type not null,
  responsible text,
  phone       text,
  city        text,
  state       text,
  address     text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists units_type_idx on public.units(type);

-- 2.2 Perfis de usuario (espelha auth.users)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  email       text not null default '',
  whatsapp    text not null default '',
  role        user_role,
  unit_id     uuid references public.units(id) on delete set null,
  status      user_status not null default 'pendente',
  created_at  timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  note        text
);
create index if not exists profiles_status_idx on public.profiles(status);
create index if not exists profiles_unit_idx   on public.profiles(unit_id);

-- 2.3 Catalogo (livros e demais itens)
create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  type        product_type not null default 'livro',
  title       text not null,
  author      text,
  edition     text,
  summary     text,
  photo_url   text,
  visibility  visibility not null default 'ambos',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null,
  search_text text generated always as (
    lower(coalesce(title,'')||' '||coalesce(author,'')||' '||
          coalesce(edition,'')||' '||coalesce(summary,''))
  ) stored
);
create index if not exists products_search_idx on public.products using gin (search_text gin_trgm_ops);
create index if not exists products_vis_idx    on public.products(visibility) where active;

-- 2.4 Pedidos feitos pelas unidades
create table if not exists public.orders (
  id                 uuid primary key default gen_random_uuid(),
  code               text unique,
  unit_id            uuid not null references public.units(id) on delete restrict,
  unit_name          text not null default '',
  requested_by       uuid references auth.users(id) on delete set null,
  requested_by_name  text not null default '',
  attendant_id       uuid references auth.users(id) on delete set null,
  attendant_name     text,
  status             order_status not null default 'fila',
  note               text,
  cancel_reason      text,
  created_at         timestamptz not null default now(),
  claimed_at         timestamptz,
  completed_at       timestamptz,
  canceled_at        timestamptz
);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_unit_idx   on public.orders(unit_id);
create index if not exists orders_att_idx    on public.orders(attendant_id);

create table if not exists public.order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.orders(id) on delete cascade,
  product_id     uuid not null references public.products(id) on delete restrict,
  product_title  text not null default '',
  qty_requested  integer not null check (qty_requested > 0),
  qty_sent       integer not null default 0 check (qty_sent >= 0)
);
create index if not exists order_items_order_idx on public.order_items(order_id);

-- 2.5 Estoque por unidade
create table if not exists public.stock (
  unit_id    uuid not null references public.units(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty        integer not null default 0 check (qty >= 0),
  updated_at timestamptz not null default now(),
  primary key (unit_id, product_id)
);

-- 2.6 Vendas registradas pelas unidades (baixa de estoque)
create table if not exists public.sales (
  id              uuid primary key default gen_random_uuid(),
  code            text unique,
  unit_id         uuid not null references public.units(id) on delete restrict,
  unit_name       text not null default '',
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text not null default '',
  total           numeric(12,2) not null default 0,
  receipt_path    text,
  note            text,
  created_at      timestamptz not null default now()
);
create index if not exists sales_unit_idx on public.sales(unit_id);
create index if not exists sales_date_idx on public.sales(created_at);

create table if not exists public.sale_items (
  id            uuid primary key default gen_random_uuid(),
  sale_id       uuid not null references public.sales(id) on delete cascade,
  product_id    uuid not null references public.products(id) on delete restrict,
  product_title text not null default '',
  qty           integer not null check (qty > 0),
  unit_price    numeric(12,2) not null default 0,
  subtotal      numeric(12,2) not null default 0
);
create index if not exists sale_items_sale_idx on public.sale_items(sale_id);

-- 2.7 Registro de acoes (auditoria)
create table if not exists public.activity_log (
  id         bigserial primary key,
  actor_id   uuid references auth.users(id) on delete set null,
  actor_name text,
  action     text not null,
  entity     text,
  entity_id  uuid,
  details    jsonb,
  created_at timestamptz not null default now()
);
create index if not exists log_date_idx   on public.activity_log(created_at desc);
create index if not exists log_entity_idx on public.activity_log(entity, entity_id);

-- 2.8 Sequencias para codigos amigaveis
create sequence if not exists public.order_code_seq start 1;
create sequence if not exists public.sale_code_seq  start 1;


-- ---------------------------------------------------------------------
-- 3. FUNCOES AUXILIARES
-- ---------------------------------------------------------------------

create or replace function public.my_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and status = 'aprovado';
$$;

create or replace function public.my_unit() returns uuid
language sql stable security definer set search_path = public as $$
  select unit_id from public.profiles where id = auth.uid() and status = 'aprovado';
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and role = 'admin' and status = 'aprovado');
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and role in ('admin','atendente') and status = 'aprovado');
$$;

create or replace function public.my_name() returns text
language sql stable security definer set search_path = public as $$
  select coalesce(full_name, email) from public.profiles where id = auth.uid();
$$;

create or replace function public.log_action(
  p_action text, p_entity text, p_entity_id uuid, p_details jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = public as $$
  insert into public.activity_log(actor_id, actor_name, action, entity, entity_id, details)
  values (auth.uid(), public.my_name(), p_action, p_entity, p_entity_id, p_details);
$$;


-- ---------------------------------------------------------------------
-- 4. CRIACAO AUTOMATICA DO PERFIL AO CADASTRAR
--    O e-mail do administrador master ja entra aprovado.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_admin boolean;
begin
  v_admin := lower(new.email) = 'livraria.app@livrariainspire.com.br';

  insert into public.profiles (id, full_name, email, whatsapp, role, status, approved_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.email,
    coalesce(new.raw_user_meta_data->>'whatsapp',''),
    case when v_admin then 'admin'::user_role else null end,
    case when v_admin then 'aprovado'::user_status else 'pendente'::user_status end,
    case when v_admin then now() else null end
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- 5. REGRAS DE NEGOCIO (RPC)
-- ---------------------------------------------------------------------

-- 5.1 Admin aprova um cadastro e define perfil + unidade
create or replace function public.fn_approve_user(
  p_user uuid, p_role user_role, p_unit uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode aprovar cadastros.'; end if;
  if p_role in ('igreja','ponto') and p_unit is null then
    raise exception 'Selecione a unidade para este perfil.';
  end if;
  if p_role in ('igreja','ponto') then
    if not exists (select 1 from public.units u
                   where u.id = p_unit and u.type::text = p_role::text) then
      raise exception 'A unidade escolhida nao corresponde ao perfil selecionado.';
    end if;
  end if;

  update public.profiles
     set role = p_role,
         unit_id = case when p_role in ('igreja','ponto') then p_unit else null end,
         status = 'aprovado', approved_at = now(), approved_by = auth.uid()
   where id = p_user;

  perform public.log_action('usuario_aprovado','profiles',p_user,
    jsonb_build_object('role',p_role,'unit_id',p_unit));
end $$;

-- 5.2 Admin recusa / desativa um cadastro
create or replace function public.fn_set_user_status(
  p_user uuid, p_status user_status, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode alterar cadastros.'; end if;
  update public.profiles set status = p_status, note = p_note where id = p_user;
  perform public.log_action('usuario_status','profiles',p_user,
    jsonb_build_object('status',p_status,'note',p_note));
end $$;

-- 5.3 Unidade cria um pedido
--     p_items = [{"product_id":"...","qty":2}, ...]
create or replace function public.fn_create_order(
  p_items jsonb, p_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_order uuid; v_unit uuid; v_role user_role; v_item jsonb; v_title text; v_count int := 0;
begin
  v_role := public.my_role(); v_unit := public.my_unit();
  if v_role not in ('igreja','ponto') then raise exception 'Apenas unidades podem criar pedidos.'; end if;
  if v_unit is null then raise exception 'Seu usuario nao esta vinculado a uma unidade.'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Inclua ao menos um item no pedido.'; end if;

  insert into public.orders (code, unit_id, unit_name, requested_by, requested_by_name, note)
  select 'PED-'||lpad(nextval('public.order_code_seq')::text,5,'0'),
         u.id, u.name, auth.uid(), public.my_name(), p_note
    from public.units u where u.id = v_unit
  returning id into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select title into v_title from public.products
     where id = (v_item->>'product_id')::uuid and active;
    if v_title is null then raise exception 'Produto indisponivel no catalogo.'; end if;
    insert into public.order_items (order_id, product_id, product_title, qty_requested)
    values (v_order, (v_item->>'product_id')::uuid, v_title, (v_item->>'qty')::int);
    v_count := v_count + 1;
  end loop;

  perform public.log_action('pedido_criado','orders',v_order, jsonb_build_object('itens',v_count));
  return v_order;
end $$;

-- 5.4 Atendente puxa o pedido da fila
create or replace function public.fn_claim_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_rows int;
begin
  if public.my_role() not in ('atendente','admin') then
    raise exception 'Apenas atendentes podem puxar pedidos.'; end if;

  update public.orders
     set status='em_atendimento', attendant_id=auth.uid(),
         attendant_name=public.my_name(), claimed_at=now()
   where id=p_order and status='fila';
  get diagnostics v_rows = row_count;
  if v_rows = 0 then raise exception 'Este pedido ja foi puxado por outro atendente.'; end if;

  perform public.log_action('pedido_puxado','orders',p_order,'{}'::jsonb);
end $$;

-- 5.5 Atendente devolve o pedido para a fila
create or replace function public.fn_release_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_staff() then raise exception 'Sem permissao.'; end if;
  update public.orders
     set status='fila', attendant_id=null, attendant_name=null, claimed_at=null
   where id=p_order and status='em_atendimento'
     and (attendant_id = auth.uid() or public.is_admin());
  perform public.log_action('pedido_devolvido','orders',p_order,'{}'::jsonb);
end $$;

-- 5.6 Admin transfere o pedido para outro atendente
create or replace function public.fn_reassign_order(p_order uuid, p_attendant uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode redirecionar pedidos.'; end if;
  select full_name into v_name from public.profiles
   where id=p_attendant and role='atendente' and status='aprovado';
  if v_name is null then raise exception 'Atendente invalido.'; end if;

  update public.orders
     set attendant_id=p_attendant, attendant_name=v_name,
         status='em_atendimento', claimed_at=coalesce(claimed_at, now())
   where id=p_order and status in ('fila','em_atendimento');

  perform public.log_action('pedido_redirecionado','orders',p_order,
    jsonb_build_object('para',v_name,'atendente_id',p_attendant));
end $$;

-- 5.7 Atendente finaliza o envio (credita estoque da unidade)
--     p_items = [{"item_id":"...","qty_sent":2}, ...]
create or replace function public.fn_fulfill_order(p_order uuid, p_items jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v_unit uuid; v_status order_status; v_item jsonb; v_qty int; v_prod uuid;
begin
  if not public.is_staff() then raise exception 'Sem permissao.'; end if;
  select unit_id, status into v_unit, v_status from public.orders where id=p_order;
  if v_unit is null then raise exception 'Pedido nao encontrado.'; end if;
  if v_status <> 'em_atendimento' then raise exception 'O pedido precisa estar em atendimento.'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'qty_sent')::int;
    update public.order_items set qty_sent = v_qty
     where id = (v_item->>'item_id')::uuid and order_id = p_order
    returning product_id into v_prod;

    if v_prod is not null and v_qty > 0 then
      insert into public.stock (unit_id, product_id, qty, updated_at)
      values (v_unit, v_prod, v_qty, now())
      on conflict (unit_id, product_id)
      do update set qty = public.stock.qty + excluded.qty, updated_at = now();
    end if;
  end loop;

  update public.orders set status='enviado', completed_at=now() where id=p_order;
  perform public.log_action('pedido_enviado','orders',p_order, jsonb_build_object('itens',p_items));
end $$;

-- 5.8 Cancelar pedido
create or replace function public.fn_cancel_order(p_order uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_unit uuid;
begin
  select unit_id into v_unit from public.orders where id=p_order;
  if not (public.is_staff() or (public.my_unit() = v_unit and public.my_role() in ('igreja','ponto'))) then
    raise exception 'Sem permissao para cancelar este pedido.'; end if;

  update public.orders set status='cancelado', cancel_reason=p_reason, canceled_at=now()
   where id=p_order and status in ('fila','em_atendimento');
  perform public.log_action('pedido_cancelado','orders',p_order, jsonb_build_object('motivo',p_reason));
end $$;

-- 5.9 Unidade registra a venda (baixa automatica do estoque)
--     p_items = [{"product_id":"...","qty":2,"unit_price":49.90}, ...]
create or replace function public.fn_create_sale(
  p_items jsonb, p_receipt text default null, p_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_sale uuid; v_unit uuid; v_item jsonb; v_qty int; v_price numeric;
  v_prod uuid; v_title text; v_have int; v_total numeric := 0;
begin
  if public.my_role() not in ('igreja','ponto') then
    raise exception 'Apenas unidades registram vendas.'; end if;
  v_unit := public.my_unit();
  if v_unit is null then raise exception 'Seu usuario nao esta vinculado a uma unidade.'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Inclua ao menos um item na venda.'; end if;

  insert into public.sales (code, unit_id, unit_name, created_by, created_by_name, receipt_path, note)
  select 'VEN-'||lpad(nextval('public.sale_code_seq')::text,5,'0'),
         u.id, u.name, auth.uid(), public.my_name(), p_receipt, p_note
    from public.units u where u.id = v_unit
  returning id into v_sale;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_prod  := (v_item->>'product_id')::uuid;
    v_qty   := (v_item->>'qty')::int;
    v_price := coalesce((v_item->>'unit_price')::numeric, 0);

    select title into v_title from public.products where id = v_prod;
    select qty into v_have from public.stock where unit_id=v_unit and product_id=v_prod;
    if coalesce(v_have,0) < v_qty then
      raise exception 'Estoque insuficiente de "%": voce tem % e tentou vender %.',
        coalesce(v_title,'produto'), coalesce(v_have,0), v_qty;
    end if;

    update public.stock set qty = qty - v_qty, updated_at=now()
     where unit_id=v_unit and product_id=v_prod;

    insert into public.sale_items (sale_id, product_id, product_title, qty, unit_price, subtotal)
    values (v_sale, v_prod, coalesce(v_title,''), v_qty, v_price, v_qty*v_price);

    v_total := v_total + (v_qty * v_price);
  end loop;

  update public.sales set total = v_total where id = v_sale;
  perform public.log_action('venda_registrada','sales',v_sale, jsonb_build_object('total',v_total));
  return v_sale;
end $$;

-- 5.10 Relatorios consolidados para o admin
create or replace function public.fn_report_sales(
  p_from date default null, p_to date default null
) returns table (
  unit_id uuid, unit_name text, unit_type unit_type,
  vendas bigint, itens bigint, total numeric
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.type,
         count(distinct s.id),
         coalesce(sum(si.qty),0),
         coalesce(sum(si.subtotal),0)
    from public.units u
    left join public.sales s on s.unit_id = u.id
      and (p_from is null or s.created_at >= p_from)
      and (p_to   is null or s.created_at < (p_to + 1))
    left join public.sale_items si on si.sale_id = s.id
   where public.is_admin()
   group by u.id, u.name, u.type
   order by 6 desc, 2;
$$;

create or replace function public.fn_report_stock()
returns table (
  unit_id uuid, unit_name text, unit_type unit_type,
  product_id uuid, product_title text, product_type product_type, qty integer
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.type, p.id, p.title, p.type, st.qty
    from public.stock st
    join public.units u    on u.id = st.unit_id
    join public.products p on p.id = st.product_id
   where public.is_admin() and st.qty > 0
   order by u.name, p.title;
$$;


-- ---------------------------------------------------------------------
-- 6. SEGURANCA (RLS)
-- ---------------------------------------------------------------------
alter table public.units        enable row level security;
alter table public.profiles     enable row level security;
alter table public.products     enable row level security;
alter table public.orders       enable row level security;
alter table public.order_items  enable row level security;
alter table public.stock        enable row level security;
alter table public.sales        enable row level security;
alter table public.sale_items   enable row level security;
alter table public.activity_log enable row level security;

-- perfis
drop policy if exists p_profiles_self on public.profiles;
create policy p_profiles_self on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());

drop policy if exists p_profiles_staff on public.profiles;
create policy p_profiles_staff on public.profiles
  for select to authenticated
  using (public.is_staff() and role in ('atendente','admin'));

drop policy if exists p_profiles_update_self on public.profiles;
create policy p_profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists p_profiles_admin on public.profiles;
create policy p_profiles_admin on public.profiles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- unidades
drop policy if exists p_units_read on public.units;
create policy p_units_read on public.units
  for select to authenticated using (true);

drop policy if exists p_units_admin on public.units;
create policy p_units_admin on public.units
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- catalogo
drop policy if exists p_products_read on public.products;
create policy p_products_read on public.products
  for select to authenticated using (
    public.is_staff()
    or (active and (
         visibility = 'ambos'
         or (visibility = 'igreja' and public.my_role() = 'igreja')
         or (visibility = 'ponto'  and public.my_role() = 'ponto')
       ))
  );

drop policy if exists p_products_admin on public.products;
create policy p_products_admin on public.products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- pedidos
drop policy if exists p_orders_read on public.orders;
create policy p_orders_read on public.orders
  for select to authenticated
  using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_order_items_read on public.order_items;
create policy p_order_items_read on public.order_items
  for select to authenticated using (
    exists (select 1 from public.orders o where o.id = order_id
            and (public.is_staff() or o.unit_id = public.my_unit()))
  );

-- estoque
drop policy if exists p_stock_read on public.stock;
create policy p_stock_read on public.stock
  for select to authenticated
  using (public.is_staff() or unit_id = public.my_unit());

-- vendas
drop policy if exists p_sales_read on public.sales;
create policy p_sales_read on public.sales
  for select to authenticated
  using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_sale_items_read on public.sale_items;
create policy p_sale_items_read on public.sale_items
  for select to authenticated using (
    exists (select 1 from public.sales s where s.id = sale_id
            and (public.is_staff() or s.unit_id = public.my_unit()))
  );

-- auditoria
drop policy if exists p_log_admin on public.activity_log;
create policy p_log_admin on public.activity_log
  for select to authenticated using (public.is_admin());


-- ---------------------------------------------------------------------
-- 7. ARQUIVOS (Storage)
--    produtos     -> publico  (fotos do catalogo)
--    comprovantes -> privado  (fotos das vendas)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('produtos','produtos', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('comprovantes','comprovantes', false)
on conflict (id) do nothing;

drop policy if exists s_produtos_read on storage.objects;
create policy s_produtos_read on storage.objects
  for select using (bucket_id = 'produtos');

drop policy if exists s_produtos_write on storage.objects;
create policy s_produtos_write on storage.objects
  for insert to authenticated with check (bucket_id='produtos' and public.is_admin());

drop policy if exists s_produtos_del on storage.objects;
create policy s_produtos_del on storage.objects
  for delete to authenticated using (bucket_id='produtos' and public.is_admin());

drop policy if exists s_comprovantes_write on storage.objects;
create policy s_comprovantes_write on storage.objects
  for insert to authenticated with check (
    bucket_id='comprovantes' and public.my_role() in ('igreja','ponto','admin')
  );

drop policy if exists s_comprovantes_read on storage.objects;
create policy s_comprovantes_read on storage.objects
  for select to authenticated using (
    bucket_id='comprovantes' and (
      public.is_staff() or (storage.foldername(name))[1] = public.my_unit()::text
    )
  );


-- ---------------------------------------------------------------------
-- 8. PERMISSOES DE EXECUCAO
-- ---------------------------------------------------------------------
grant execute on function
  public.fn_approve_user(uuid,user_role,uuid),
  public.fn_set_user_status(uuid,user_status,text),
  public.fn_create_order(jsonb,text),
  public.fn_claim_order(uuid),
  public.fn_release_order(uuid),
  public.fn_reassign_order(uuid,uuid),
  public.fn_fulfill_order(uuid,jsonb),
  public.fn_cancel_order(uuid,text),
  public.fn_create_sale(jsonb,text,text),
  public.fn_report_sales(date,date),
  public.fn_report_stock(),
  public.my_role(), public.my_unit(), public.is_admin(), public.is_staff()
to authenticated;

-- =====================================================================
--  FIM
-- =====================================================================
