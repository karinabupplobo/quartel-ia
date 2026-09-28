-- =============================================================================
-- Prefix every educational object with "e_".
-- The quartel-ia Supabase project hosts two demos side by side:
--   e_*  educational (this repo's Core module)
--   m_*  membership
-- Renames keep OIDs, so policies, triggers, grants and FKs stay attached.
-- SQL helper bodies reference tables by name, so they are rewritten below.
-- =============================================================================

-- Types
alter type public.app_role   rename to e_app_role;
alter type public.module_key rename to e_module_key;

-- Tables
alter table public.tenants        rename to e_tenants;
alter table public.tenant_modules rename to e_tenant_modules;
alter table public.people         rename to e_people;
alter table public.user_roles     rename to e_user_roles;
alter table public.guardianships  rename to e_guardianships;
alter table public.courses        rename to e_courses;

-- Named indexes
alter index public.user_roles_user_id_idx    rename to e_user_roles_user_id_idx;
alter index public.user_roles_person_id_idx  rename to e_user_roles_person_id_idx;
alter index public.people_tenant_id_idx      rename to e_people_tenant_id_idx;
alter index public.guardianships_student_idx rename to e_guardianships_student_idx;
alter index public.courses_tenant_id_idx     rename to e_courses_tenant_id_idx;

-- Triggers
alter trigger tenants_updated_at on public.e_tenants rename to e_tenants_updated_at;
alter trigger people_updated_at  on public.e_people  rename to e_people_updated_at;
alter trigger courses_updated_at on public.e_courses rename to e_courses_updated_at;

-- Helper functions: rename (keeps policies attached), then rewrite bodies.
alter function app.set_updated_at()                              rename to e_set_updated_at;
alter function app.is_member(uuid)                               rename to e_is_member;
alter function app.has_role(uuid, public.e_app_role[])           rename to e_has_role;
alter function app.module_enabled(uuid, public.e_module_key)     rename to e_module_enabled;
alter function app.can_see_person(uuid, uuid)                    rename to e_can_see_person;

create or replace function app.e_is_member(p_tenant uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.e_user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
  );
$$;

create or replace function app.e_has_role(p_tenant uuid, p_roles public.e_app_role[])
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.e_user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
      and ur.role = any (p_roles)
  );
$$;

create or replace function app.e_module_enabled(p_tenant uuid, p_module public.e_module_key)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.e_tenant_modules tm
    where tm.tenant_id = p_tenant
      and tm.module = p_module
      and tm.enabled
  );
$$;

create or replace function app.e_can_see_person(p_tenant uuid, p_person uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select
    app.e_has_role(p_tenant, array['admin', 'staff', 'teacher']::public.e_app_role[])
    or exists (
      select 1 from public.e_user_roles ur
      where ur.tenant_id = p_tenant
        and ur.user_id = (select auth.uid())
        and ur.person_id = p_person
    )
    or exists (
      select 1
      from public.e_user_roles ur
      join public.e_guardianships g
        on g.tenant_id = ur.tenant_id
       and g.guardian_person_id = ur.person_id
      where ur.tenant_id = p_tenant
        and ur.user_id = (select auth.uid())
        and ur.role = 'guardian'
        and g.student_person_id = p_person
    );
$$;

-- Policies
alter policy tenants_select         on public.e_tenants        rename to e_tenants_select;
alter policy tenants_update         on public.e_tenants        rename to e_tenants_update;
alter policy tenant_modules_select  on public.e_tenant_modules rename to e_tenant_modules_select;
alter policy people_select          on public.e_people         rename to e_people_select;
alter policy people_insert          on public.e_people         rename to e_people_insert;
alter policy people_update          on public.e_people         rename to e_people_update;
alter policy people_delete          on public.e_people         rename to e_people_delete;
alter policy user_roles_select      on public.e_user_roles     rename to e_user_roles_select;
alter policy user_roles_insert      on public.e_user_roles     rename to e_user_roles_insert;
alter policy user_roles_update      on public.e_user_roles     rename to e_user_roles_update;
alter policy user_roles_delete      on public.e_user_roles     rename to e_user_roles_delete;
alter policy guardianships_select   on public.e_guardianships  rename to e_guardianships_select;
alter policy guardianships_write    on public.e_guardianships  rename to e_guardianships_write;
alter policy courses_select         on public.e_courses        rename to e_courses_select;
alter policy courses_write          on public.e_courses        rename to e_courses_write;
