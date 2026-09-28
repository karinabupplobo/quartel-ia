-- =============================================================================
-- Membership demo (m_*). Lives beside the educational demo (e_*) in the same
-- Supabase project. Generic subscription/membership business, Brazil (BRL,
-- Pix / boleto / card via Asaas). Screen map: Project doc membership/mapa-de-telas.md
--
-- Security model (same as e_*):
--   * every row carries tenant_id; isolation enforced by RLS;
--   * composite FKs (tenant_id, x_id) make cross-tenant references impossible;
--   * module tables are gated by m_tenant_modules;
--   * helpers are security definer in the private `app` schema.
-- Roles: admin, staff, attendant (team) and member (portal).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.m_app_role      as enum ('admin', 'staff', 'attendant', 'member');
create type public.m_module_key    as enum ('capture', 'members', 'billing', 'health', 'portal', 'dashboard', 'tasks', 'agent');
create type public.m_source_kind   as enum ('meta_ads', 'instagram', 'whatsapp', 'google_ads', 'referral', 'landing_page',
                                            'newsletter', 'rd_station', 'mailchimp', 'event', 'tiktok', 'webhook', 'manual');
create type public.m_source_status as enum ('active', 'paused', 'disconnected');
create type public.m_stage_kind    as enum ('open', 'won', 'lost');
create type public.m_icp_fit       as enum ('high', 'medium', 'low');
create type public.m_activity_kind as enum ('note', 'message', 'call', 'email', 'stage_change', 'system');
create type public.m_billing_cycle as enum ('monthly', 'quarterly', 'semiannual', 'annual');
create type public.m_benefit_kind  as enum ('access', 'discount', 'content', 'event');
create type public.m_sub_status    as enum ('active', 'paused', 'past_due', 'canceled');
create type public.m_invoice_status as enum ('pending', 'paid', 'overdue', 'canceled', 'refunded');
create type public.m_pay_method    as enum ('pix', 'boleto', 'credit_card');
create type public.m_channel_kind  as enum ('whatsapp', 'email', 'slack', 'tasks');
create type public.m_reg_status    as enum ('registered', 'canceled', 'attended');
create type public.m_health_level  as enum ('ok', 'attention', 'urgent');
create type public.m_lifecycle     as enum ('onboarding', 'adoption', 'renewal', 'retention');
create type public.m_alert_status  as enum ('open', 'in_progress', 'resolved', 'dismissed');
create type public.m_priority      as enum ('low', 'medium', 'high', 'urgent');
create type public.m_task_status   as enum ('todo', 'in_progress', 'done', 'canceled');
create type public.m_task_origin   as enum ('manual', 'agent', 'playbook');
create type public.m_agent_skill   as enum ('sales', 'billing', 'customer_success', 'support', 'manager_assistant');
create type public.m_conv_status   as enum ('ai_handling', 'needs_human', 'human_handling', 'closed');
create type public.m_msg_direction as enum ('inbound', 'outbound');
create type public.m_msg_sender    as enum ('person', 'agent', 'staff');
create type public.m_action_status as enum ('proposed', 'awaiting_confirmation', 'executed', 'rejected', 'failed');

create or replace function app.m_set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- =============================================================================
-- CORE
-- =============================================================================
create table public.m_tenants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  timezone    text not null default 'America/Sao_Paulo',
  currency    text not null default 'BRL' check (currency ~ '^[A-Z]{3}$'),
  logo_url    text,
  brand_color text check (brand_color is null or brand_color ~ '^#[0-9a-fA-F]{6}$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Written only by quartel.ia (service role).
create table public.m_tenant_modules (
  tenant_id     uuid not null references public.m_tenants(id) on delete cascade,
  module        public.m_module_key not null,
  enabled       boolean not null default true,
  activated_at  timestamptz not null default now(),
  primary key (tenant_id, module)
);

-- Anyone the business deals with: lead, member, dependent.
create table public.m_people (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  full_name   text not null check (length(trim(full_name)) > 0),
  email       text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone_e164  text check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  birth_date  date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (tenant_id, phone_e164),
  unique (tenant_id, id)
);

-- Sensitive identifiers kept apart so RLS can restrict them to admin/staff.
create table public.m_people_private (
  tenant_id   uuid not null,
  person_id   uuid primary key,
  cpf         text check (cpf is null or cpf ~ '^[0-9]{11}$'),
  updated_at  timestamptz not null default now(),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete cascade
);

create table public.m_user_roles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  person_id   uuid not null,
  role        public.m_app_role not null,
  created_at  timestamptz not null default now(),
  unique (tenant_id, user_id, role),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete cascade
);

