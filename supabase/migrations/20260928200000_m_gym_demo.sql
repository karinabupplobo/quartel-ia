-- =============================================================================
-- Membership demo becomes a gym: "Academia Pulso" (fictional).
-- Schema: assistant analyses (scope 'analysis', structured in `details`) for
-- the Proposta and Negociação stages.
-- Data (demo tenant only): funnel stages Lead → Contato → Proposta →
-- Negociação → Fechado / Perdido, plans by level, gym benefits and events,
-- ICP, and every lead's history, next steps and assistant comments. Resets the
-- demo funnel to a known state (removes leads/people added while testing).
-- =============================================================================

-- ---- Schema: assistant analyses --------------------------------------------------
alter table public.m_ai_insights add column details jsonb not null default '{}';
alter table public.m_ai_insights drop constraint m_ai_insights_scope_check;
alter table public.m_ai_insights add constraint m_ai_insights_scope_check
  check (scope in ('lead', 'stage', 'pipeline', 'analysis'));
alter table public.m_ai_insights drop constraint m_ai_insights_check;
alter table public.m_ai_insights add constraint m_ai_insights_lead_scope_check
  check ((scope in ('lead', 'analysis')) = (lead_id is not null));

-- ---- Tenant, catalog -------------------------------------------------------------
update public.m_tenants set name = 'Academia Pulso', slug = 'pulso'
where id = 'f1000000-0000-4000-8000-000000000001';

update public.m_pipeline_stages set name = case id
    when 'f5000000-0000-4000-8000-000000000002' then 'Contato'
    when 'f5000000-0000-4000-8000-000000000003' then 'Proposta'
    else name end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

-- Ricardo's family plan becomes Premium (1 person): dependents leave the plan.
delete from public.m_subscription_members
where tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and subscription_id = 'f4000000-0000-4000-8000-000000000011';

update public.m_plans p set name = v.name, description = v.descr, price_cents = v.price,
  billing_cycle = v.cycle::public.m_billing_cycle, max_people = v.maxp
from (values
  ('f3000000-0000-4000-8000-000000000001'::uuid, 'Básico',     'Musculação livre',                           9900,   'monthly', 1),
  ('f3000000-0000-4000-8000-000000000002'::uuid, 'Dupla',      'Plus para 2 pessoas',                        25900,  'monthly', 2),
  ('f3000000-0000-4000-8000-000000000003'::uuid, 'Premium',    'Plus + avaliação física e personal mensal',  22900,  'monthly', 1),
  ('f3000000-0000-4000-8000-000000000004'::uuid, 'Anual Plus', 'Plus com pagamento anual',                   149000, 'annual',  1)
) as v(id, name, descr, price, cycle, maxp)
where p.id = v.id;

