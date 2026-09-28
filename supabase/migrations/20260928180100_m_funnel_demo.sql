-- =============================================================================
-- Funnel screen support (membership demo).
-- Schema:
--   * m_tenants.monthly_close_goal: the "Fechado/Objetivo" target, editable
--     by the manager;
--   * m_leads.ai_priority (0-100) orders the lead list; source_note keeps the
--     human-readable origin detail ("Indicada por Fernanda Lima");
--   * m_ai_insights: the assistant's comments. For the demo they are stored,
--     not generated live. scope = 'lead' (one lead), 'stage' (one funnel
--     stage) or 'pipeline' (the whole funnel).
-- Data (Clube Aurora only): stage names from the approved design, the leads
-- shown in the design, their history, tasks and assistant comments.
-- =============================================================================

-- ---- Schema -------------------------------------------------------------------
alter table public.m_tenants
  add column monthly_close_goal integer check (monthly_close_goal is null or monthly_close_goal > 0);

alter table public.m_leads
  add column ai_priority smallint check (ai_priority is null or ai_priority between 0 and 100),
  add column source_note text;

create index m_leads_priority_idx on public.m_leads (tenant_id, stage_id, ai_priority desc);

create table public.m_ai_insights (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.m_tenants(id) on delete cascade,
  scope         text not null check (scope in ('lead', 'stage', 'pipeline')),
  lead_id       uuid,
  stage_id      uuid,
  body          text not null check (length(trim(body)) > 0),
  action_label  text,
  created_at    timestamptz not null default now(),
  check ((scope = 'lead') = (lead_id is not null)),
  check ((scope = 'stage') = (stage_id is not null)),
  foreign key (tenant_id, lead_id)  references public.m_leads(tenant_id, id)           on delete cascade,
  foreign key (tenant_id, stage_id) references public.m_pipeline_stages(tenant_id, id) on delete cascade
);
create index m_ai_insights_lead_idx  on public.m_ai_insights (tenant_id, lead_id);
create index m_ai_insights_stage_idx on public.m_ai_insights (tenant_id, stage_id);

alter table public.m_ai_insights enable row level security;
create policy m_ai_insights_team_read on public.m_ai_insights for select to authenticated
  using (app.m_has_role(tenant_id, '{admin,staff,attendant}'::public.m_app_role[]) and app.m_module_enabled(tenant_id, 'capture'));
create policy m_ai_insights_team_insert on public.m_ai_insights for insert to authenticated
  with check (app.m_has_role(tenant_id, '{admin,staff}'::public.m_app_role[]) and app.m_module_enabled(tenant_id, 'capture'));
create policy m_ai_insights_team_update on public.m_ai_insights for update to authenticated
  using (app.m_has_role(tenant_id, '{admin,staff}'::public.m_app_role[]) and app.m_module_enabled(tenant_id, 'capture'))
  with check (app.m_has_role(tenant_id, '{admin,staff}'::public.m_app_role[]) and app.m_module_enabled(tenant_id, 'capture'));
create policy m_ai_insights_team_delete on public.m_ai_insights for delete to authenticated
  using (app.m_has_role(tenant_id, '{admin,staff}'::public.m_app_role[]) and app.m_module_enabled(tenant_id, 'capture'));

-- ---- Clube Aurora data ------------------------------------------------------------
update public.m_tenants set monthly_close_goal = 10
where id = 'f1000000-0000-4000-8000-000000000001';

update public.m_pipeline_stages set name = case id
    when 'f5000000-0000-4000-8000-000000000001' then 'Lead'
    when 'f5000000-0000-4000-8000-000000000003' then 'Reunião'
    when 'f5000000-0000-4000-8000-000000000004' then 'Negociação'
    else name end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

