-- =============================================================================
-- Membership (m_*) RLS tests. Run after migrations (see scripts/test-local.sh).
-- Fixtures are created here; the membership demo seed is separate.
-- =============================================================================
\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Fixtures: club A (all modules) and club B (agent only)
-- -----------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('c0000000-0000-4000-8000-000000000001', 'm-admin@club-a.example.com'),
  ('c0000000-0000-4000-8000-000000000002', 'm-attendant@club-a.example.com'),
  ('c0000000-0000-4000-8000-000000000011', 'm-holder@club-a.example.com'),
  ('c0000000-0000-4000-8000-000000000012', 'm-dependent@club-a.example.com'),
  ('c0000000-0000-4000-8000-000000000013', 'm-other@club-a.example.com'),
  ('d0000000-0000-4000-8000-000000000001', 'm-admin@club-b.example.com');

insert into public.m_tenants (id, name, slug) values
  ('11000000-0000-4000-8000-000000000001', 'Club A', 'club-a'),
  ('11000000-0000-4000-8000-000000000002', 'Club B', 'club-b');

insert into public.m_tenant_modules (tenant_id, module)
select '11000000-0000-4000-8000-000000000001', m from unnest(enum_range(null::public.m_module_key)) m;
insert into public.m_tenant_modules (tenant_id, module) values
  ('11000000-0000-4000-8000-000000000002', 'agent');