insert into public.m_plans (id, tenant_id, name, description, price_cents, billing_cycle, max_people) values
  ('f3000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'Plus', 'Musculação + aulas coletivas', 14900, 'monthly', 1);

update public.m_benefits b set name = v.name, kind = v.kind::public.m_benefit_kind, description = v.descr
from (values
  ('f7000000-0000-4000-8000-000000000001'::uuid, 'Musculação livre',         'access',   'Acesso livre à área de musculação'),
  ('f7000000-0000-4000-8000-000000000002'::uuid, 'Traga um amigo',           'access',   '1 convidado por mês'),
  ('f7000000-0000-4000-8000-000000000003'::uuid, '10% em suplementos',       'discount', 'Desconto na loja parceira'),
  ('f7000000-0000-4000-8000-000000000004'::uuid, 'Aulas coletivas',          'access',   'Funcional, spinning, pilates solo e mais'),
  ('f7000000-0000-4000-8000-000000000005'::uuid, 'Avaliação física mensal',  'content',  'Avaliação e ajuste de treino todo mês')
) as v(id, name, kind, descr)
where b.id = v.id;

delete from public.m_plan_benefits where tenant_id = 'f1000000-0000-4000-8000-000000000001';
insert into public.m_plan_benefits (tenant_id, plan_id, benefit_id)
select 'f1000000-0000-4000-8000-000000000001', ('f3000000-0000-4000-8000-00000000000' || v.p)::uuid, ('f7000000-0000-4000-8000-00000000000' || v.b)::uuid
from (values
  ('1','1'),
  ('5','1'), ('5','4'), ('5','3'),
  ('3','1'), ('3','4'), ('3','3'), ('3','5'), ('3','2'),
  ('2','1'), ('2','4'), ('2','3'), ('2','2'),
  ('4','1'), ('4','4'), ('4','3'), ('4','2')
) as v(p, b);

-- Some members move to Plus; invoices follow their plan's price.
update public.m_subscriptions set plan_id = 'f3000000-0000-4000-8000-000000000005'
where id in ('f4000000-0000-4000-8000-000000000012', 'f4000000-0000-4000-8000-000000000016', 'f4000000-0000-4000-8000-000000000015');
update public.m_invoices i set amount_cents = p.price_cents
from public.m_subscriptions s join public.m_plans p on p.id = s.plan_id
where i.subscription_id = s.id and i.tenant_id = 'f1000000-0000-4000-8000-000000000001';

update public.m_events e set title = v.title, description = v.descr, location = v.loc, capacity = v.cap
from (values
  ('f8000000-0000-4000-8000-000000000001'::uuid, 'Aulão de boas-vindas',     'Para quem entrou nos últimos 60 dias', 'Sala de aulas',   40),
  ('f8000000-0000-4000-8000-000000000002'::uuid, 'Workshop de mobilidade',   'Com fisioterapeuta convidado',         'Estúdio 2',       20),
  ('f8000000-0000-4000-8000-000000000003'::uuid, 'Desafio 30 dias Premium',  'Exclusivo para alunos Premium',        'Área funcional',  30),
  ('f8000000-0000-4000-8000-000000000004'::uuid, 'Aulão de setembro',        'Aulão mensal aberto a todos',          'Salão principal', 50)
) as v(id, title, descr, loc, cap)
where e.id = v.id;

-- ---- Capture: ICP, sources ------------------------------------------------------------
update public.m_icp_profiles set
  answers = '{"cliente_ideal": "Adultos de 25 a 45 anos que moram ou trabalham a até 3 km e querem criar rotina de treino",
              "dor_desejo": "Voltar a treinar com constância e ter acompanhamento",
              "plano_tipico": "Plus ou Premium, ticket médio R$ 170",
              "nao_e_cliente": "Quem busca só diária ou mora longe",
              "motivo_cancelamento": "Falta de tempo e perda de motivação no 2º mês"}',
  criteria = '{"idade": [25, 45], "raio_km": 3, "sinais_positivos": ["indicação", "pede aula experimental", "pergunta sobre avaliação física"],
               "sinais_negativos": ["pede desconto repetidamente", "fora da região", "só quer diária"]}'
where tenant_id = 'f1000000-0000-4000-8000-000000000001' and is_active;

update public.m_sources set name = case id
    when 'f6000000-0000-4000-8000-000000000005' then 'Newsletter Pulso'
    when 'f6000000-0000-4000-8000-000000000006' then 'Landing page Verão'
    when 'f6000000-0000-4000-8000-000000000003' then 'Indicação de alunos'
    else name end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

-- ---- Reset the demo funnel ----------------------------------------------------------------
-- People added while testing (not part of the demo data) and their leads.
delete from public.m_people
where tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and id::text not like 'f2000000-0000-4000-8000-%';
delete from public.m_leads
where tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and id::text not like 'f9000000-0000-4000-8000-%';