-- New people from the design
insert into public.m_people (id, tenant_id, full_name, email, phone_e164) values
  ('f2000000-0000-4000-8000-000000000058', 'f1000000-0000-4000-8000-000000000001', 'Mariana Duarte',  'mariana.duarte@example.com',  '+5511900010058'),
  ('f2000000-0000-4000-8000-000000000059', 'f1000000-0000-4000-8000-000000000001', 'Thiago Barros',   'thiago.barros@example.com',   '+5511900010059'),
  ('f2000000-0000-4000-8000-000000000060', 'f1000000-0000-4000-8000-000000000001', 'Paula Mendes',    'paula.mendes@example.com',    '+5511900010060'),
  ('f2000000-0000-4000-8000-000000000061', 'f1000000-0000-4000-8000-000000000001', 'Rafael Souza',    'rafael.souza@example.com',    '+5511900010061'),
  ('f2000000-0000-4000-8000-000000000062', 'f1000000-0000-4000-8000-000000000001', 'Gabriela Rios',   'gabriela.rios@example.com',   '+5511900010062'),
  ('f2000000-0000-4000-8000-000000000063', 'f1000000-0000-4000-8000-000000000001', 'Sérgio Lopes',    'sergio.lopes@example.com',    '+5511900010063'),
  ('f2000000-0000-4000-8000-000000000064', 'f1000000-0000-4000-8000-000000000001', 'Natália Campos',  'natalia.campos@example.com',  '+5511900010064');

-- Sérgio and Natália closed this month, so they are members too.
insert into public.m_subscriptions (id, tenant_id, holder_person_id, plan_id, status, started_at, next_billing_date) values
  ('f4000000-0000-4000-8000-000000000022', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000063', 'f3000000-0000-4000-8000-000000000002', 'active', current_date - 9,  current_date + 21),
  ('f4000000-0000-4000-8000-000000000023', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000064', 'f3000000-0000-4000-8000-000000000004', 'active', current_date - 21, current_date + 344);
insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date, status, method, paid_at) values
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000022', 25900,  current_date - 9,  'paid', 'pix',         (current_date - 9)::timestamptz),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000023', 149000, current_date - 21, 'paid', 'credit_card', (current_date - 21)::timestamptz);

-- New leads (open ones and the ones closed this month)
insert into public.m_leads (id, tenant_id, person_id, stage_id, source_id, interest_plan_id, utm_source, utm_medium, utm_campaign, icp_fit, stage_changed_at, created_at) values
  ('f9000000-0000-4000-8000-000000000009', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000058', 'f5000000-0000-4000-8000-000000000001', 'f6000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000003', 'instagram',  'paid_social', 'primavera-familia',    'high',   now() - interval '1 day',   now() - interval '1 day'),
  ('f9000000-0000-4000-8000-000000000010', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000059', 'f5000000-0000-4000-8000-000000000001', 'f6000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000001', 'newsletter', 'email',       'setembro',             'medium', now() - interval '4 days',  now() - interval '4 days'),
  ('f9000000-0000-4000-8000-000000000011', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000060', 'f5000000-0000-4000-8000-000000000001', 'f6000000-0000-4000-8000-000000000006', 'f3000000-0000-4000-8000-000000000001', null,         null,          null,                   'low',    now() - interval '3 days',  now() - interval '3 days'),
  ('f9000000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000061', 'f5000000-0000-4000-8000-000000000003', 'f6000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000001', 'google',     'cpc',         'clube-perto-de-mim',   'medium', now() - interval '1 day',   now() - interval '5 days'),
  ('f9000000-0000-4000-8000-000000000013', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000062', 'f5000000-0000-4000-8000-000000000004', 'f6000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000003', null,         null,          null,                   'high',   now() - interval '2 days',  now() - interval '9 days'),
  ('f9000000-0000-4000-8000-000000000014', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000063', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000002', 'f3000000-0000-4000-8000-000000000002', null,         null,          null,                   'high',   now() - interval '9 days',  now() - interval '15 days'),
  ('f9000000-0000-4000-8000-000000000015', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000064', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000004', 'newsletter', 'email',       'agosto',               'high',   now() - interval '21 days', now() - interval '29 days'),
  ('f9000000-0000-4000-8000-000000000016', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000021', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000003', null,         null,          null,                   'high',   now() - interval '5 days',  now() - interval '11 days'),
  ('f9000000-0000-4000-8000-000000000017', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000012', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'instagram',  'paid_social', 'primavera-individual', 'high',   now() - interval '18 days', now() - interval '24 days'),
  ('f9000000-0000-4000-8000-000000000018', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000016', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000001', 'google',     'cpc',         'clube-perto-de-mim',   'medium', now() - interval '25 days', now() - interval '30 days');

-- Priority, origin detail and dates for every Aurora lead
update public.m_leads l set
  ai_priority = v.prio,
  source_note = v.note
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, 92, null),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 61, null),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 78, null),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 22, null),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 88, 'Indicada por Fernanda Lima'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 74, null),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 80, null),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 15, null),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 84, null),
  ('f9000000-0000-4000-8000-000000000010'::uuid, 44, null),
  ('f9000000-0000-4000-8000-000000000011'::uuid, 31, 'Formulário do site'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 66, null),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 90, 'Indicada por Ricardo Alves'),
  ('f9000000-0000-4000-8000-000000000014'::uuid, 65, null),
  ('f9000000-0000-4000-8000-000000000015'::uuid, 62, null),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 86, 'Indicado por Aline Rocha'),
  ('f9000000-0000-4000-8000-000000000017'::uuid, 70, null),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 78, null)
) as v(id, prio, note)
where l.id = v.id;