-- Timeline shared by leads and members (notes, messages, stage changes).
create table public.m_activities (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  person_id   uuid not null,
  lead_id     uuid,
  kind        public.m_activity_kind not null,
  body        text,
  metadata    jsonb not null default '{}',
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete cascade
);

-- Catalog (ungated, like e_courses): plans and benefits are used by capture,
-- billing, members and the portal.
create table public.m_plans (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.m_tenants(id) on delete cascade,
  name           text not null,
  description    text,
  price_cents    integer not null check (price_cents >= 0),
  billing_cycle  public.m_billing_cycle not null default 'monthly',
  max_people     integer not null default 1 check (max_people >= 1),
  active         boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (tenant_id, name),
  unique (tenant_id, id)
);

create table public.m_benefits (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.m_tenants(id) on delete cascade,
  name         text not null,
  kind         public.m_benefit_kind not null,
  description  text,
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (tenant_id, name),
  unique (tenant_id, id)
);

create table public.m_plan_benefits (
  tenant_id   uuid not null,
  plan_id     uuid not null,
  benefit_id  uuid not null,
  primary key (tenant_id, plan_id, benefit_id),
  foreign key (tenant_id, plan_id)    references public.m_plans(tenant_id, id)    on delete cascade,
  foreign key (tenant_id, benefit_id) references public.m_benefits(tenant_id, id) on delete cascade
);

-- =============================================================================
-- CAPTURE
-- =============================================================================
create table public.m_icp_profiles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  answers     jsonb not null default '{}',   -- raw answers from the ICP assistant
  criteria    jsonb not null default '{}',   -- fit rules derived from the answers
  is_active   boolean not null default true,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index m_icp_profiles_one_active on public.m_icp_profiles (tenant_id) where is_active;

-- Connector config only; secrets (API tokens) belong in Supabase Vault, never here.
create table public.m_sources (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.m_tenants(id) on delete cascade,
  name          text not null,
  kind          public.m_source_kind not null,
  status        public.m_source_status not null default 'active',
  config        jsonb not null default '{}',
  monthly_cost_cents integer check (monthly_cost_cents is null or monthly_cost_cents >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, name),
  unique (tenant_id, id)
);

create table public.m_pipeline_stages (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  name        text not null,
  position    integer not null,
  kind        public.m_stage_kind not null default 'open',
  unique (tenant_id, position),
  unique (tenant_id, id)
);

create table public.m_leads (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.m_tenants(id) on delete cascade,
  person_id         uuid not null,
  stage_id          uuid not null,
  source_id         uuid,
  owner_user_id     uuid references auth.users(id) on delete set null,
  interest_plan_id  uuid,
  utm_source        text,
  utm_medium        text,
  utm_campaign      text,
  utm_content       text,
  utm_term          text,
  icp_fit           public.m_icp_fit,
  attention_points  jsonb not null default '[]',
  lost_reason       text,
  stage_changed_at  timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, person_id)        references public.m_people(tenant_id, id)          on delete cascade,
  foreign key (tenant_id, stage_id)         references public.m_pipeline_stages(tenant_id, id),
  foreign key (tenant_id, source_id)        references public.m_sources(tenant_id, id)         on delete set null (source_id),
  foreign key (tenant_id, interest_plan_id) references public.m_plans(tenant_id, id)           on delete set null (interest_plan_id)
);

alter table public.m_activities
  add foreign key (tenant_id, lead_id) references public.m_leads(tenant_id, id) on delete set null (lead_id);

-- =============================================================================
-- MEMBERS (benefits usage, events)
-- =============================================================================
create table public.m_events (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.m_tenants(id) on delete cascade,
  title        text not null,
  description  text,
  starts_at    timestamptz not null,
  ends_at      timestamptz,
  location     text,
  capacity     integer check (capacity is null or capacity > 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at),
  unique (tenant_id, id)
);

-- Plans eligible for an event (no rows = open to every plan).
create table public.m_event_plans (
  tenant_id  uuid not null,
  event_id   uuid not null,
  plan_id    uuid not null,
  primary key (tenant_id, event_id, plan_id),
  foreign key (tenant_id, event_id) references public.m_events(tenant_id, id) on delete cascade,
  foreign key (tenant_id, plan_id)  references public.m_plans(tenant_id, id)  on delete cascade
);