update public.m_leads l set
  stage_id = ('f5000000-0000-4000-8000-00000000000' || v.stage)::uuid,
  interest_plan_id = ('f3000000-0000-4000-8000-00000000000' || v.plan)::uuid,
  stage_changed_at = now() - v.days * interval '1 day',
  utm_campaign = v.campaign,
  lost_reason = v.lost,
  source_note = v.note,
  ai_priority = v.prio
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, '1', '3', 1,  'verao-premium',         null::text,            null::text,                  92),
  ('f9000000-0000-4000-8000-000000000009'::uuid, '1', '3', 1,  'verao-premium',         null,                  null,                        84),
  ('f9000000-0000-4000-8000-000000000002'::uuid, '1', '5', 2,  'academia-perto-de-mim', null,                  null,                        61),
  ('f9000000-0000-4000-8000-000000000010'::uuid, '1', '1', 4,  'setembro',              null,                  null,                        44),
  ('f9000000-0000-4000-8000-000000000011'::uuid, '1', '1', 3,  null,                    null,                  'Formulário do site',        31),
  ('f9000000-0000-4000-8000-000000000003'::uuid, '2', '2', 3,  null,                    null,                  null,                        78),
  ('f9000000-0000-4000-8000-000000000004'::uuid, '2', '1', 6,  'verao-plus',            null,                  null,                        22),
  ('f9000000-0000-4000-8000-000000000005'::uuid, '3', '5', 2,  null,                    null,                  'Indicada por Fernanda Lima', 88),
  ('f9000000-0000-4000-8000-000000000012'::uuid, '3', '3', 1,  'academia-perto-de-mim', null,                  null,                        66),
  ('f9000000-0000-4000-8000-000000000013'::uuid, '4', '2', 2,  null,                    null,                  'Indicada por Ricardo Alves', 90),
  ('f9000000-0000-4000-8000-000000000006'::uuid, '4', '4', 5,  'setembro',              null,                  null,                        74),
  ('f9000000-0000-4000-8000-000000000016'::uuid, '5', '3', 5,  null,                    null,                  'Indicado por Aline Rocha',  86),
  ('f9000000-0000-4000-8000-000000000007'::uuid, '5', '1', 18, 'verao-plus',            null,                  null,                        80),
  ('f9000000-0000-4000-8000-000000000018'::uuid, '5', '5', 25, 'academia-perto-de-mim', null,                  null,                        78),
  ('f9000000-0000-4000-8000-000000000017'::uuid, '5', '5', 18, 'verao-plus',            null,                  null,                        70),
  ('f9000000-0000-4000-8000-000000000014'::uuid, '5', '2', 9,  null,                    null,                  null,                        65),
  ('f9000000-0000-4000-8000-000000000015'::uuid, '5', '4', 21, 'agosto',                null,                  null,                        62),
  ('f9000000-0000-4000-8000-000000000008'::uuid, '6', '1', 9,  'academia-perto-de-mim', 'Achou longe de casa', null,                        15)
) as v(id, stage, plan, days, campaign, lost, note, prio)
where l.id = v.id;

-- Next steps (tasks)
delete from public.m_tasks where tenant_id = 'f1000000-0000-4000-8000-000000000001';
insert into public.m_tasks (tenant_id, title, description, person_id, lead_id, subscription_id, health_alert_id, due_date, priority, status, origin, completed_at) values
  ('f1000000-0000-4000-8000-000000000001', 'Responder sobre avaliação física',   null, 'f2000000-0000-4000-8000-000000000050', 'f9000000-0000-4000-8000-000000000001', null, null, current_date - 1, 'high',   'todo', 'manual', null),
  ('f1000000-0000-4000-8000-000000000001', 'Convidar para aula experimental',    null, 'f2000000-0000-4000-8000-000000000051', 'f9000000-0000-4000-8000-000000000002', null, null, current_date + 1, 'medium', 'todo', 'agent',  null),
  ('f1000000-0000-4000-8000-000000000001', 'Enviar guia de treino para iniciantes', null, 'f2000000-0000-4000-8000-000000000059', 'f9000000-0000-4000-8000-000000000010', null, null, current_date + 2, 'low', 'todo', 'manual', null),
  ('f1000000-0000-4000-8000-000000000001', 'Enviar proposta do Plus',            null, 'f2000000-0000-4000-8000-000000000054', 'f9000000-0000-4000-8000-000000000005', null, null, current_date,     'high',   'todo', 'agent',  null),
  ('f1000000-0000-4000-8000-000000000001', 'Aula experimental com personal',     null, 'f2000000-0000-4000-8000-000000000061', 'f9000000-0000-4000-8000-000000000012', null, null, current_date + 3, 'medium', 'todo', 'manual', null),
  ('f1000000-0000-4000-8000-000000000001', 'Enviar contrato',                    null, 'f2000000-0000-4000-8000-000000000062', 'f9000000-0000-4000-8000-000000000013', null, null, current_date,     'high',   'todo', 'agent',  null),
  ('f1000000-0000-4000-8000-000000000001', 'Ligar oferecendo 12x no cartão',     null, 'f2000000-0000-4000-8000-000000000055', 'f9000000-0000-4000-8000-000000000006', null, null, current_date,     'high',   'todo', 'agent',  null),
  -- member care (outside the funnel)
  ('f1000000-0000-4000-8000-000000000001', 'Ligar para Leonardo sobre o cartão recusado', 'Oferecer Pix ou troca de cartão', 'f2000000-0000-4000-8000-000000000017', null, 'f4000000-0000-4000-8000-000000000017', 'fb000000-0000-4000-8000-000000000001', current_date, 'urgent', 'todo', 'playbook', null),
  ('f1000000-0000-4000-8000-000000000001', 'Resolver reclamação de cobrança da Camila', 'Ela deu NPS 4; retornar hoje', 'f2000000-0000-4000-8000-000000000018', null, 'f4000000-0000-4000-8000-000000000018', 'fb000000-0000-4000-8000-000000000002', current_date, 'high', 'in_progress', 'agent', null),
  ('f1000000-0000-4000-8000-000000000001', 'Convidar Eduardo para o aulão',      null, 'f2000000-0000-4000-8000-000000000015', null, null, 'fb000000-0000-4000-8000-000000000003', current_date + 2, 'medium', 'todo', 'playbook', null),
  ('f1000000-0000-4000-8000-000000000001', 'Ligação de boas-vindas para Patrícia', 'Parou de treinar na 2ª semana', 'f2000000-0000-4000-8000-000000000016', null, null, 'fb000000-0000-4000-8000-000000000004', current_date + 1, 'medium', 'todo', 'playbook', null),
  ('f1000000-0000-4000-8000-000000000001', 'Preparar resumo do ano para Gustavo', 'Renovação do Anual Plus', 'f2000000-0000-4000-8000-000000000013', null, 'f4000000-0000-4000-8000-000000000013', 'fb000000-0000-4000-8000-000000000005', current_date + 10, 'low', 'todo', 'playbook', null),
  ('f1000000-0000-4000-8000-000000000001', 'Enviar kit de boas-vindas ao Marcelo', 'Novo aluno Premium', 'f2000000-0000-4000-8000-000000000021', null, 'f4000000-0000-4000-8000-000000000021', null, current_date - 2, 'low', 'done', 'manual', now() - interval '1 day');