update public.m_leads set created_at = now() - interval '1 day'
where id = 'f9000000-0000-4000-8000-000000000001';

-- Tasks: align titles with the design and add the new ones
update public.m_tasks set title = 'Confirmar reunião de sábado'
where tenant_id = 'f1000000-0000-4000-8000-000000000001' and lead_id = 'f9000000-0000-4000-8000-000000000005';
update public.m_tasks set title = 'Responder sobre eventos infantis'
where tenant_id = 'f1000000-0000-4000-8000-000000000001' and lead_id = 'f9000000-0000-4000-8000-000000000001';
update public.m_tasks set title = 'Follow-up da proposta'
where tenant_id = 'f1000000-0000-4000-8000-000000000001' and lead_id = 'f9000000-0000-4000-8000-000000000006';

insert into public.m_tasks (tenant_id, title, person_id, lead_id, due_date, priority, status, origin) values
  ('f1000000-0000-4000-8000-000000000001', 'Enviar contrato',          'f2000000-0000-4000-8000-000000000062', 'f9000000-0000-4000-8000-000000000013', current_date,     'high',   'todo', 'agent'),
  ('f1000000-0000-4000-8000-000000000001', 'Reunião de apresentação',  'f2000000-0000-4000-8000-000000000061', 'f9000000-0000-4000-8000-000000000012', current_date + 3, 'medium', 'todo', 'manual');

-- Lead history: replace the earlier sample timeline with the design's
delete from public.m_activities where tenant_id = 'f1000000-0000-4000-8000-000000000001';