create table public.m_event_registrations (
  tenant_id      uuid not null,
  event_id       uuid not null,
  person_id      uuid not null,
  status         public.m_reg_status not null default 'registered',
  registered_at  timestamptz not null default now(),
  primary key (tenant_id, event_id, person_id),
  foreign key (tenant_id, event_id)  references public.m_events(tenant_id, id)  on delete cascade,
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id)  on delete cascade
);

-- =============================================================================
-- BILLING (lives in the dashboard: plans, subscriptions, invoices, dunning)
-- =============================================================================
create table public.m_subscriptions (
  id                        uuid primary key default gen_random_uuid(),
  tenant_id                 uuid not null references public.m_tenants(id) on delete cascade,
  holder_person_id          uuid not null,
  plan_id                   uuid not null,
  status                    public.m_sub_status not null default 'active',
  started_at                date not null default current_date,
  next_billing_date         date,
  paused_at                 timestamptz,
  canceled_at               timestamptz,
  cancel_reason             text,
  provider_subscription_id  text,   -- Asaas subscription id
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, holder_person_id) references public.m_people(tenant_id, id),
  foreign key (tenant_id, plan_id)          references public.m_plans(tenant_id, id)
);

-- Dependents covered by the holder's plan (holder is not listed here).
create table public.m_subscription_members (
  tenant_id        uuid not null,
  subscription_id  uuid not null,
  person_id        uuid not null,
  added_at         timestamptz not null default now(),
  primary key (tenant_id, subscription_id, person_id),
  foreign key (tenant_id, subscription_id) references public.m_subscriptions(tenant_id, id) on delete cascade,
  foreign key (tenant_id, person_id)       references public.m_people(tenant_id, id)        on delete cascade
);

create table public.m_invoices (
  id                   uuid primary key default gen_random_uuid(),
  tenant_id            uuid not null references public.m_tenants(id) on delete cascade,
  subscription_id      uuid not null,
  amount_cents         integer not null check (amount_cents >= 0),
  due_date             date not null,
  status               public.m_invoice_status not null default 'pending',
  method               public.m_pay_method,
  paid_at              timestamptz,
  provider_invoice_id  text,   -- Asaas payment id
  invoice_url          text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  check (status <> 'paid' or paid_at is not null),
  foreign key (tenant_id, subscription_id) references public.m_subscriptions(tenant_id, id) on delete cascade
);

-- Dunning: offset_days < 0 before due date, 0 on the day, > 0 after.
create table public.m_dunning_rules (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.m_tenants(id) on delete cascade,
  name         text not null,
  offset_days  integer not null,
  channel      public.m_channel_kind not null default 'whatsapp',
  template     text not null,
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (tenant_id, offset_days, channel)
);

-- =============================================================================
-- HEALTH (customer health + pre-retention)
-- =============================================================================
create table public.m_health_scores (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.m_tenants(id) on delete cascade,
  person_id      uuid not null,
  score          integer not null check (score between 0 and 100),
  level          public.m_health_level not null,
  dimensions     jsonb not null default '{}',   -- payment, engagement, relationship, lifecycle
  calculated_at  timestamptz not null default now(),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete cascade
);

create table public.m_playbooks (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.m_tenants(id) on delete cascade,
  name             text not null,
  lifecycle_phase  public.m_lifecycle not null,
  trigger_rule     jsonb not null default '{}',
  actions          jsonb not null default '[]',
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (tenant_id, name),
  unique (tenant_id, id)
);

create table public.m_health_alerts (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.m_tenants(id) on delete cascade,
  person_id    uuid not null,
  playbook_id  uuid,
  level        public.m_health_level not null,
  reason       text not null,
  status       public.m_alert_status not null default 'open',
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  resolved_by  uuid references auth.users(id) on delete set null,
  unique (tenant_id, id),
  foreign key (tenant_id, person_id)   references public.m_people(tenant_id, id)    on delete cascade,
  foreign key (tenant_id, playbook_id) references public.m_playbooks(tenant_id, id) on delete set null (playbook_id)
);

create table public.m_nps_responses (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  person_id   uuid not null,
  score       integer not null check (score between 0 and 10),
  comment     text,
  created_at  timestamptz not null default now(),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete cascade
);