-- Lead history
delete from public.m_activities where tenant_id = 'f1000000-0000-4000-8000-000000000001';
insert into public.m_activities (tenant_id, person_id, lead_id, kind, body, metadata, created_at)
select 'f1000000-0000-4000-8000-000000000001', l.person_id, l.id, v.kind::public.m_activity_kind, v.body,
       jsonb_build_object('title', v.title), now() - v.ago
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'message',      'WhatsApp',                    'Perguntou se o Premium inclui avaliação física.',                                        interval '1 day'),
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'system',       'Lead criado',                 'Anúncio do Instagram, campanha verao-premium.',                                          interval '1 day 2 minutes'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'note',         'Visitou a página de planos',  '3ª visita esta semana, ficou 4 min no Premium.',                                         interval '3 hours'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'system',       'Lead criado',                 'Formulário do anúncio verao-premium.',                                                   interval '1 day'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'email',        'E-mail',                      'Recebeu a apresentação da academia. Abriu, não respondeu.',                              interval '2 days'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'system',       'Lead criado',                 'Google Ads, busca "academia perto de mim".',                                              interval '2 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000010'::uuid, 'email',        'E-mail',                      'Abriu a newsletter de setembro.',                                                        interval '3 days'),
  ('f9000000-0000-4000-8000-000000000010'::uuid, 'system',       'Lead criado',                 'Clicou no link de planos da newsletter.',                                                interval '4 days'),
  ('f9000000-0000-4000-8000-000000000011'::uuid, 'message',      'WhatsApp',                    'Pediu só a tabela de preços.',                                                           interval '3 days'),
  ('f9000000-0000-4000-8000-000000000011'::uuid, 'system',       'Lead criado',                 'Formulário da landing page Verão.',                                                      interval '3 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'message',      'WhatsApp',                    'Perguntou horários das aulas coletivas à noite para ela e o namorado.',                  interval '3 days'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'stage_change', 'Movida para Contato',         'Respondeu às perguntas iniciais.',                                                       interval '3 days 10 minutes'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'system',       'Lead criado',                 'Chamou direto no WhatsApp.',                                                             interval '4 days'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'message',      'WhatsApp',                    'Pediu desconto pela segunda vez.',                                                       interval '5 days'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'message',      'WhatsApp',                    'Perguntou se havia desconto no Básico.',                                                 interval '6 days'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'system',       'Lead criado',                 'Anúncio do Instagram, campanha verao-plus.',                                             interval '7 days'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'message',      'WhatsApp',                    'Pediu os valores do Plus e do Premium.',                                                 interval '1 day'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'meeting',      'Aula experimental',           'Fez aula de funcional às 7h e gostou da turma. Perguntou se dá para congelar o plano nas férias.', interval '2 days'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'stage_change', 'Movida para Proposta',        'Aula experimental feita.',                                                               interval '2 days 1 hour'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'system',       'Lead criado',                 'Indicação da aluna Fernanda Lima.',                                                      interval '3 days'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'meeting',      'Aula experimental agendada',  'Quinta às 7h, com personal.',                                                            interval '1 day'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'call',         'Ligação',                     'Quer ganhar massa muscular e tem receio de treinar sem orientação.',                     interval '2 days'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'system',       'Lead criado',                 'Google Ads, busca "academia perto de mim".',                                              interval '5 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'call',         'Ligação',                     'Aceitou que o marido comece no dia 1º do mês que vem, sem desconto.',                    interval '1 day'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'message',      'WhatsApp',                    'Perguntou se o marido pode começar só no mês que vem.',                                  interval '2 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'email',        'Proposta enviada',            'Plano Dupla, R$ 259/mês, para ela e o marido.',                                          interval '3 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'meeting',      'Aula experimental',           'Fez aula com o marido. Os dois gostaram do espaço e dos horários.',                      interval '4 days'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'system',       'Lead criado',                 'Indicação do aluno Ricardo Alves.',                                                      interval '9 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'email',        'Proposta enviada',            'Anual Plus, R$ 1.490 à vista.',                                                          interval '5 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'meeting',      'Aula experimental',           'Disse que o anual cabe no orçamento se puder parcelar.',                                 interval '6 days'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'system',       'Lead criado',                 'Clicou na newsletter de setembro.',                                                      interval '12 days'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'stage_change', 'Fechado',                     'Assinou o Premium e agendou a avaliação física.',                                        interval '5 days'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'system',       'Lead criado',                 'Indicação da aluna Aline Rocha.',                                                        interval '11 days'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'stage_change', 'Fechado',                     'Assinou o Básico, pagou por Pix.',                                                       interval '18 days'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'system',       'Lead criado',                 'Anúncio do Instagram, campanha verao-plus.',                                             interval '25 days'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'stage_change', 'Fechado',                     'Assinou o Plus por boleto.',                                                             interval '25 days'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'system',       'Lead criado',                 'Google Ads, busca "academia perto de mim".',                                              interval '30 days'),
  ('f9000000-0000-4000-8000-000000000017'::uuid, 'stage_change', 'Fechado',                     'Assinou o Plus no cartão.',                                                              interval '18 days'),
  ('f9000000-0000-4000-8000-000000000017'::uuid, 'system',       'Lead criado',                 'Anúncio do Instagram, campanha verao-plus.',                                             interval '24 days'),
  ('f9000000-0000-4000-8000-000000000014'::uuid, 'stage_change', 'Fechado',                     'Assinou o Dupla por Pix.',                                                               interval '9 days'),
  ('f9000000-0000-4000-8000-000000000014'::uuid, 'system',       'Lead criado',                 'Chamou direto no WhatsApp.',                                                             interval '15 days'),
  ('f9000000-0000-4000-8000-000000000015'::uuid, 'stage_change', 'Fechado',                     'Assinou o Anual Plus em 12x no cartão.',                                                 interval '21 days'),
  ('f9000000-0000-4000-8000-000000000015'::uuid, 'system',       'Lead criado',                 'Clicou na newsletter de agosto.',                                                        interval '29 days'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'stage_change', 'Perdido',                     'Motivo: achou longe de casa.',                                                           interval '9 days'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'system',       'Lead criado',                 'Google Ads, busca "academia perto de mim".',                                              interval '14 days')
) as v(lead_id, kind, title, body, ago)
join public.m_leads l on l.id = v.lead_id;

