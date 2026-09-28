-- =============================================================================
-- Membership demo seed: "Clube Aurora" (fictional). Demo only.
-- Dates are relative to current_date so the demo always looks current.
-- Deterministic UUIDs (prefix f*) so screens and tests can reference rows.
-- Login accounts (auth.users + m_user_roles) are created separately via the
-- Admin API, so assignee/owner columns are left empty here.
-- All names, phones, e-mails and CPFs are fictional.
-- =============================================================================

-- ---- Tenant & modules -------------------------------------------------------
insert into public.m_tenants (id, name, slug, brand_color) values
  ('f1000000-0000-4000-8000-000000000001', 'Clube Aurora', 'aurora', '#5B4BDB');

insert into public.m_tenant_modules (tenant_id, module)
select 'f1000000-0000-4000-8000-000000000001', m
from unnest(enum_range(null::public.m_module_key)) as m;

-- ---- Catalog: plans & benefits ----------------------------------------------
insert into public.m_plans (id, tenant_id, name, description, price_cents, billing_cycle, max_people) values
  ('f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Individual',        'Acesso completo para 1 pessoa',               14900, 'monthly', 1),
  ('f3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Casal',             'Titular + 1 pessoa',                          25900, 'monthly', 2),
  ('f3000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Família',           'Titular + até 3 dependentes',                 34900, 'monthly', 4),
  ('f3000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Individual Anual',  '1 pessoa, pagamento anual com 2 meses grátis', 149000, 'annual', 1);