-- =============================================================================
-- TASKS (cross-cutting)
-- =============================================================================
create table public.m_tasks (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.m_tenants(id) on delete cascade,
  title             text not null check (length(trim(title)) > 0),
  description       text,
  person_id         uuid,
  lead_id           uuid,
  subscription_id   uuid,
  health_alert_id   uuid,
  assignee_user_id  uuid references auth.users(id) on delete set null,
  due_date          date,
  priority          public.m_priority not null default 'medium',
  status            public.m_task_status not null default 'todo',
  origin            public.m_task_origin not null default 'manual',
  created_by        uuid references auth.users(id) on delete set null,
  completed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  foreign key (tenant_id, person_id)       references public.m_people(tenant_id, id)        on delete cascade,
  foreign key (tenant_id, lead_id)         references public.m_leads(tenant_id, id)         on delete set null (lead_id),
  foreign key (tenant_id, subscription_id) references public.m_subscriptions(tenant_id, id) on delete set null (subscription_id),
  foreign key (tenant_id, health_alert_id) references public.m_health_alerts(tenant_id, id) on delete set null (health_alert_id)
);

-- =============================================================================
-- AGENT
-- =============================================================================
create table public.m_channels (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  kind        public.m_channel_kind not null,
  enabled     boolean not null default false,
  config      jsonb not null default '{}',   -- no secrets: tokens go in Supabase Vault
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (tenant_id, kind)
);

create table public.m_agent_skills (
  tenant_id  uuid not null references public.m_tenants(id) on delete cascade,
  skill      public.m_agent_skill not null,
  enabled    boolean not null default false,
  settings   jsonb not null default '{}',
  primary key (tenant_id, skill)
);

create table public.m_conversations (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.m_tenants(id) on delete cascade,
  channel           public.m_channel_kind not null,
  person_id         uuid,
  external_id       text,
  status            public.m_conv_status not null default 'ai_handling',
  assigned_user_id  uuid references auth.users(id) on delete set null,
  last_message_at   timestamptz,
  created_at        timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, channel, external_id),
  foreign key (tenant_id, person_id) references public.m_people(tenant_id, id) on delete set null (person_id)
);

create table public.m_messages (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null,
  conversation_id  uuid not null,
  direction        public.m_msg_direction not null,
  sender           public.m_msg_sender not null,
  body             text,
  metadata         jsonb not null default '{}',
  created_at       timestamptz not null default now(),
  foreign key (tenant_id, conversation_id) references public.m_conversations(tenant_id, id) on delete cascade
);