-- ---- Assistant: comments, stage summaries, analyses ---------------------------------------
delete from public.m_ai_insights where tenant_id = 'f1000000-0000-4000-8000-000000000001';

insert into public.m_ai_insights (tenant_id, scope, lead_id, body, action_label, created_at)
select 'f1000000-0000-4000-8000-000000000001', 'lead', v.lead_id, v.body, v.action, now() - interval '30 minutes'
from (values
  ('f9000000-0000-4000-8000-000000000001'::uuid, 'A Renata é o perfil exato do ICP: 34 anos, trabalha a 2 km da academia e quer voltar a treinar com acompanhamento. Está esperando resposta desde ontem sobre a avaliação física. Lead quente esfria em 48h: responda hoje e ofereça uma aula experimental.', 'Responder no WhatsApp'),
  ('f9000000-0000-4000-8000-000000000009'::uuid, 'A Mariana abriu a página de planos 3 vezes esta semana e o timing é bom: começo do verão é o pico de matrículas. Vale um primeiro contato ainda hoje.', 'Enviar primeira mensagem'),
  ('f9000000-0000-4000-8000-000000000002'::uuid, 'O Felipe buscou "academia perto de mim", o que mostra intenção alta. O convite para a aula experimental está agendado para amanhã.', 'Convidar para aula experimental'),
  ('f9000000-0000-4000-8000-000000000003'::uuid, 'A Isabela quer o Dupla para treinar com o namorado, mas está há 3 dias sem próximo passo. Agende uma aula experimental para os dois.', 'Agendar aula experimental'),
  ('f9000000-0000-4000-8000-000000000004'::uuid, 'O André pediu desconto duas vezes e mora a 12 km, fora do raio do ICP. É o perfil que costuma cancelar cedo. Prioridade baixa: não vale desconto.', 'Mover para nutrição'),
  ('f9000000-0000-4000-8000-000000000005'::uuid, 'A Carolina fez aula experimental e gostou. Abra a Análise IA: a proposta do Plus já está pronta para enviar hoje.', 'Ver análise'),
  ('f9000000-0000-4000-8000-000000000012'::uuid, 'O Rafael quer orientação de perto. Depois da aula com personal na quinta, envie a proposta do Premium no mesmo dia.', 'Ver análise'),
  ('f9000000-0000-4000-8000-000000000013'::uuid, 'A Gabriela está pronta para fechar: só falta enviar o contrato com o início do marido no dia 1º.', 'Enviar contrato'),
  ('f9000000-0000-4000-8000-000000000006'::uuid, 'O Bruno está há 5 dias sem responder. Ele pediu parcelamento e a proposta não citou isso: ofereça 12x no cartão hoje.', 'Oferecer 12x no cartão'),
  ('f9000000-0000-4000-8000-000000000016'::uuid, 'O Marcelo fechou o Premium há 5 dias e já agendou a avaliação física: bom sinal de engajamento.', 'Enviar kit de boas-vindas'),
  ('f9000000-0000-4000-8000-000000000007'::uuid, 'A Letícia virou aluna há 18 dias e só treinou 2 vezes. Um convite para o aulão de boas-vindas ajuda no onboarding.', 'Convidar para o aulão'),
  ('f9000000-0000-4000-8000-000000000018'::uuid, 'A Patrícia entrou há 25 dias e parou de treinar na 2ª semana. É o momento de uma ligação antes que ela desista.', 'Agendar ligação'),
  ('f9000000-0000-4000-8000-000000000008'::uuid, 'O Diego saiu porque achou longe de casa. A chance de reativar é baixa, mas se abrir uma unidade na zona leste, ele é um bom contato.', 'Marcar para reativar')
) as v(lead_id, body, action);

