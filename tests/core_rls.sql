-- =============================================================================
-- Core RLS tests. Run after migrations + seed (see scripts/test-local.sh).
-- Each scenario runs in its own transaction as the `authenticated` role with a
-- fake JWT, exactly like a request coming through the Supabase Data API.
-- =============================================================================
\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Fixtures (as superuser): logins for school A, and a second school B
-- -----------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000001', 'ana.ribeiro@example.com'),
  ('a0000000-0000-4000-8000-000000000002', 'daniel.souza@example.com'),
  ('a0000000-0000-4000-8000-000000000009', 'office@example.com'),
  ('a0000000-0000-4000-8000-000000000011', 'bruno.carvalho@example.com'),
  ('a0000000-0000-4000-8000-000000000021', 'maria.albuquerque@example.com'),
  ('b0000000-0000-4000-8000-000000000001', 'admin@school-b.example.com');

insert into public.e_people (id, tenant_id, full_name) values
  ('20000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001', 'Front Office');

insert into public.e_user_roles (tenant_id, user_id, person_id, role) values
  ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'admin'),
  ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'teacher'),
  ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000009', '20000000-0000-4000-8000-000000000009', 'staff'),
  ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000011', 'student'),
  ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000021', '20000000-0000-4000-8000-000000000021', 'guardian');

insert into public.e_tenants (id, name, slug) values
  ('10000000-0000-4000-8000-000000000002', 'School B', 'school-b');
insert into public.e_tenant_modules (tenant_id, module) values
  ('10000000-0000-4000-8000-000000000002', 'agent');
insert into public.e_people (id, tenant_id, full_name, phone_e164) values
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000002', 'School B Admin', '+5511900000001');
insert into public.e_user_roles (tenant_id, user_id, person_id, role) values
  ('10000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000b1', 'admin');

-- -----------------------------------------------------------------------------
-- 1. Tenant isolation
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 10, 'admin A should see all 10 people of school A';
  assert (select count(*) from public.e_people where tenant_id = '10000000-0000-4000-8000-000000000002') = 0,
    'admin A must not see school B';
  assert (select count(*) from public.e_tenants) = 1, 'admin A sees only its own tenant';
  assert (select count(*) from public.e_tenant_modules) = 7, 'school A has all 7 modules';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 1, 'admin B sees only school B';
  assert (select count(*) from public.e_courses) = 0, 'admin B sees no courses of school A';
end $$;
rollback;

-- Same phone in two schools is allowed (uniqueness is per tenant).
do $$ begin
  assert (select count(*) from public.e_people where phone_e164 = '+5511900000001') = 2,
    'phone uniqueness must be per tenant';
end $$;

-- -----------------------------------------------------------------------------
-- 2. Role-based visibility
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000011"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 1, 'student sees only themself';
  assert (select full_name from public.e_people) = 'Bruno Carvalho', 'student row is their own';
  assert (select count(*) from public.e_user_roles) = 1, 'student sees only own role';
  assert (select count(*) from public.e_courses) = 3, 'members see the course catalog';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000021"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 2, 'guardian sees self + ward';
  assert exists (select 1 from public.e_people where full_name = 'Pedro Albuquerque'), 'guardian sees Pedro';
  assert (select count(*) from public.e_guardianships) = 1, 'guardian sees own guardianship';
end $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002"}', true);
do $$ begin
  assert (select count(*) from public.e_people) = 10, 'teacher sees people of the school';
end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 3. Writes
-- -----------------------------------------------------------------------------
-- staff can register people
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009"}', true);
insert into public.e_people (tenant_id, full_name) values ('10000000-0000-4000-8000-000000000001', 'New Lead');
update public.e_people set full_name = 'Bruno C. Carvalho' where id = '20000000-0000-4000-8000-000000000011';
do $$ begin
  assert (select updated_at > created_at from public.e_people where id = '20000000-0000-4000-8000-000000000011'),
    'updated_at trigger fires for API users';
end $$;
rollback;

-- student cannot register people
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000011"}', true);
do $$ begin
  begin
    insert into public.e_people (tenant_id, full_name) values ('10000000-0000-4000-8000-000000000001', 'Hacker');
    raise exception 'FAIL: student inserted a person';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- staff cannot grant roles (no privilege escalation)
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009"}', true);
do $$ begin
  begin
    insert into public.e_user_roles (tenant_id, user_id, person_id, role) values
      ('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000009',
       '20000000-0000-4000-8000-000000000009', 'admin');
    raise exception 'FAIL: staff granted itself admin';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- admin A cannot write into school B
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  begin
    insert into public.e_people (tenant_id, full_name) values ('10000000-0000-4000-8000-000000000002', 'Intruder');
    raise exception 'FAIL: admin A wrote into school B';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- Nobody can change module entitlements through the API
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001"}', true);
do $$ begin
  begin
    insert into public.e_tenant_modules (tenant_id, module)
      values ('10000000-0000-4000-8000-000000000002', 'finance');
    raise exception 'FAIL: tenant_modules writable';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 4. Schema guarantees (even for service role / buggy code)
-- -----------------------------------------------------------------------------
-- Guardianship across schools is rejected by the composite FK
do $$ begin
  begin
    insert into public.e_guardianships (tenant_id, guardian_person_id, student_person_id) values
      ('10000000-0000-4000-8000-000000000001',
       '20000000-0000-4000-8000-0000000000b1',   -- person from school B
       '20000000-0000-4000-8000-000000000015');
    raise exception 'FAIL: cross-tenant guardianship accepted';
  exception when foreign_key_violation then null;
  end;
end $$;

-- -----------------------------------------------------------------------------
-- 5. Module entitlement helper
-- -----------------------------------------------------------------------------
do $$ begin
  assert app.e_module_enabled('10000000-0000-4000-8000-000000000002', 'agent'), 'school B has agent';
  assert not app.e_module_enabled('10000000-0000-4000-8000-000000000002', 'academic'), 'school B lacks academic';
end $$;

-- Anonymous requests see nothing
begin;
set local role anon;
do $$ begin
  assert (select count(*) from public.e_people) = 0, 'anon sees nothing';
end $$;
rollback;

\echo 'ALL CORE RLS TESTS PASSED'