create table public.m_knowledge_base (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.m_tenants(id) on delete cascade,
  title       text not null,
  content     text not null,
  category    text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Audit log of everything the agent did or proposed.
create table public.m_agent_actions (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.m_tenants(id) on delete cascade,
  skill         public.m_agent_skill not null,
  channel       public.m_channel_kind,
  action        text not null,
  target        jsonb not null default '{}',
  status        public.m_action_status not null default 'proposed',
  requested_by  uuid references auth.users(id) on delete set null,
  confirmed_by  uuid references auth.users(id) on delete set null,
  result        jsonb,
  created_at    timestamptz not null default now(),
  executed_at   timestamptz
);

-- =============================================================================
-- Indexes (RLS helpers hit m_user_roles by user_id; FKs used for filters)
-- =============================================================================
create index m_user_roles_user_id_idx          on public.m_user_roles (user_id);
create index m_user_roles_person_idx           on public.m_user_roles (tenant_id, person_id);
create index m_people_tenant_idx               on public.m_people (tenant_id);
create index m_activities_person_idx           on public.m_activities (tenant_id, person_id, created_at desc);
create index m_activities_lead_idx             on public.m_activities (tenant_id, lead_id);
create index m_activities_created_by_idx       on public.m_activities (created_by);
create index m_plan_benefits_benefit_idx       on public.m_plan_benefits (tenant_id, benefit_id);
create index m_icp_profiles_created_by_idx     on public.m_icp_profiles (created_by);
create index m_leads_stage_idx                 on public.m_leads (tenant_id, stage_id);
create index m_leads_person_idx                on public.m_leads (tenant_id, person_id);
create index m_leads_source_idx                on public.m_leads (tenant_id, source_id);
create index m_leads_plan_idx                  on public.m_leads (tenant_id, interest_plan_id);
create index m_leads_owner_idx                 on public.m_leads (owner_user_id);
create index m_event_plans_plan_idx            on public.m_event_plans (tenant_id, plan_id);
create index m_event_regs_person_idx           on public.m_event_registrations (tenant_id, person_id);
create index m_subscriptions_holder_idx        on public.m_subscriptions (tenant_id, holder_person_id);
create index m_subscriptions_plan_idx          on public.m_subscriptions (tenant_id, plan_id);
create index m_sub_members_person_idx          on public.m_subscription_members (tenant_id, person_id);
create index m_invoices_sub_idx                on public.m_invoices (tenant_id, subscription_id);
create index m_invoices_status_due_idx         on public.m_invoices (tenant_id, status, due_date);
create index m_health_scores_person_idx        on public.m_health_scores (tenant_id, person_id, calculated_at desc);
create index m_health_alerts_person_idx        on public.m_health_alerts (tenant_id, person_id);
create index m_health_alerts_playbook_idx      on public.m_health_alerts (tenant_id, playbook_id);
create index m_health_alerts_resolved_by_idx   on public.m_health_alerts (resolved_by);
create index m_nps_person_idx                  on public.m_nps_responses (tenant_id, person_id);
create index m_tasks_person_idx                on public.m_tasks (tenant_id, person_id);
create index m_tasks_lead_idx                  on public.m_tasks (tenant_id, lead_id);
create index m_tasks_sub_idx                   on public.m_tasks (tenant_id, subscription_id);
create index m_tasks_alert_idx                 on public.m_tasks (tenant_id, health_alert_id);
create index m_tasks_assignee_idx              on public.m_tasks (assignee_user_id);
create index m_tasks_created_by_idx            on public.m_tasks (created_by);
create index m_tasks_status_due_idx            on public.m_tasks (tenant_id, status, due_date);
create index m_conversations_person_idx        on public.m_conversations (tenant_id, person_id);
create index m_conversations_assigned_idx      on public.m_conversations (assigned_user_id);
create index m_messages_conv_idx               on public.m_messages (tenant_id, conversation_id, created_at);
create index m_knowledge_base_tenant_idx       on public.m_knowledge_base (tenant_id);
create index m_agent_actions_tenant_idx        on public.m_agent_actions (tenant_id, created_at desc);
create index m_agent_actions_requested_by_idx  on public.m_agent_actions (requested_by);
create index m_agent_actions_confirmed_by_idx  on public.m_agent_actions (confirmed_by);

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'm_tenants','m_people','m_people_private','m_plans','m_benefits','m_icp_profiles','m_sources',
    'm_leads','m_events','m_subscriptions','m_invoices','m_dunning_rules','m_playbooks','m_tasks',
    'm_channels','m_knowledge_base'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function app.m_set_updated_at()',
      t || '_updated_at', t);
  end loop;
end $$;

-- =============================================================================
-- Helper functions
-- =============================================================================
create or replace function app.m_has_role(p_tenant uuid, p_roles public.m_app_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.m_user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
      and ur.role = any (p_roles)
  );
$$;

create or replace function app.m_is_member(p_tenant uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.m_user_roles ur
    where ur.tenant_id = p_tenant and ur.user_id = (select auth.uid())
  );
$$;

create or replace function app.m_module_enabled(p_tenant uuid, p_module public.m_module_key)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.m_tenant_modules tm
    where tm.tenant_id = p_tenant and tm.module = p_module and tm.enabled
  );
$$;

-- People records linked to the current login in this tenant.
create or replace function app.m_is_self(p_tenant uuid, p_person uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.m_user_roles ur
    where ur.tenant_id = p_tenant
      and ur.user_id = (select auth.uid())
      and ur.person_id = p_person
  );
$$;

-- Current login is the holder of the subscription.
create or replace function app.m_is_holder(p_tenant uuid, p_subscription uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.m_subscriptions s
    join public.m_user_roles ur
      on ur.tenant_id = s.tenant_id and ur.person_id = s.holder_person_id
    where s.tenant_id = p_tenant and s.id = p_subscription
      and ur.user_id = (select auth.uid())
  );
$$;