insert into public.m_ai_insights (tenant_id, scope, stage_id, body) values
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000001', 'Em Lead, a Renata e a Mariana estão quentes: perfil do ICP, perto da academia e no pico de matrículas do verão.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000002', 'A Isabela está há 3 dias sem próximo passo. O André pediu desconto duas vezes: prioridade baixa.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000003', 'A Carolina já fez aula experimental: a proposta dela sai hoje. O Rafael faz aula com personal na quinta.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000004', 'A Gabriela está pronta para fechar e o Bruno precisa de parcelamento. Os dois têm próximo passo para hoje.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000005', 'Vocês estão em 6 de 10 na meta do mês. A Patrícia parou de treinar na 2ª semana: vale uma ligação.'),
  ('f1000000-0000-4000-8000-000000000001', 'stage', 'f5000000-0000-4000-8000-000000000006', 'O Diego saiu pela distância. Se abrir unidade na zona leste, ele é um bom contato para reativar.');
insert into public.m_ai_insights (tenant_id, scope, body) values
  ('f1000000-0000-4000-8000-000000000001', 'pipeline', 'Hoje os 3 leads mais quentes são Renata, Gabriela e Carolina.');

insert into public.m_ai_insights (tenant_id, scope, lead_id, body, details) values
('f1000000-0000-4000-8000-000000000001', 'analysis', 'f9000000-0000-4000-8000-000000000005',
 'Análise para a proposta da Carolina',
 $j${
  "kind": "proposal",
  "summary": "Carolina fez aula experimental de funcional e gostou da turma das 7h. Quer treinar 3 vezes por semana antes do trabalho e veio indicada pela aluna Fernanda Lima.",
  "conversations": [
    "Aula experimental (2 dias atrás): elogiou a turma e o professor; perguntou se dá para congelar o plano nas férias.",
    "WhatsApp (ontem): pediu os valores do Plus e do Premium."
  ],
  "tips": [
    "Proponha o Plus: cobre as aulas coletivas que ela quer, sem pagar pelo personal que ela não pediu.",
    "Responda à dúvida das férias: o plano pode ser congelado por até 30 dias por ano.",
    "Cite a indicação da Fernanda: quem vem indicado costuma fechar mais rápido."
  ],
  "next_step": "Enviar a proposta do Plus hoje e confirmar a matrícula até sexta.",
  "proposal": {
    "subject": "Sua proposta na Academia Pulso",
    "body": "Oi, Carolina!\n\nQue bom que você curtiu a aula de funcional das 7h. Preparei uma proposta pensando no que você me contou:\n\nPlano Plus: R$ 149/mês\n• Musculação livre\n• Todas as aulas coletivas (funcional, spinning, pilates solo e mais)\n• 10% de desconto em suplementos\n\nSobre as férias: você pode congelar o plano por até 30 dias por ano, sem custo.\n\nSe fechar até sexta, a matrícula sai sem taxa de adesão. É só responder este e-mail que eu envio o link de pagamento (Pix, boleto ou cartão).\n\nAbraço,\nMarina · Academia Pulso"
  }
 }$j$::jsonb),