insert into public.m_activities (tenant_id, person_id, lead_id, kind, body, metadata, created_at)
select 'f1000000-0000-4000-8000-000000000001', l.person_id, l.id, v.kind::public.m_activity_kind, v.body,
       jsonb_build_object('title', v.title), now() - v.ago
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'message',      'WhatsApp',                  'Perguntou se o clube tem atividades para crianças.',                         interval '1 day'),
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'system',       'Lead criado',               'Entrou pelo anúncio do Instagram, campanha primavera-familia.',              interval '1 day 2 minutes'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'note',         'Visitou a página de planos','3ª visita esta semana, ficou 4 min no plano Família.',                        interval '3 hours'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'system',       'Lead criado',               'Formulário do anúncio primavera-familia.',                                   interval '1 day'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'email',        'E-mail',                    'Recebeu a apresentação do clube. Abriu, não respondeu.',                     interval '2 days'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'system',       'Lead criado',               'Formulário do Google Ads, busca clube-perto-de-mim.',                        interval '2 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000010'::uuid, 'email',        'E-mail',                    'Abriu a newsletter de setembro.',                                            interval '3 days'),
  ('f9000000-0000-4000-8000-000000000010'::uuid, 'system',       'Lead criado',               'Clicou no link de planos da newsletter.',                                    interval '4 days'),
  ('f9000000-0000-4000-8000-000000000011'::uuid, 'message',      'WhatsApp',                  'Pediu só a tabela de preços.',                                               interval '3 days'),
  ('f9000000-0000-4000-8000-000000000011'::uuid, 'system',       'Lead criado',               'Formulário da landing page Primavera.',                                      interval '3 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'stage_change', 'Movida para Qualificado',   'Respondeu às perguntas de qualificação.',                                    interval '3 days'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'message',      'WhatsApp',                  'Perguntou horários de eventos para casais.',                                 interval '4 days'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'system',       'Lead criado',               'Chamou direto no WhatsApp.',                                                 interval '4 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'message',      'WhatsApp',                  'Pediu desconto pela segunda vez.',                                           interval '5 days'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'message',      'WhatsApp',                  'Perguntou se havia desconto no plano Individual.',                           interval '6 days'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'system',       'Lead criado',               'Anúncio do Instagram primavera-individual.',                                 interval '7 days'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'meeting',      'Reunião agendada',          'Sábado às 10h, visita guiada ao espaço.',                                    interval '2 days'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'system',       'Lead criado',               'Indicação da membro Fernanda Lima.',                                         interval '3 days'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'meeting',      'Reunião agendada',          'Quinta às 10h, apresentação online.',                                        interval '1 day'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'system',       'Lead criado',               'Formulário do Google Ads.',                                                  interval '5 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'meeting',      'Reunião',                   'Gostou muito do piquenique das famílias. Quer incluir marido e 2 filhos.',   interval '2 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'stage_change', 'Movida para Negociação',    'Pediu proposta do plano Família.',                                           interval '2 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'system',       'Lead criado',               'Indicação do membro Ricardo Alves.',                                         interval '9 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'email',        'E-mail',                    'Proposta do plano Individual Anual enviada.',                                interval '5 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'meeting',      'Reunião',                   'Disse que o anual cabe no orçamento se parcelar.',                           interval '6 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'system',       'Lead criado',               'Clicou na newsletter de setembro.',                                          interval '12 days'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'stage_change', 'Fechado',                   'Assinou o plano Família com 3 dependentes.',                                 interval '5 days'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'system',       'Lead criado',               'Indicação da membro Aline Rocha.',                                           interval '11 days'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'stage_change', 'Fechado',                   'Assinou o plano Individual, pagou por Pix.',                                 interval '18 days'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'system',       'Lead criado',               'Anúncio do Instagram primavera-individual.',                                 interval '25 days'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'stage_change', 'Fechado',                   'Assinou o plano Individual por boleto.',                                     interval '25 days'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'system',       'Lead criado',               'Formulário do Google Ads.',                                                  interval '30 days'),
  ('f9000000-0000-4000-8000-000000000017'::uuid, 'stage_change', 'Fechado',                   'Assinou o plano Individual no cartão.',                                      interval '18 days'),
  ('f9000000-0000-4000-8000-000000000017'::uuid, 'system',       'Lead criado',               'Anúncio do Instagram primavera-individual.',                                 interval '24 days'),
  ('f9000000-0000-4000-8000-000000000014'::uuid, 'stage_change', 'Fechado',                   'Assinou o plano Casal por Pix.',                                             interval '9 days'),
  ('f9000000-0000-4000-8000-000000000014'::uuid, 'system',       'Lead criado',               'Chamou direto no WhatsApp.',                                                 interval '15 days'),
  ('f9000000-0000-4000-8000-000000000015'::uuid, 'stage_change', 'Fechado',                   'Assinou o Individual Anual em 12x no cartão.',                               interval '21 days'),
  ('f9000000-0000-4000-8000-000000000015'::uuid, 'system',       'Lead criado',               'Clicou na newsletter de agosto.',                                            interval '29 days'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'stage_change', 'Perdido',                   'Motivo: achou longe de casa.',                                               interval '9 days'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'system',       'Lead criado',               'Formulário do Google Ads.',                                                  interval '14 days')
) as v(lead_id, kind, title, body, ago)
join public.m_leads l on l.id = v.lead_id;