-- Current login is holder or dependent of the subscription.
create or replace function app.m_is_sub_party(p_tenant uuid, p_subscription uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app.m_is_holder(p_tenant, p_subscription)
      or exists (
        select 1
        from public.m_subscription_members sm
        join public.m_user_roles ur
          on ur.tenant_id = sm.tenant_id and ur.person_id = sm.person_id
        where sm.tenant_id = p_tenant and sm.subscription_id = p_subscription
          and ur.user_id = (select auth.uid())
      );
$$;

-- Portal visibility of people: self, plus dependents of subscriptions I hold.
create or replace function app.m_can_see_person(p_tenant uuid, p_person uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app.m_has_role(p_tenant, array['admin', 'staff', 'attendant']::public.m_app_role[])
      or app.m_is_self(p_tenant, p_person)
      or exists (
        select 1
        from public.m_subscription_members sm
        where sm.tenant_id = p_tenant and sm.person_id = p_person
          and app.m_is_holder(p_tenant, sm.subscription_id)
      );
$$;

revoke all on all functions in schema app from public;
grant execute on function
  app.m_has_role(uuid, public.m_app_role[]),
  app.m_is_member(uuid),
  app.m_module_enabled(uuid, public.m_module_key),
  app.m_is_self(uuid, uuid),
  app.m_is_holder(uuid, uuid),
  app.m_is_sub_party(uuid, uuid),
  app.m_can_see_person(uuid, uuid)
to authenticated;

-- Plan capacity: holder + dependents may not exceed plan.max_people,
-- and the holder is never listed as their own dependent.
create or replace function app.m_check_subscription_capacity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_max     integer;
  v_holder  uuid;
  v_count   integer;
begin
  select p.max_people, s.holder_person_id into v_max, v_holder
  from public.m_subscriptions s
  join public.m_plans p on p.tenant_id = s.tenant_id and p.id = s.plan_id
  where s.tenant_id = new.tenant_id and s.id = new.subscription_id;

  if new.person_id = v_holder then
    raise exception 'holder cannot be added as a dependent' using errcode = 'check_violation';
  end if;

  select count(*) into v_count
  from public.m_subscription_members
  where tenant_id = new.tenant_id and subscription_id = new.subscription_id
    and person_id <> new.person_id;

  if 1 + v_count + 1 > v_max then
    raise exception 'plan allows at most % people (holder included)', v_max using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
revoke all on function app.m_check_subscription_capacity() from public;

create trigger m_subscription_members_capacity
  before insert or update on public.m_subscription_members
  for each row execute function app.m_check_subscription_capacity();

-- =============================================================================
-- Row Level Security
-- No policy targets anon: nothing is readable without a login.
-- =============================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'm_tenants','m_tenant_modules','m_people','m_people_private','m_user_roles','m_activities',
    'm_plans','m_benefits','m_plan_benefits','m_icp_profiles','m_sources','m_pipeline_stages',
    'm_leads','m_events','m_event_plans','m_event_registrations','m_subscriptions',
    'm_subscription_members','m_invoices','m_dunning_rules','m_health_scores','m_playbooks',
    'm_health_alerts','m_nps_responses','m_tasks','m_channels','m_agent_skills',
    'm_conversations','m_messages','m_knowledge_base','m_agent_actions'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Team tables: one read policy + one write policy each, generated from a spec.
--   read/write: role lists; module: gate (null = ungated).
do $$
declare
  r record;
  gate text;
begin
  for r in
    select * from (values
      -- table                    module       read roles                        write roles
      ('m_activities',           null,        '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_icp_profiles',         'capture',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_sources',              'capture',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_pipeline_stages',      'capture',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_leads',                'capture',   '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_dunning_rules',        'billing',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_health_scores',        'health',    '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_playbooks',            'health',    '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_health_alerts',        'health',    '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_tasks',                'tasks',     '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_channels',             'agent',     '{admin,staff,attendant}',         '{admin}'),
      ('m_agent_skills',         'agent',     '{admin,staff,attendant}',         '{admin}'),
      ('m_conversations',        'agent',     '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_messages',             'agent',     '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_knowledge_base',       'agent',     '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_agent_actions',        'agent',     '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_people_private',       null,        '{admin,staff}',                   '{admin,staff}'),
      -- tables that also have portal (member) read policies below
      ('m_plans',                null,        '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_benefits',             null,        '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_plan_benefits',        null,        '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_events',               'members',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_event_plans',          'members',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_event_registrations',  'members',   '{admin,staff,attendant}',         '{admin,staff,attendant}'),
      ('m_subscriptions',        'billing',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_subscription_members', 'billing',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_invoices',             'billing',   '{admin,staff,attendant}',         '{admin,staff}'),
      ('m_nps_responses',        'health',    '{admin,staff,attendant}',         '{admin,staff}')
    ) as spec(tbl, module, read_roles, write_roles)
  loop
    gate := case when r.module is null then ''
                 else format(' and app.m_module_enabled(tenant_id, %L::public.m_module_key)', r.module) end;
    execute format(
      'create policy %I on public.%I for select to authenticated using (app.m_has_role(tenant_id, %L::public.m_app_role[])%s)',
      r.tbl || '_team_read', r.tbl, r.read_roles, gate);
    execute format(
      'create policy %I on public.%I for all to authenticated using (app.m_has_role(tenant_id, %L::public.m_app_role[])%s) with check (app.m_has_role(tenant_id, %L::public.m_app_role[])%s)',
      r.tbl || '_team_write', r.tbl, r.write_roles, gate, r.write_roles, gate);
  end loop;
end $$;

-- ---- Core ------------------------------------------------------------------
create policy m_tenants_select on public.m_tenants
  for select to authenticated using (app.m_is_member(id));
create policy m_tenants_update on public.m_tenants
  for update to authenticated
  using (app.m_has_role(id, array['admin']::public.m_app_role[]))
  with check (app.m_has_role(id, array['admin']::public.m_app_role[]));

-- Read-only for members; written by quartel.ia via service role.
create policy m_tenant_modules_select on public.m_tenant_modules
  for select to authenticated using (app.m_is_member(tenant_id));

create policy m_people_select on public.m_people
  for select to authenticated using (app.m_can_see_person(tenant_id, id));
create policy m_people_insert on public.m_people
  for insert to authenticated
  with check (app.m_has_role(tenant_id, array['admin', 'staff', 'attendant']::public.m_app_role[]));
create policy m_people_update on public.m_people
  for update to authenticated
  using (app.m_has_role(tenant_id, array['admin', 'staff', 'attendant']::public.m_app_role[]))
  with check (app.m_has_role(tenant_id, array['admin', 'staff', 'attendant']::public.m_app_role[]));
create policy m_people_delete on public.m_people
  for delete to authenticated
  using (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]));

