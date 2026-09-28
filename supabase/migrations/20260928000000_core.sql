-- =============================================================================
-- Core module (always included)
-- Tenants, module entitlements, people, roles, guardianships, course catalog.
-- Every other module depends only on this one.
-- =============================================================================

create extension if not exists pgcrypto;

-- Private schema for helper functions. Not exposed through the Data API.
create schema if not exists app;

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.app_role as enum ('admin', 'staff', 'teacher', 'student', 'guardian');

create type public.module_key as enum (
  'capture',      -- 1. Lead capture & enrollment
  'finance',      -- 2. Billing
  'academic',     -- 3. Classes, attendance, grades
  'portal',       -- 4. Student / teacher portal
  'performance',  -- 5. Progress & churn risk (AI)
  'agent',        -- 6. WhatsApp agent
  'dashboard'     -- 7. Management dashboard
);

-- -----------------------------------------------------------------------------
-- Shared trigger: updated_at
-- -----------------------------------------------------------------------------
create or replace function app.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------
create table public.tenants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Which modules each school has bought. Written only by quartel.ia (service role).
create table public.tenant_modules (
  tenant_id     uuid not null references public.tenants(id) on delete cascade,
  module        public.module_key not null,
  enabled       boolean not null default true,
  activated_at  timestamptz not null default now(),
  primary key (tenant_id, module)
);

-- A person exists independently of having a login (leads, guardians, payers).
create table public.people (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id) on delete cascade,
  full_name   text not null check (length(trim(full_name)) > 0),
  email       text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone_e164  text check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  birth_date  date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- The WhatsApp agent resolves "who is talking" by phone, per school.
  unique (tenant_id, phone_e164),
  -- Target for composite FKs: guarantees references never cross tenants.
  unique (tenant_id, id)
);

create table public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  person_id   uuid not null,
  role        public.app_role not null,
  created_at  timestamptz not null default now(),
  unique (tenant_id, user_id, role),
  foreign key (tenant_id, person_id) references public.people(tenant_id, id) on delete cascade
);

create table public.guardianships (
  tenant_id           uuid not null references public.tenants(id) on delete cascade,
  guardian_person_id  uuid not null,
  student_person_id   uuid not null,
  created_at          timestamptz not null default now(),
  primary key (tenant_id, guardian_person_id, student_person_id),
  check (guardian_person_id <> student_person_id),
  -- Composite FKs: both people must belong to the same tenant as the row.
  foreign key (tenant_id, guardian_person_id) references public.people(tenant_id, id) on delete cascade,
  foreign key (tenant_id, student_person_id)  references public.people(tenant_id, id) on delete cascade
);

-- Course catalog lives in Core: capture, finance and academic all reference it,
-- and none of them may depend on each other.
create table public.courses (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  name         text not null,
  description  text,
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (tenant_id, name),
  unique (tenant_id, id)
);

-- -----------------------------------------------------------------------------
-- Indexes (every RLS policy hits user_roles by user_id)
-- -----------------------------------------------------------------------------
create index user_roles_user_id_idx      on public.user_roles (user_id);
create index user_roles_person_id_idx    on public.user_roles (tenant_id, person_id);
create index people_tenant_id_idx        on public.people (tenant_id);
create index guardianships_student_idx   on public.guardianships (tenant_id, student_person_id);
create index courses_tenant_id_idx       on public.courses (tenant_id);

create trigger tenants_updated_at before update on public.tenants
  for each row execute function app.set_updated_at();
create trigger people_updated_at before update on public.people
  for each row execute function app.set_updated_at();
create trigger courses_updated_at before update on public.courses
  for each row execute function app.set_updated_at();

-- -----------------------------------------------------------------------------
-- Helper functions
-- security definer: they read user_roles without triggering its own RLS
--   (otherwise user_roles policies calling these functions would recurse).
-- stable: same result within a statement, so Postgres can cache per query.
-- search_path = '': a caller cannot shadow public.user_roles with a fake table.
-- -----------------------------------------------------------------------------
create or replace function app.is_member(p_tenant uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
  );
$$;