('f1000000-0000-4000-8000-000000000001', 'analysis', 'f9000000-0000-4000-8000-000000000012',
 'Análise para a proposta do Rafael',
 $j${
  "kind": "proposal",
  "summary": "Rafael quer ganhar massa muscular e tem receio de treinar sem orientação. A aula experimental com personal está marcada para quinta.",
  "conversations": [
    "Ligação (2 dias atrás): contou que já tentou treinar sozinho e desistiu por não ver resultado.",
    "Agendamento (ontem): aula experimental na quinta às 7h, com personal."
  ],
  "tips": [
    "Proponha o Premium: o personal mensal e a avaliação física resolvem o medo de treinar sem orientação.",
    "Inclua na proposta um plano de 12 semanas com avaliação a cada mês.",
    "Evite focar em preço: para ele o valor está no acompanhamento."
  ],
  "next_step": "Fazer a aula experimental com personal na quinta e enviar a proposta do Premium no mesmo dia.",
  "proposal": {
    "subject": "Seu plano de treino na Academia Pulso",
    "body": "Oi, Rafael!\n\nPelo que conversamos, o seu objetivo é ganhar massa muscular com orientação de perto. Por isso a minha sugestão é o Premium:\n\nPlano Premium: R$ 229/mês\n• Musculação livre e aulas coletivas\n• Avaliação física todo mês para acompanhar a evolução\n• 1 sessão por mês com personal para ajustar o seu treino\n\nNa aula de quinta, o personal já monta a primeira versão do seu treino de 12 semanas.\n\nQualquer dúvida, é só responder este e-mail.\n\nAbraço,\nMarina · Academia Pulso"
  }
 }$j$::jsonb),
('f1000000-0000-4000-8000-000000000001', 'analysis', 'f9000000-0000-4000-8000-000000000013',
 'Análise da negociação da Gabriela',
 $j${
  "kind": "negotiation",
  "summary": "Gabriela recebeu a proposta do plano Dupla (R$ 259/mês) para ela e o marido há 3 dias e quer fechar.",
  "conversations": [
    "E-mail (3 dias atrás): proposta do Dupla enviada.",
    "WhatsApp (2 dias atrás): perguntou se o marido pode começar só no mês que vem.",
    "Ligação (ontem): aceitou que o marido comece no dia 1º, sem desconto."
  ],
  "negotiation": [
    "Pediu início escalonado para o marido: combinado, sem desconto.",
    "Não questionou o preço nem a forma de pagamento."
  ],
  "tips": [
    "Envie o contrato com o início dela imediato e o do marido no dia 1º.",
    "Sugira o cartão recorrente para evitar atraso na primeira mensalidade."
  ],
  "next_step": "Enviar o contrato hoje, com início dela imediato e do marido no dia 1º."
 }$j$::jsonb),