insert into public.m_people (id, tenant_id, full_name, phone_e164) values
  ('21000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'Admin A',     '+5511910000001'),
  ('21000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', 'Attendant A', '+5511910000002'),
  ('21000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', 'Holder',      '+5511910000011'),
  ('21000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', 'Dependent',   null),
  ('21000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', 'Other Member','+5511910000013'),
  ('21000000-0000-4000-8000-000000000014', '11000000-0000-4000-8000-000000000001', 'Lead',        '+5511910000014'),
  ('21000000-0000-4000-8000-0000000000b1', '11000000-0000-4000-8000-000000000002', 'Admin B',     '+5511910000001');

insert into public.m_people_private (tenant_id, person_id, cpf) values
  ('11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000011', '12345678901');

insert into public.m_user_roles (tenant_id, user_id, person_id, role) values
  ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', 'admin'),
  ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000002', 'attendant'),
  ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000011', '21000000-0000-4000-8000-000000000011', 'member'),
  ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000012', '21000000-0000-4000-8000-000000000012', 'member'),
  ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000013', '21000000-0000-4000-8000-000000000013', 'member'),
  ('11000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-0000000000b1', 'admin');

insert into public.m_plans (id, tenant_id, name, price_cents, max_people) values
  ('31000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'Família', 29900, 2),
  ('31000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', 'Individual', 14900, 1);

insert into public.m_subscriptions (id, tenant_id, holder_person_id, plan_id) values
  ('41000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000011', '31000000-0000-4000-8000-000000000001'),
  ('41000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000013', '31000000-0000-4000-8000-000000000002');

insert into public.m_subscription_members (tenant_id, subscription_id, person_id) values
  ('11000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000012');

insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date) values
  ('11000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', 29900, current_date),
  ('11000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000002', 14900, current_date);

insert into public.m_pipeline_stages (id, tenant_id, name, position) values
  ('51000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'Novo', 1);
insert into public.m_leads (tenant_id, person_id, stage_id) values
  ('11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000014', '51000000-0000-4000-8000-000000000001');

insert into public.m_tasks (tenant_id, title, person_id) values
  ('11000000-0000-4000-8000-000000000001', 'Ligar para o Holder', '21000000-0000-4000-8000-000000000011');

-- -----------------------------------------------------------------------------
-- 1. Tenant isolation
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  assert (select count(*) from public.m_people) = 6, 'admin A sees the 6 people of club A';
  assert (select count(*) from public.m_tenants) = 1, 'admin A sees only club A';
  assert (select count(*) from public.m_invoices) = 2, 'admin A sees all invoices of club A';
  assert (select count(*) from public.m_people_private) = 1, 'admin sees CPF';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  assert (select count(*) from public.m_people) = 1, 'admin B sees only club B';
  assert (select count(*) from public.m_leads) = 0, 'club B sees no leads (no access to A; no capture module)';
  assert (select count(*) from public.m_tasks) = 0, 'club B sees no tasks of A';
end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 2. Attendant: operational access, no CPF, no billing writes
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000002"}', true);
do $$ begin
  assert (select count(*) from public.m_people_private) = 0, 'attendant must not see CPF';
  assert (select count(*) from public.m_leads) = 1, 'attendant sees leads';
  assert (select count(*) from public.m_tasks) = 1, 'attendant sees tasks';
end $$;
insert into public.m_tasks (tenant_id, title) values ('11000000-0000-4000-8000-000000000001', 'Nova tarefa');
do $$ begin
  begin
    update public.m_invoices set status = 'canceled';
    if (select count(*) from public.m_invoices where status = 'canceled') > 0 then
      raise exception 'FAIL: attendant changed an invoice';
    end if;
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 3. Portal: holder, dependent, other member
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000011"}', true);
do $$ begin
  assert (select count(*) from public.m_people) = 2, 'holder sees self + dependent';
  assert (select count(*) from public.m_subscriptions) = 1, 'holder sees own subscription only';
  assert (select count(*) from public.m_invoices) = 1, 'holder sees own invoices only';
  assert (select count(*) from public.m_plans) = 2, 'members see active plans';
  assert (select count(*) from public.m_leads) = 0, 'members never see leads';
  assert (select count(*) from public.m_tasks) = 0, 'members never see tasks';
  assert (select count(*) from public.m_people_private) = 0, 'members never see CPF';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000012"}', true);
do $$ begin
  assert (select count(*) from public.m_people) = 1, 'dependent sees only self';
  assert (select count(*) from public.m_subscriptions) = 1, 'dependent sees the family subscription';
  assert (select count(*) from public.m_invoices) = 0, 'only the holder sees invoices';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000013"}', true);
do $$ begin
  assert (select count(*) from public.m_subscriptions) = 1, 'other member sees only own subscription';
  assert not exists (select 1 from public.m_people where full_name = 'Holder'), 'members cannot see each other';
end $$;
-- a member cannot pause/cancel their own subscription (team only)
do $$ begin
  begin
    update public.m_subscriptions set status = 'paused';
    if exists (select 1 from public.m_subscriptions where status = 'paused') then
      raise exception 'FAIL: member paused own subscription';
    end if;
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- member cannot create people or grant roles
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000011"}', true);
do $$ begin
  begin
    insert into public.m_user_roles (tenant_id, user_id, person_id, role) values
      ('11000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000011',
       '21000000-0000-4000-8000-000000000011', 'admin');
    raise exception 'FAIL: member granted itself admin';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 4. Schema guarantees
-- -----------------------------------------------------------------------------
-- Plan capacity: Família allows 2 (holder + 1 dependent), third person rejected
do $$ begin
  begin
    insert into public.m_subscription_members (tenant_id, subscription_id, person_id) values
      ('11000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001',
       '21000000-0000-4000-8000-000000000014');
    raise exception 'FAIL: plan capacity exceeded';
  exception when check_violation then null;
  end;
end $$;

-- Holder cannot be their own dependent
do $$ begin
  begin
    insert into public.m_subscription_members (tenant_id, subscription_id, person_id) values
      ('11000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000002',
       '21000000-0000-4000-8000-000000000013');
    raise exception 'FAIL: holder added as dependent';
  exception when check_violation then null;
  end;
end $$;

-- Cross-tenant reference rejected by composite FK
do $$ begin
  begin
    insert into public.m_tasks (tenant_id, title, person_id) values
      ('11000000-0000-4000-8000-000000000001', 'x', '21000000-0000-4000-8000-0000000000b1');
    raise exception 'FAIL: cross-tenant task accepted';
  exception when foreign_key_violation then null;
  end;
end $$;

-- Module gating
do $$ begin
  assert app.m_module_enabled('11000000-0000-4000-8000-000000000002', 'agent'), 'club B has agent';
  assert not app.m_module_enabled('11000000-0000-4000-8000-000000000002', 'tasks'), 'club B lacks tasks';
end $$;

-- Educational and membership demos never see each other
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 0, 'membership admin sees no educational data';
end $$;
rollback;

-- Assistant comments: team only, never across tenants
insert into public.m_ai_insights (tenant_id, scope, body) values
  ('11000000-0000-4000-8000-000000000001', 'pipeline', 'Resumo do dia');
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000002"}', true);
do $$ begin
  assert (select count(*) from public.m_ai_insights) = 1, 'attendant sees only own club insights';
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000011"}', true);
do $$ begin
  assert (select count(*) from public.m_ai_insights) = 0, 'members never see assistant comments';
end $$;
rollback;

-- Anonymous requests see nothing
begin;
set local role anon;
do $$ begin
  assert (select count(*) from public.m_people) = 0, 'anon sees nothing';
end $$;
rollback;

\echo 'ALL MEMBERSHIP RLS TESTS PASSED'