create or replace function app.has_role(p_tenant uuid, p_roles public.app_role[])
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
      and ur.role = any (p_roles)
  );
$$;

-- Used by every non-core module's policies: no entitlement, no data.
create or replace function app.module_enabled(p_tenant uuid, p_module public.module_key)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenant_modules tm
    where tm.tenant_id = p_tenant
      and tm.module = p_module
      and tm.enabled
  );
$$;

-- People the current user may see: staff sees all; everyone sees themselves;
-- guardians see their wards.
create or replace function app.can_see_person(p_tenant uuid, p_person uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select
    app.has_role(p_tenant, array['admin', 'staff', 'teacher']::public.app_role[])
    or exists (
      select 1 from public.user_roles ur
      where ur.tenant_id = p_tenant
        and ur.user_id = (select auth.uid())
        and ur.person_id = p_person
    )
    or exists (
      select 1
      from public.user_roles ur
      join public.guardianships g
        on g.tenant_id = ur.tenant_id
       and g.guardian_person_id = ur.person_id
      where ur.tenant_id = p_tenant
        and ur.user_id = (select auth.uid())
        and ur.role = 'guardian'
        and g.student_person_id = p_person
    );
$$;

revoke all on schema app from public;
grant usage on schema app to authenticated;
revoke all on all functions in schema app from public;
grant execute on function
  app.is_member(uuid),
  app.has_role(uuid, public.app_role[]),
  app.module_enabled(uuid, public.module_key),
  app.can_see_person(uuid, uuid)
to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- No policy targets anon: the Core is never readable without a login.
-- -----------------------------------------------------------------------------
alter table public.tenants        enable row level security;
alter table public.tenant_modules enable row level security;
alter table public.people         enable row level security;
alter table public.user_roles     enable row level security;
alter table public.guardianships  enable row level security;
alter table public.courses        enable row level security;

-- tenants
create policy tenants_select on public.tenants
  for select to authenticated
  using (app.is_member(id));

create policy tenants_update on public.tenants
  for update to authenticated
  using (app.has_role(id, array['admin']::public.app_role[]))
  with check (app.has_role(id, array['admin']::public.app_role[]));

-- tenant_modules: read-only for members; writes via service role (billing).
create policy tenant_modules_select on public.tenant_modules
  for select to authenticated
  using (app.is_member(tenant_id));

-- people
create policy people_select on public.people
  for select to authenticated
  using (app.can_see_person(tenant_id, id));

create policy people_insert on public.people
  for insert to authenticated
  with check (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]));

create policy people_update on public.people
  for update to authenticated
  using (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]))
  with check (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]));

create policy people_delete on public.people
  for delete to authenticated
  using (app.has_role(tenant_id, array['admin']::public.app_role[]));

-- user_roles: only admins grant roles (staff cannot escalate themselves).
create policy user_roles_select on public.user_roles
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or app.has_role(tenant_id, array['admin', 'staff']::public.app_role[])
  );

create policy user_roles_insert on public.user_roles
  for insert to authenticated
  with check (app.has_role(tenant_id, array['admin']::public.app_role[]));

create policy user_roles_update on public.user_roles
  for update to authenticated
  using (app.has_role(tenant_id, array['admin']::public.app_role[]))
  with check (app.has_role(tenant_id, array['admin']::public.app_role[]));

create policy user_roles_delete on public.user_roles
  for delete to authenticated
  using (app.has_role(tenant_id, array['admin']::public.app_role[]));

-- guardianships
create policy guardianships_select on public.guardianships
  for select to authenticated
  using (
    app.has_role(tenant_id, array['admin', 'staff', 'teacher']::public.app_role[])
    or app.can_see_person(tenant_id, guardian_person_id)
       and app.can_see_person(tenant_id, student_person_id)
  );

create policy guardianships_write on public.guardianships
  for all to authenticated
  using (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]))
  with check (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]));

-- courses
create policy courses_select on public.courses
  for select to authenticated
  using (app.is_member(tenant_id));

create policy courses_write on public.courses
  for all to authenticated
  using (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]))
  with check (app.has_role(tenant_id, array['admin', 'staff']::public.app_role[]));