-- Assistant comments (stored for the demo)
insert into public.m_ai_insights (tenant_id, scope, lead_id, body, action_label, created_at)
select 'f1000000-0000-4000-8000-000000000001', 'lead', v.lead_id, v.body, v.action, now() - interval '30 minutes'
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'A Renata é o perfil exato do ICP: família com filhos, mora a 3 km, num bairro com muitas famílias. Ela perguntou de eventos para crianças e está esperando resposta desde ontem. Lead quente esfria em 48h: responda hoje e mencione o piquenique das famílias.', 'Responder no WhatsApp'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'A Mariana abriu a página de planos 3 vezes esta semana e o timing é bom: início do semestre escolar é o pico de adesão de famílias. Vale um primeiro contato ainda hoje.', 'Enviar primeira mensagem'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'O Felipe buscou "clube perto de mim", o que mostra intenção alta, mas está sem interação há 2 dias. Um convite para conhecer o espaço pode destravar.', 'Convidar para conhecer'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'A Isabela quer o plano Casal e perguntou dos eventos para casais. Fit alto. Sugiro convidá-la para uma reunião no Encontro de boas-vindas, daqui a 6 dias.', 'Convidar para reunião'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'O André pediu desconto duas vezes e mora a 35 km, fora do raio do ICP. É o tipo de perfil que costuma cancelar cedo. Prioridade baixa: não vale desconto.', 'Mover para nutrição'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'A Carolina foi indicada pela Fernanda Lima, membro com NPS 10. Indicações assim fecham bem. Na reunião de sábado, mostre a agenda de eventos para casais.', 'Ver roteiro da reunião'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'O Rafael se interessou pelos conteúdos exclusivos. Leve exemplos de aulas gravadas para a reunião de quinta.', 'Separar exemplos de aulas'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'Na reunião, a Gabriela se animou com o piquenique das famílias e só pediu para confirmar os dependentes. Está pronta para fechar: envie o contrato hoje.', 'Enviar contrato'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'Na reunião, o Bruno disse que o plano anual cabe se puder parcelar. Está há 5 dias sem responder a proposta. Ofereça 12x no cartão no follow-up de hoje.', 'Oferecer 12x no cartão'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'O Marcelo fechou o Família há 5 dias com 3 dependentes. Já está inscrito no Encontro de boas-vindas: bom sinal de engajamento.', 'Enviar kit de boas-vindas'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'A Letícia virou membro há 18 dias e ainda não usou nenhum benefício. Um convite para o Encontro de boas-vindas ajuda no onboarding.', 'Convidar para o encontro'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'A Patrícia entrou há 25 dias e ainda não usou nenhum benefício. É o momento de uma ligação de boas-vindas antes que o interesse caia.', 'Agendar ligação'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'O Diego saiu por causa da distância, então a chance de reativar é baixa. Se um dia houver plano digital, ele é um bom contato.', 'Marcar para reativar')
) as v(lead_id, body, action);

insert into public.m_ai_insights (tenant_id, scope, stage_id, body) values
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000001', 'Em Lead, a Renata e a Mariana estão quentes: perfil família, perto do clube e no pico de adesão do semestre.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000002', 'A Isabela tem fit alto e quer o plano Casal. O André pediu desconto duas vezes: prioridade baixa.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000003', 'Duas reuniões esta semana: Carolina no sábado e Rafael na quinta. Separei o que levar para cada uma.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000004', 'A Gabriela está pronta para fechar e o Bruno precisa de parcelamento. Os dois têm tarefa para hoje.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000005', 'Vocês estão em 6 de 10 na meta do mês. A Patrícia ainda não usou benefícios: vale uma ligação.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000006', 'O Diego saiu pela distância. Se houver plano digital, ele é um bom contato para reativar.');
insert into public.m_ai_insights (tenant_id, scope, body) values
  ('f1000000-0000-4000-8000-000000000001', 'pipeline', 'Hoje os 3 leads mais quentes são Renata, Gabriela e Carolina. A meta do mês está em 6 de 10.');
