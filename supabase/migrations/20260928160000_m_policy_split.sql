-- =============================================================================
-- Membership: performance follow-up from the Supabase advisor.
--   * index for the m_people_private composite FK;
--   * split "for all" team write policies into insert/update/delete so they no
--     longer overlap the select policies (each overlap runs every policy).
-- Behavior is unchanged: same roles, same module gates.
-- =============================================================================

create index m_people_private_fk_idx on public.m_people_private (tenant_id, person_id);

do $$
declare
  r record;
  gate text;
  roles_cond text;
begin
  for r in
    select * from (values
      ('m_activities',           null,       '{admin,staff,attendant}'),
      ('m_icp_profiles',         'capture',  '{admin,staff}'),
      ('m_sources',              'capture',  '{admin,staff}'),
      ('m_pipeline_stages',      'capture',  '{admin,staff}'),
      ('m_leads',                'capture',  '{admin,staff,attendant}'),
      ('m_dunning_rules',        'billing',  '{admin,staff}'),
      ('m_health_scores',        'health',   '{admin,staff}'),
      ('m_playbooks',            'health',   '{admin,staff}'),
      ('m_health_alerts',        'health',   '{admin,staff,attendant}'),
      ('m_tasks',                'tasks',    '{admin,staff,attendant}'),
      ('m_channels',             'agent',    '{admin}'),
      ('m_agent_skills',         'agent',    '{admin}'),
      ('m_conversations',        'agent',    '{admin,staff,attendant}'),
      ('m_messages',             'agent',    '{admin,staff,attendant}'),
      ('m_knowledge_base',       'agent',    '{admin,staff}'),
      ('m_agent_actions',        'agent',    '{admin,staff,attendant}'),
      ('m_people_private',       null,       '{admin,staff}'),
      ('m_plans',                null,       '{admin,staff}'),
      ('m_benefits',             null,       '{admin,staff}'),
      ('m_plan_benefits',        null,       '{admin,staff}'),
      ('m_events',               'members',  '{admin,staff}'),
      ('m_event_plans',          'members',  '{admin,staff}'),
      ('m_event_registrations',  'members',  '{admin,staff,attendant}'),
      ('m_subscriptions',        'billing',  '{admin,staff}'),
      ('m_subscription_members', 'billing',  '{admin,staff}'),
      ('m_invoices',             'billing',  '{admin,staff}'),
      ('m_nps_responses',        'health',   '{admin,staff}')
    ) as spec(tbl, module, write_roles)
  loop
    gate := case when r.module is null then ''
                 else format(' and app.m_module_enabled(tenant_id, %L::public.m_module_key)', r.module) end;
    roles_cond := format('app.m_has_role(tenant_id, %L::public.m_app_role[])%s', r.write_roles, gate);

    execute format('drop policy %I on public.%I', r.tbl || '_team_write', r.tbl);
    execute format('create policy %I on public.%I for insert to authenticated with check (%s)',
                   r.tbl || '_team_insert', r.tbl, roles_cond);
    execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)',
                   r.tbl || '_team_update', r.tbl, roles_cond, roles_cond);
    execute format('create policy %I on public.%I for delete to authenticated using (%s)',
                   r.tbl || '_team_delete', r.tbl, roles_cond);
  end loop;
end $$;

-- Same split for role grants (admin only) and member event registrations.
drop policy m_user_roles_write on public.m_user_roles;
create policy m_user_roles_insert on public.m_user_roles for insert to authenticated
  with check (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]));
create policy m_user_roles_update on public.m_user_roles for update to authenticated
  using (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]))
  with check (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]));
create policy m_user_roles_delete on public.m_user_roles for delete to authenticated
  using (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]));

drop policy m_event_regs_self on public.m_event_registrations;
create policy m_event_regs_self_read on public.m_event_registrations for select to authenticated
  using (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members'));
create policy m_event_regs_self_insert on public.m_event_registrations for insert to authenticated
  with check (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members')
              and status = 'registered');
create policy m_event_regs_self_update on public.m_event_registrations for update to authenticated
  using (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members'))
  with check (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members')
              and status in ('registered', 'canceled'));