-- Only admins grant roles (no self-escalation).
create policy m_user_roles_select on public.m_user_roles
  for select to authenticated
  using (user_id = (select auth.uid())
         or app.m_has_role(tenant_id, array['admin', 'staff']::public.m_app_role[]));
create policy m_user_roles_write on public.m_user_roles
  for all to authenticated
  using (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]))
  with check (app.m_has_role(tenant_id, array['admin']::public.m_app_role[]));

-- ---- Portal (member) reads ---------------------------------------------------
create policy m_plans_portal_read on public.m_plans
  for select to authenticated using (active and app.m_is_member(tenant_id));
create policy m_benefits_portal_read on public.m_benefits
  for select to authenticated using (active and app.m_is_member(tenant_id));
create policy m_plan_benefits_portal_read on public.m_plan_benefits
  for select to authenticated using (app.m_is_member(tenant_id));

create policy m_events_portal_read on public.m_events
  for select to authenticated
  using (app.m_is_member(tenant_id) and app.m_module_enabled(tenant_id, 'members'));
create policy m_event_plans_portal_read on public.m_event_plans
  for select to authenticated
  using (app.m_is_member(tenant_id) and app.m_module_enabled(tenant_id, 'members'));

-- Members register / cancel themselves for events.
create policy m_event_regs_self on public.m_event_registrations
  for all to authenticated
  using (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members'))
  with check (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'members')
              and status in ('registered', 'canceled'));

create policy m_subscriptions_portal_read on public.m_subscriptions
  for select to authenticated
  using (app.m_is_sub_party(tenant_id, id) and app.m_module_enabled(tenant_id, 'billing'));
create policy m_sub_members_portal_read on public.m_subscription_members
  for select to authenticated
  using (app.m_is_sub_party(tenant_id, subscription_id) and app.m_module_enabled(tenant_id, 'billing'));
-- Only the holder (the payer) sees invoices.
create policy m_invoices_portal_read on public.m_invoices
  for select to authenticated
  using (app.m_is_holder(tenant_id, subscription_id) and app.m_module_enabled(tenant_id, 'billing'));

-- Members answer NPS about themselves and see their own answers.
create policy m_nps_self_read on public.m_nps_responses
  for select to authenticated
  using (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'health'));
create policy m_nps_self_insert on public.m_nps_responses
  for insert to authenticated
  with check (app.m_is_self(tenant_id, person_id) and app.m_module_enabled(tenant_id, 'health'));