('f1000000-0000-4000-8000-000000000001', 'analysis', 'f9000000-0000-4000-8000-000000000006',
 'Análise da negociação do Bruno',
 $j${
  "kind": "negotiation",
  "summary": "Bruno recebeu a proposta do Anual Plus (R$ 1.490 à vista) há 5 dias e ainda não respondeu.",
  "conversations": [
    "Aula experimental (6 dias atrás): disse que o anual cabe no orçamento se puder parcelar.",
    "E-mail (5 dias atrás): proposta do Anual Plus enviada, sem mencionar parcelamento."
  ],
  "negotiation": [
    "Objeção principal: pagamento à vista.",
    "A proposta enviada não respondeu ao pedido de parcelamento."
  ],
  "tips": [
    "Ofereça 12x de R$ 124,17 no cartão, sem juros.",
    "Mostre a economia: R$ 298 no ano em relação ao Plus mensal.",
    "Se ele não quiser se comprometer por um ano, ofereça o Plus mensal como alternativa."
  ],
  "next_step": "Ligar hoje oferecendo 12x no cartão; se não atender, reenviar a proposta com parcelamento amanhã."
 }$j$::jsonb);

-- ---- Member care & agent texts --------------------------------------------------------------
update public.m_health_alerts set reason = case id
    when 'fb000000-0000-4000-8000-000000000003' then 'Não treina há 3 semanas'
    when 'fb000000-0000-4000-8000-000000000004' then 'Entrou há 25 dias e parou de treinar na 2ª semana'
    when 'fb000000-0000-4000-8000-000000000005' then 'Anual Plus renova em 25 dias'
    else reason end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

update public.m_playbooks set name = case id
    when 'fa000000-0000-4000-8000-000000000002' then 'Queda de frequência'
    else name end,
  actions = case id
    when 'fa000000-0000-4000-8000-000000000001' then '["whatsapp: boas-vindas e convite para o aulão", "tarefa: ligação de acompanhamento"]'::jsonb
    when 'fa000000-0000-4000-8000-000000000002' then '["whatsapp: convite personalizado para uma aula coletiva", "alerta: Atenção"]'::jsonb
    when 'fa000000-0000-4000-8000-000000000003' then '["e-mail: resumo da evolução do aluno no ano", "tarefa: contato do time"]'::jsonb
    else actions end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

update public.m_nps_responses set comment = case score
    when 10 then 'Os aulões de sábado são o melhor da academia.'
    when 9 then 'Professores muito atenciosos.'
    else comment end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

update public.m_dunning_rules set template = replace(template, 'Clube Aurora', 'Academia Pulso')
where tenant_id = 'f1000000-0000-4000-8000-000000000001';

delete from public.m_knowledge_base where tenant_id = 'f1000000-0000-4000-8000-000000000001';
insert into public.m_knowledge_base (tenant_id, title, content, category) values
  ('f1000000-0000-4000-8000-000000000001', 'Planos e preços',     'Básico R$ 99/mês (musculação); Plus R$ 149/mês (+ aulas coletivas); Premium R$ 229/mês (+ avaliação física e personal mensal); Dupla R$ 259/mês (Plus para 2 pessoas); Anual Plus R$ 1.490 (até 12x no cartão).', 'vendas'),
  ('f1000000-0000-4000-8000-000000000001', 'Aula experimental',   'Todo interessado pode fazer 1 aula experimental gratuita, de musculação ou de qualquer aula coletiva.', 'vendas'),
  ('f1000000-0000-4000-8000-000000000001', 'Formas de pagamento', 'Pix, boleto ou cartão de crédito recorrente. A 2ª via pode ser enviada pelo WhatsApp.', 'cobrança'),
  ('f1000000-0000-4000-8000-000000000001', 'Congelamento e cancelamento', 'O plano pode ser congelado por até 30 dias por ano. Pausa e cancelamento são feitos pela equipe; antes de cancelar, oferecer o congelamento.', 'políticas');

delete from public.m_messages where tenant_id = 'f1000000-0000-4000-8000-000000000001' and conversation_id = 'fc000000-0000-4000-8000-000000000001';
insert into public.m_messages (tenant_id, conversation_id, direction, sender, body, created_at) values
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000001', 'inbound',  'person', 'Oi! Vi o anúncio. O Premium inclui avaliação física?', now() - interval '1 day 5 minutes'),
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000001', 'outbound', 'agent',  'Oi, Renata! Inclui sim: avaliação física todo mês e uma sessão com personal. Quer agendar uma aula experimental gratuita?', now() - interval '1 day');

update public.m_agent_actions set action = case action
    when 'Convidar para o workshop' then 'Convidar para o aulão'
    when 'Responder lead sobre plano Família' then 'Responder lead sobre o Premium'
    else action end
where tenant_id = 'f1000000-0000-4000-8000-000000000001';