insert into public.m_benefits (id, tenant_id, name, kind, description) values
  ('f7000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Acesso ao espaço',        'access',   'Uso livre do espaço do clube'),
  ('f7000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Convidado do mês',        'access',   '1 convidado por mês'),
  ('f7000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', '10% em parceiros',        'discount', 'Desconto na rede de parceiros'),
  ('f7000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Conteúdos exclusivos',    'content',  'Aulas e materiais só para membros'),
  ('f7000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'Encontros mensais',       'event',    'Evento mensal para membros');

-- Every plan gets the base benefits; guest pass only on Casal, Família and Anual.
insert into public.m_plan_benefits (tenant_id, plan_id, benefit_id)
select 'f1000000-0000-4000-8000-000000000001', p.id, b.id
from public.m_plans p, public.m_benefits b
where p.tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and b.tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and (b.id <> 'f7000000-0000-4000-8000-000000000002'
       or p.id <> 'f3000000-0000-4000-8000-000000000001');

-- ---- People -----------------------------------------------------------------
-- 01-09 team, 10-39 members (holders), 40-49 dependents, 50-69 leads
insert into public.m_people (id, tenant_id, full_name, email, phone_e164, birth_date) values
  -- team
  ('f2000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Marina Costa',      'marina@aurora.example.com',   '+5511900010001', '1986-02-14'),
  ('f2000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Tiago Rezende',     'tiago@aurora.example.com',    '+5511900010002', '1991-06-03'),
  ('f2000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Larissa Moura',     'larissa@aurora.example.com',  '+5511900010003', '1995-10-22'),
  -- holders
  ('f2000000-0000-4000-8000-000000000010', 'f1000000-0000-4000-8000-000000000001', 'Fernanda Lima',     'fernanda.lima@example.com',   '+5511900010010', '1988-04-11'),
  ('f2000000-0000-4000-8000-000000000011', 'f1000000-0000-4000-8000-000000000001', 'Ricardo Alves',     'ricardo.alves@example.com',   '+5511900010011', '1979-09-30'),
  ('f2000000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000001', 'Beatriz Santos',    'beatriz.santos@example.com',  '+5511900010012', '1993-01-19'),
  ('f2000000-0000-4000-8000-000000000013', 'f1000000-0000-4000-8000-000000000001', 'Gustavo Pereira',   'gustavo.pereira@example.com', '+5511900010013', '1985-12-02'),
  ('f2000000-0000-4000-8000-000000000014', 'f1000000-0000-4000-8000-000000000001', 'Aline Rocha',       'aline.rocha@example.com',     '+5511900010014', '1990-07-27'),
  ('f2000000-0000-4000-8000-000000000015', 'f1000000-0000-4000-8000-000000000001', 'Eduardo Martins',   'eduardo.martins@example.com', '+5511900010015', '1982-03-08'),
  ('f2000000-0000-4000-8000-000000000016', 'f1000000-0000-4000-8000-000000000001', 'Patrícia Gomes',    'patricia.gomes@example.com',  '+5511900010016', '1997-11-15'),
  ('f2000000-0000-4000-8000-000000000017', 'f1000000-0000-4000-8000-000000000001', 'Leonardo Dias',     'leonardo.dias@example.com',   '+5511900010017', '1989-05-05'),
  ('f2000000-0000-4000-8000-000000000018', 'f1000000-0000-4000-8000-000000000001', 'Camila Ferreira',   'camila.ferreira@example.com', '+5511900010018', '1994-08-24'),
  ('f2000000-0000-4000-8000-000000000019', 'f1000000-0000-4000-8000-000000000001', 'Rodrigo Barbosa',   'rodrigo.barbosa@example.com', '+5511900010019', '1977-02-28'),
  ('f2000000-0000-4000-8000-000000000020', 'f1000000-0000-4000-8000-000000000001', 'Juliana Ribeiro',   'juliana.ribeiro@example.com', '+5511900010020', '1992-12-09'),
  ('f2000000-0000-4000-8000-000000000021', 'f1000000-0000-4000-8000-000000000001', 'Marcelo Teixeira',  'marcelo.teixeira@example.com','+5511900010021', '1984-06-17'),
  -- dependents
  ('f2000000-0000-4000-8000-000000000040', 'f1000000-0000-4000-8000-000000000001', 'Paulo Lima',        'paulo.lima@example.com',      '+5511900010040', '1987-03-21'),
  ('f2000000-0000-4000-8000-000000000041', 'f1000000-0000-4000-8000-000000000001', 'Helena Alves',      'helena.alves@example.com',    '+5511900010041', '1981-10-10'),
  ('f2000000-0000-4000-8000-000000000042', 'f1000000-0000-4000-8000-000000000001', 'Sofia Alves',       null,                          null,             '2012-05-14'),
  ('f2000000-0000-4000-8000-000000000043', 'f1000000-0000-4000-8000-000000000001', 'Miguel Alves',      null,                          null,             '2015-09-02'),
  ('f2000000-0000-4000-8000-000000000044', 'f1000000-0000-4000-8000-000000000001', 'Vitor Rocha',       'vitor.rocha@example.com',     '+5511900010044', '1989-01-13'),
  -- leads
  ('f2000000-0000-4000-8000-000000000050', 'f1000000-0000-4000-8000-000000000001', 'Renata Carvalho',   'renata.carvalho@example.com', '+5511900010050', null),
  ('f2000000-0000-4000-8000-000000000051', 'f1000000-0000-4000-8000-000000000001', 'Felipe Nunes',      'felipe.nunes@example.com',    '+5511900010051', null),
  ('f2000000-0000-4000-8000-000000000052', 'f1000000-0000-4000-8000-000000000001', 'Isabela Freitas',   null,                          '+5511900010052', null),
  ('f2000000-0000-4000-8000-000000000053', 'f1000000-0000-4000-8000-000000000001', 'André Monteiro',    'andre.monteiro@example.com',  '+5511900010053', null),
  ('f2000000-0000-4000-8000-000000000054', 'f1000000-0000-4000-8000-000000000001', 'Carolina Pinto',    'carolina.pinto@example.com',  '+5511900010054', null),
  ('f2000000-0000-4000-8000-000000000055', 'f1000000-0000-4000-8000-000000000001', 'Bruno Cardoso',     null,                          '+5511900010055', null),
  ('f2000000-0000-4000-8000-000000000056', 'f1000000-0000-4000-8000-000000000001', 'Letícia Araújo',    'leticia.araujo@example.com',  '+5511900010056', null),
  ('f2000000-0000-4000-8000-000000000057', 'f1000000-0000-4000-8000-000000000001', 'Diego Correia',     'diego.correia@example.com',   '+5511900010057', null);

-- Obviously fake CPFs (not valid documents).
insert into public.m_people_private (tenant_id, person_id, cpf)
select 'f1000000-0000-4000-8000-000000000001', id, '000000000' || right(id::text, 2)
from public.m_people
where tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and id between 'f2000000-0000-4000-8000-000000000010' and 'f2000000-0000-4000-8000-000000000021';

-- ---- Subscriptions ----------------------------------------------------------
insert into public.m_subscriptions (id, tenant_id, holder_person_id, plan_id, status, started_at, next_billing_date, paused_at, canceled_at, cancel_reason) values
  -- healthy
  ('f4000000-0000-4000-8000-000000000010', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000010', 'f3000000-0000-4000-8000-000000000002', 'active',   current_date - 420, current_date + 12, null, null, null),
  ('f4000000-0000-4000-8000-000000000011', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000011', 'f3000000-0000-4000-8000-000000000003', 'active',   current_date - 610, current_date + 5,  null, null, null),
  ('f4000000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000012', 'f3000000-0000-4000-8000-000000000001', 'active',   current_date - 18,  current_date + 12, null, null, null),
  ('f4000000-0000-4000-8000-000000000013', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000013', 'f3000000-0000-4000-8000-000000000004', 'active',   current_date - 340, current_date + 25, null, null, null),
  ('f4000000-0000-4000-8000-000000000014', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000014', 'f3000000-0000-4000-8000-000000000002', 'active',   current_date - 150, current_date + 9,  null, null, null),
  -- attention: usage dropping
  ('f4000000-0000-4000-8000-000000000015', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000015', 'f3000000-0000-4000-8000-000000000001', 'active',   current_date - 260, current_date + 3,  null, null, null),
  ('f4000000-0000-4000-8000-000000000016', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000016', 'f3000000-0000-4000-8000-000000000001', 'active',   current_date - 25,  current_date + 5,  null, null, null),
  -- urgent: payment failing
  ('f4000000-0000-4000-8000-000000000017', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000017', 'f3000000-0000-4000-8000-000000000001', 'past_due', current_date - 200, current_date - 8,  null, null, null),
  ('f4000000-0000-4000-8000-000000000018', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000018', 'f3000000-0000-4000-8000-000000000002', 'past_due', current_date - 95,  current_date - 3,  null, null, null),
  -- paused / canceled
  ('f4000000-0000-4000-8000-000000000019', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000019', 'f3000000-0000-4000-8000-000000000001', 'paused',   current_date - 300, null, now() - interval '20 days', null, null),
  ('f4000000-0000-4000-8000-000000000020', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000020', 'f3000000-0000-4000-8000-000000000001', 'canceled', current_date - 180, null, null, now() - interval '12 days', 'Mudou de cidade'),
  ('f4000000-0000-4000-8000-000000000021', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000021', 'f3000000-0000-4000-8000-000000000003', 'active',   current_date - 5,   current_date + 25, null, null, null);

insert into public.m_subscription_members (tenant_id, subscription_id, person_id) values
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000010', 'f2000000-0000-4000-8000-000000000040'),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000011', 'f2000000-0000-4000-8000-000000000041'),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000011', 'f2000000-0000-4000-8000-000000000042'),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000011', 'f2000000-0000-4000-8000-000000000043'),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000014', 'f2000000-0000-4000-8000-000000000044');

-- ---- Invoices: last 3 cycles for monthly subs, plus current state -----------
-- Paid history for active/paused/canceled monthly subscriptions.
insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date, status, method, paid_at)
select s.tenant_id, s.id, p.price_cents, (current_date - (30 * g))::date, 'paid',
       (array['pix', 'credit_card', 'boleto'])[1 + (g + ascii(right(s.id::text, 1))) % 3]::public.m_pay_method,
       ((current_date - (30 * g)) - 1)::timestamptz
from public.m_subscriptions s
join public.m_plans p on p.id = s.plan_id
cross join generate_series(1, 3) as g
where s.tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and p.billing_cycle = 'monthly'
  and s.started_at <= current_date - (30 * g);

-- Annual plan: one paid invoice at start.
insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date, status, method, paid_at) values
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000013', 149000, current_date - 340, 'paid', 'pix', (current_date - 340)::timestamptz);

-- Upcoming invoices for active subscriptions.
insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date, status, method)
select s.tenant_id, s.id, p.price_cents, s.next_billing_date, 'pending', null
from public.m_subscriptions s
join public.m_plans p on p.id = s.plan_id
where s.tenant_id = 'f1000000-0000-4000-8000-000000000001'
  and s.status = 'active' and p.billing_cycle = 'monthly';

-- Overdue invoices for past_due subscriptions.
insert into public.m_invoices (tenant_id, subscription_id, amount_cents, due_date, status, method) values
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000017', 14900, current_date - 8, 'overdue', 'credit_card'),
  ('f1000000-0000-4000-8000-000000000001', 'f4000000-0000-4000-8000-000000000018', 25900, current_date - 3, 'overdue', 'boleto');

-- ---- Dunning rules ------------------------------------------------------------
insert into public.m_dunning_rules (tenant_id, name, offset_days, channel, template) values
  ('f1000000-0000-4000-8000-000000000001', 'Lembrete antes do vencimento', -3, 'whatsapp', 'Oi {{nome}}! Sua mensalidade do Clube Aurora vence em 3 dias. Pix e boleto no link: {{link}}'),
  ('f1000000-0000-4000-8000-000000000001', 'Dia do vencimento',             0, 'whatsapp', 'Oi {{nome}}, hoje é o dia da sua mensalidade. Pague por Pix em segundos: {{link}}'),
  ('f1000000-0000-4000-8000-000000000001', 'Atraso 3 dias',                 3, 'whatsapp', 'Oi {{nome}}, não identificamos seu pagamento. Precisa de ajuda ou de outra forma de pagar?'),
  ('f1000000-0000-4000-8000-000000000001', 'Atraso 7 dias',                 7, 'email',    'Olá {{nome}}, sua assinatura está com pagamento pendente há 7 dias. Regularize para manter seus benefícios.');

-- ---- Capture: ICP, sources, pipeline, leads -----------------------------------
insert into public.m_icp_profiles (tenant_id, answers, criteria) values
  ('f1000000-0000-4000-8000-000000000001',
   '{"cliente_ideal": "Adultos de 28 a 45 anos, moram a até 10 km, buscam comunidade e rotina",
     "dor_desejo": "Sair da rotina casa-trabalho e conhecer pessoas com interesses parecidos",
     "plano_tipico": "Casal ou Família, ticket médio R$ 250",
     "nao_e_cliente": "Quem só quer desconto pontual ou mora longe",
     "motivo_cancelamento": "Falta de tempo e mudança de cidade"}',
   '{"idade": [28, 45], "raio_km": 10, "sinais_positivos": ["indicação", "pergunta sobre eventos", "plano família"],
     "sinais_negativos": ["pede desconto repetidamente", "fora da região"]}');

insert into public.m_sources (id, tenant_id, name, kind, status, monthly_cost_cents) values
  ('f6000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Instagram Ads',             'meta_ads',     'active', 250000),
  ('f6000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'WhatsApp direto',           'whatsapp',     'active', null),
  ('f6000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Indicação de membros',      'referral',     'active', null),
  ('f6000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Google Ads',                'google_ads',   'active', 120000),
  ('f6000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'Newsletter Aurora',         'newsletter',   'active', null),
  ('f6000000-0000-4000-8000-000000000006', 'f1000000-0000-4000-8000-000000000001', 'Landing page Primavera',    'landing_page', 'paused', null);

insert into public.m_pipeline_stages (id, tenant_id, name, position, kind) values
  ('f5000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Novo',          1, 'open'),
  ('f5000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Qualificado',   2, 'open'),
  ('f5000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Visita/Trial',  3, 'open'),
  ('f5000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Proposta',      4, 'open'),
  ('f5000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'Fechado',       5, 'won'),
  ('f5000000-0000-4000-8000-000000000006', 'f1000000-0000-4000-8000-000000000001', 'Perdido',       6, 'lost');

insert into public.m_leads (id, tenant_id, person_id, stage_id, source_id, interest_plan_id, utm_source, utm_medium, utm_campaign, icp_fit, attention_points, lost_reason, stage_changed_at) values
  ('f9000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000050', 'f5000000-0000-4000-8000-000000000001', 'f6000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000003', 'instagram', 'paid_social', 'primavera-familia', 'high',   '["Perguntou sobre eventos para crianças"]', null, now() - interval '1 day'),
  ('f9000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000051', 'f5000000-0000-4000-8000-000000000001', 'f6000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000001', 'google',    'cpc',         'clube-perto-de-mim', 'medium', '[]', null, now() - interval '2 days'),
  ('f9000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000052', 'f5000000-0000-4000-8000-000000000002', 'f6000000-0000-4000-8000-000000000002', 'f3000000-0000-4000-8000-000000000002', null,        null,          null,                 'high',   '[]', null, now() - interval '3 days'),
  ('f9000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000053', 'f5000000-0000-4000-8000-000000000002', 'f6000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'instagram', 'paid_social', 'primavera-individual', 'low', '["Pediu desconto 2x", "Mora a 35 km"]', null, now() - interval '6 days'),
  ('f9000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000054', 'f5000000-0000-4000-8000-000000000003', 'f6000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000002', null,        null,          null,                 'high',   '["Indicada por Fernanda Lima"]', null, now() - interval '2 days'),
  ('f9000000-0000-4000-8000-000000000006', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000055', 'f5000000-0000-4000-8000-000000000004', 'f6000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000004', 'newsletter','email',       'setembro',           'medium', '["5 dias sem resposta à proposta"]', null, now() - interval '5 days'),
  ('f9000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000056', 'f5000000-0000-4000-8000-000000000005', 'f6000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'instagram', 'paid_social', 'primavera-individual', 'high', '[]', null, now() - interval '18 days'),
  ('f9000000-0000-4000-8000-000000000008', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000057', 'f5000000-0000-4000-8000-000000000006', 'f6000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000001', 'google',    'cpc',         'clube-perto-de-mim', 'low',    '["Fora da região"]', 'Achou longe de casa', now() - interval '9 days');

insert into public.m_activities (tenant_id, person_id, lead_id, kind, body) values
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000050', 'f9000000-0000-4000-8000-000000000001', 'message',      'Chegou pelo anúncio da campanha Primavera e perguntou sobre o plano Família.'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000054', 'f9000000-0000-4000-8000-000000000005', 'stage_change', 'Visita agendada para sábado.'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000055', 'f9000000-0000-4000-8000-000000000006', 'email',        'Proposta do plano Anual enviada.'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000015', null,                                   'note',         'Comentou que está com a agenda apertada no trabalho.'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000017', null,                                   'system',       'Cartão recusado na cobrança do mês.');

-- ---- Members: events -----------------------------------------------------------
insert into public.m_events (id, tenant_id, title, description, starts_at, ends_at, location, capacity) values
  ('f8000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Encontro de boas-vindas',  'Para quem entrou nos últimos 60 dias', date_trunc('day', now()) + interval '6 days 19 hours',  date_trunc('day', now()) + interval '6 days 21 hours',  'Salão principal', 40),
  ('f8000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Workshop de fotografia',    'Com convidado especial',              date_trunc('day', now()) + interval '13 days 10 hours', date_trunc('day', now()) + interval '13 days 13 hours', 'Sala 2',          20),
  ('f8000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Piquenique das famílias',   'Exclusivo para planos Família',       date_trunc('day', now()) + interval '20 days 11 hours', date_trunc('day', now()) + interval '20 days 16 hours', 'Área externa',    60),
  ('f8000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Happy hour de setembro',    'Encontro mensal',                     date_trunc('day', now()) - interval '10 days' + interval '19 hours', date_trunc('day', now()) - interval '10 days' + interval '22 hours', 'Terraço', 50);

insert into public.m_event_plans (tenant_id, event_id, plan_id) values
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000003');

insert into public.m_event_registrations (tenant_id, event_id, person_id, status) values
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000012', 'registered'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000021', 'registered'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000002', 'f2000000-0000-4000-8000-000000000010', 'registered'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000002', 'f2000000-0000-4000-8000-000000000013', 'registered'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000003', 'f2000000-0000-4000-8000-000000000011', 'registered'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000004', 'f2000000-0000-4000-8000-000000000010', 'attended'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000004', 'f2000000-0000-4000-8000-000000000011', 'attended'),
  ('f1000000-0000-4000-8000-000000000001', 'f8000000-0000-4000-8000-000000000004', 'f2000000-0000-4000-8000-000000000014', 'attended');

-- ---- Health -----------------------------------------------------------------------
insert into public.m_health_scores (tenant_id, person_id, score, level, dimensions) values
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000010', 92, 'ok',        '{"pagamento": 100, "engajamento": 90, "relacionamento": 95, "ciclo_de_vida": 85}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000011', 88, 'ok',        '{"pagamento": 100, "engajamento": 85, "relacionamento": 80, "ciclo_de_vida": 90}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000012', 74, 'ok',        '{"pagamento": 100, "engajamento": 60, "relacionamento": 80, "ciclo_de_vida": 55}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000013', 70, 'attention', '{"pagamento": 100, "engajamento": 70, "relacionamento": 75, "ciclo_de_vida": 35}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000014', 85, 'ok',        '{"pagamento": 100, "engajamento": 80, "relacionamento": 85, "ciclo_de_vida": 75}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000015', 52, 'attention', '{"pagamento": 100, "engajamento": 25, "relacionamento": 60, "ciclo_de_vida": 70}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000016', 58, 'attention', '{"pagamento": 100, "engajamento": 20, "relacionamento": 70, "ciclo_de_vida": 40}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000017', 28, 'urgent',    '{"pagamento": 10, "engajamento": 30, "relacionamento": 40, "ciclo_de_vida": 60}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000018', 41, 'urgent',    '{"pagamento": 30, "engajamento": 50, "relacionamento": 35, "ciclo_de_vida": 55}'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000021', 80, 'ok',        '{"pagamento": 100, "engajamento": 70, "relacionamento": 80, "ciclo_de_vida": 60}');

insert into public.m_playbooks (id, tenant_id, name, lifecycle_phase, trigger_rule, actions) values
  ('fa000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Onboarding 30 dias',      'onboarding', '{"dias_desde_inicio": [0, 30], "sem_uso_de_beneficio_dias": 14}', '["whatsapp: boas-vindas e convite para o próximo encontro", "tarefa: ligação de acompanhamento"]'),
  ('fa000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'Queda de uso',            'adoption',   '{"queda_engajamento_pct": 40, "janela_dias": 21}',                  '["whatsapp: convite personalizado para evento", "alerta: Atenção"]'),
  ('fa000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'Renovação anual',         'renewal',    '{"dias_para_renovacao": 30}',                                        '["e-mail: resumo do ano do membro", "tarefa: contato do time"]'),
  ('fa000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'Pagamento falhou',        'retention',  '{"fatura_status": "overdue"}',                                      '["whatsapp: link de Pix", "slack: aviso ao time", "tarefa: contato em 48h", "alerta: Urgência"]');

insert into public.m_health_alerts (id, tenant_id, person_id, playbook_id, level, reason, status) values
  ('fb000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000017', 'fa000000-0000-4000-8000-000000000004', 'urgent',    'Fatura em atraso há 8 dias e cartão recusado', 'open'),
  ('fb000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000018', 'fa000000-0000-4000-8000-000000000004', 'urgent',    'Boleto vencido há 3 dias; tom negativo na última conversa', 'in_progress'),
  ('fb000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000015', 'fa000000-0000-4000-8000-000000000002', 'attention', 'Não usa nenhum benefício há 3 semanas', 'open'),
  ('fb000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000016', 'fa000000-0000-4000-8000-000000000001', 'attention', 'Entrou há 25 dias e ainda não usou nenhum benefício', 'open'),
  ('fb000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000013', 'fa000000-0000-4000-8000-000000000003', 'attention', 'Plano anual renova em 25 dias', 'open');

insert into public.m_nps_responses (tenant_id, person_id, score, comment, created_at) values
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000010', 10, 'Os encontros mensais são o melhor do clube.',      now() - interval '15 days'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000011',  9, 'As crianças adoram.',                               now() - interval '20 days'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000014',  8, null,                                                now() - interval '30 days'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000015',  6, 'Gosto, mas quase não consigo ir.',                  now() - interval '12 days'),
  ('f1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000018',  4, 'O atendimento demorou para resolver minha cobrança.', now() - interval '5 days');

-- ---- Tasks --------------------------------------------------------------------------
insert into public.m_tasks (tenant_id, title, description, person_id, lead_id, subscription_id, health_alert_id, due_date, priority, status, origin) values
  ('f1000000-0000-4000-8000-000000000001', 'Ligar para Leonardo sobre o cartão recusado', 'Oferecer Pix ou troca de cartão', 'f2000000-0000-4000-8000-000000000017', null, 'f4000000-0000-4000-8000-000000000017', 'fb000000-0000-4000-8000-000000000001', current_date,     'urgent', 'todo',        'playbook'),
  ('f1000000-0000-4000-8000-000000000001', 'Resolver reclamação de cobrança da Camila',   'Ela deu NPS 4; retornar hoje',    'f2000000-0000-4000-8000-000000000018', null, 'f4000000-0000-4000-8000-000000000018', 'fb000000-0000-4000-8000-000000000002', current_date,     'high',   'in_progress', 'agent'),
  ('f1000000-0000-4000-8000-000000000001', 'Convidar Eduardo para o workshop',            null,                              'f2000000-0000-4000-8000-000000000015', null, null,                                   'fb000000-0000-4000-8000-000000000003', current_date + 2, 'medium', 'todo',        'playbook'),
  ('f1000000-0000-4000-8000-000000000001', 'Ligação de boas-vindas para Patrícia',        'Onboarding: ainda não usou benefícios', 'f2000000-0000-4000-8000-000000000016', null, null,                              'fb000000-0000-4000-8000-000000000004', current_date + 1, 'medium', 'todo',        'playbook'),
  ('f1000000-0000-4000-8000-000000000001', 'Preparar resumo do ano para Gustavo',         'Renovação do plano anual',        'f2000000-0000-4000-8000-000000000013', null, 'f4000000-0000-4000-8000-000000000013', 'fb000000-0000-4000-8000-000000000005', current_date + 10, 'low',   'todo',        'playbook'),
  ('f1000000-0000-4000-8000-000000000001', 'Follow-up da proposta com Bruno',             '5 dias sem resposta',             'f2000000-0000-4000-8000-000000000055', 'f9000000-0000-4000-8000-000000000006', null, null, current_date,     'high',   'todo',        'agent'),
  ('f1000000-0000-4000-8000-000000000001', 'Confirmar visita da Carolina no sábado',      null,                              'f2000000-0000-4000-8000-000000000054', 'f9000000-0000-4000-8000-000000000005', null, null, current_date + 1, 'medium', 'todo',        'manual'),
  ('f1000000-0000-4000-8000-000000000001', 'Responder Renata sobre eventos infantis',     null,                              'f2000000-0000-4000-8000-000000000050', 'f9000000-0000-4000-8000-000000000001', null, null, current_date - 1, 'high',   'todo',        'manual'),
  ('f1000000-0000-4000-8000-000000000001', 'Enviar kit de boas-vindas ao Marcelo',        'Novo plano Família',              'f2000000-0000-4000-8000-000000000021', null, 'f4000000-0000-4000-8000-000000000021', null, current_date - 2, 'low',    'done',        'manual');

update public.m_tasks set completed_at = now() - interval '1 day'
where tenant_id = 'f1000000-0000-4000-8000-000000000001' and status = 'done';

-- ---- Agent -----------------------------------------------------------------------------
insert into public.m_channels (tenant_id, kind, enabled, config) values
  ('f1000000-0000-4000-8000-000000000001', 'whatsapp', true, '{"numero": "+55 11 90001-0000"}'),
  ('f1000000-0000-4000-8000-000000000001', 'email',    true, '{"remetente": "contato@aurora.example.com"}'),
  ('f1000000-0000-4000-8000-000000000001', 'slack',    true, '{"canal": "#aurora-time"}'),
  ('f1000000-0000-4000-8000-000000000001', 'tasks',    true, '{}');

insert into public.m_agent_skills (tenant_id, skill, enabled) values
  ('f1000000-0000-4000-8000-000000000001', 'sales',             true),
  ('f1000000-0000-4000-8000-000000000001', 'billing',           true),
  ('f1000000-0000-4000-8000-000000000001', 'customer_success',  true),
  ('f1000000-0000-4000-8000-000000000001', 'support',           true),
  ('f1000000-0000-4000-8000-000000000001', 'manager_assistant', true);

insert into public.m_knowledge_base (tenant_id, title, content, category) values
  ('f1000000-0000-4000-8000-000000000001', 'Planos e preços',        'Individual R$ 149/mês; Casal R$ 259/mês (2 pessoas); Família R$ 349/mês (até 4 pessoas); Individual Anual R$ 1.490.', 'vendas'),
  ('f1000000-0000-4000-8000-000000000001', 'Formas de pagamento',    'Pix, boleto ou cartão de crédito recorrente. A 2ª via pode ser enviada pelo WhatsApp.',                            'cobrança'),
  ('f1000000-0000-4000-8000-000000000001', 'Pausa e cancelamento',   'Pausa e cancelamento são feitos pela equipe. Antes de cancelar, oferecer pausa de até 60 dias.',                  'políticas'),
  ('f1000000-0000-4000-8000-000000000001', 'Convidados',             'Planos Casal, Família e Anual têm direito a 1 convidado por mês.',                                                 'benefícios');

insert into public.m_conversations (id, tenant_id, channel, person_id, external_id, status, last_message_at) values
  ('fc000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'whatsapp', 'f2000000-0000-4000-8000-000000000050', 'wa-5511900010050', 'ai_handling',    now() - interval '2 hours'),
  ('fc000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'whatsapp', 'f2000000-0000-4000-8000-000000000018', 'wa-5511900010018', 'needs_human',    now() - interval '40 minutes'),
  ('fc000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001', 'whatsapp', 'f2000000-0000-4000-8000-000000000017', 'wa-5511900010017', 'ai_handling',    now() - interval '1 day');

insert into public.m_messages (tenant_id, conversation_id, direction, sender, body, created_at) values
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000001', 'inbound',  'person', 'Oi! Vi o anúncio. Vocês têm atividades para crianças?',                                       now() - interval '2 hours 5 minutes'),
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000001', 'outbound', 'agent',  'Oi, Renata! Temos sim: o plano Família inclui até 4 pessoas e um piquenique das famílias este mês. Quer agendar uma visita?', now() - interval '2 hours'),
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000002', 'inbound',  'person', 'Já paguei o boleto e continua aparecendo em atraso. Quero cancelar.',                         now() - interval '45 minutes'),
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000002', 'outbound', 'agent',  'Sinto muito pelo transtorno, Camila. Vou passar para alguém da equipe verificar agora mesmo.', now() - interval '40 minutes'),
  ('f1000000-0000-4000-8000-000000000001', 'fc000000-0000-4000-8000-000000000003', 'outbound', 'agent',  'Oi, Leonardo! Seu cartão foi recusado na mensalidade. Quer pagar por Pix? Segue o link: {{link}}', now() - interval '1 day');

insert into public.m_agent_actions (tenant_id, skill, channel, action, target, status, result, created_at, executed_at) values
  ('f1000000-0000-4000-8000-000000000001', 'billing',          'whatsapp', 'Enviar link de Pix',                 '{"pessoa": "Leonardo Dias"}',   'executed',              '{"mensagem": "enviada"}',  now() - interval '1 day', now() - interval '1 day'),
  ('f1000000-0000-4000-8000-000000000001', 'billing',          'slack',    'Avisar o time sobre pagamento falho', '{"pessoa": "Leonardo Dias"}',   'executed',              '{"canal": "#aurora-time"}', now() - interval '1 day', now() - interval '1 day'),
  ('f1000000-0000-4000-8000-000000000001', 'support',          'whatsapp', 'Transferir para humano',             '{"pessoa": "Camila Ferreira"}', 'executed',              null,                        now() - interval '40 minutes', now() - interval '40 minutes'),
  ('f1000000-0000-4000-8000-000000000001', 'customer_success', 'whatsapp', 'Convidar para o workshop',           '{"pessoa": "Eduardo Martins"}', 'awaiting_confirmation', null,                        now() - interval '3 hours', null),
  ('f1000000-0000-4000-8000-000000000001', 'sales',            'whatsapp', 'Responder lead sobre plano Família', '{"pessoa": "Renata Carvalho"}', 'executed',              null,                        now() - interval '2 hours', now() - interval '2 hours');
