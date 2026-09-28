import { supabase } from './supabase'

export type Fit = 'high' | 'medium' | 'low'
export type StageKind = 'open' | 'won' | 'lost'
export type BillingCycle = 'monthly' | 'quarterly' | 'semiannual' | 'annual'

export interface Stage {
  id: string
  name: string
  position: number
  kind: StageKind
}

export interface Lead {
  id: string
  personId: string
  stageId: string
  name: string
  email: string | null
  phone: string | null
  source: string | null
  campaign: string | null
  planName: string | null
  planPriceCents: number | null
  planCycle: BillingCycle | null
  fit: Fit | null
  priority: number
  stageChangedAt: string
  lostReason: string | null
  /** Latest message, call, e-mail or meeting with the lead. */
  lastContact: { at: string; kind: string } | null
}

export interface Task {
  id: string
  leadId: string
  title: string
  dueDate: string | null
}

/** The assistant's structured analysis of a lead in Proposta or Negociação. */
export interface Analysis {
  kind: 'proposal' | 'negotiation'
  summary: string
  conversations: string[]
  negotiation?: string[]
  tips: string[]
  next_step: string
  proposal?: { subject: string; body: string }
}

export interface Insight {
  id: string
  scope: 'lead' | 'stage' | 'pipeline' | 'analysis'
  leadId: string | null
  stageId: string | null
  body: string
  actionLabel: string | null
  details: Analysis | null
}

export interface Workspace {
  tenantId: string
  tenantName: string
  closeGoal: number | null
  userFirstName: string
  icpSummary: string | null
}

export interface FunnelData {
  stages: Stage[]
  leads: Lead[]
  tasks: Task[]
  insights: Insight[]
}

export interface HistoryItem {
  id: string
  kind: string
  title: string
  body: string | null
  createdAt: string
}

/** Activity kinds that count as talking to the lead. */
const CONTACT_KINDS = ['message', 'call', 'email', 'meeting']

export const CONTACT_LABEL: Record<string, string> = {
  message: 'WhatsApp',
  call: 'Ligação',
  email: 'E-mail',
  meeting: 'Aula / visita',
}

// PostgREST returns an embedded to-one row as an object (or null).
type One<T> = T | null

function fail(error: { message: string } | null, what: string): void {
  if (error) throw new Error(`Não foi possível carregar ${what}: ${error.message}`)
}

/** The team workspace of the signed-in user (first tenant where they are team). */
export async function loadWorkspace(): Promise<Workspace | null> {
  const { data: auth } = await supabase.auth.getUser()
  if (!auth.user) return null

  const { data: roles, error } = await supabase
    .from('m_user_roles')
    .select('tenant_id, role, person:m_people(full_name), tenant:m_tenants(name, monthly_close_goal)')
    .eq('user_id', auth.user.id)
    .in('role', ['admin', 'staff', 'attendant'])
    .limit(1)
  fail(error, 'seu acesso')
  const row = roles?.[0] as unknown as
    | { tenant_id: string; person: One<{ full_name: string }>; tenant: One<{ name: string; monthly_close_goal: number | null }> }
    | undefined
  if (!row) return null

  const { data: icp } = await supabase
    .from('m_icp_profiles')
    .select('answers')
    .eq('tenant_id', row.tenant_id)
    .eq('is_active', true)
    .maybeSingle()
  const answers = (icp?.answers ?? {}) as Record<string, string>
  const icpSummary = [answers.cliente_ideal, answers.plano_tipico ? `Plano típico: ${answers.plano_tipico}` : null]
    .filter(Boolean)
    .join('. ')

  return {
    tenantId: row.tenant_id,
    tenantName: row.tenant?.name ?? '',
    closeGoal: row.tenant?.monthly_close_goal ?? null,
    userFirstName: (row.person?.full_name ?? '').split(' ')[0],
    icpSummary: icpSummary || null,
  }
}

export async function loadFunnel(tenantId: string): Promise<FunnelData> {
  const [stagesRes, leadsRes, tasksRes, insightsRes, contactsRes] = await Promise.all([
    supabase.from('m_pipeline_stages').select('id, name, position, kind').eq('tenant_id', tenantId).order('position'),
    supabase
      .from('m_leads')
      .select(
        'id, person_id, stage_id, icp_fit, ai_priority, stage_changed_at, utm_campaign, source_note, lost_reason,' +
          ' person:m_people(full_name, email, phone_e164), source:m_sources(name), plan:m_plans(name, price_cents, billing_cycle)',
      )
      .eq('tenant_id', tenantId),
    supabase
      .from('m_tasks')
      .select('id, lead_id, title, due_date')
      .eq('tenant_id', tenantId)
      .in('status', ['todo', 'in_progress'])
      .not('lead_id', 'is', null)
      .order('due_date', { ascending: true, nullsFirst: false }),
    supabase.from('m_ai_insights').select('id, scope, lead_id, stage_id, body, action_label, details').eq('tenant_id', tenantId),
    supabase
      .from('m_activities')
      .select('lead_id, kind, created_at')
      .eq('tenant_id', tenantId)
      .in('kind', CONTACT_KINDS)
      .not('lead_id', 'is', null)
      .order('created_at', { ascending: false }),
  ])
  fail(stagesRes.error, 'as etapas')
  fail(leadsRes.error, 'os leads')
  fail(tasksRes.error, 'as tarefas')
  fail(insightsRes.error, 'os comentários da assistente')
  fail(contactsRes.error, 'os últimos contatos')

  // Rows come newest first, so the first one per lead is its last contact.
  const lastContact = new Map<string, { at: string; kind: string }>()
  for (const a of (contactsRes.data ?? []) as { lead_id: string; kind: string; created_at: string }[]) {
    if (!lastContact.has(a.lead_id)) lastContact.set(a.lead_id, { at: a.created_at, kind: a.kind })
  }

  type LeadRow = {
    id: string
    person_id: string
    stage_id: string
    icp_fit: Fit | null
    ai_priority: number | null
    stage_changed_at: string
    utm_campaign: string | null
    source_note: string | null
    lost_reason: string | null
    person: One<{ full_name: string; email: string | null; phone_e164: string | null }>
    source: One<{ name: string }>
    plan: One<{ name: string; price_cents: number; billing_cycle: BillingCycle }>
  }

  const leads = ((leadsRes.data ?? []) as unknown as LeadRow[]).map<Lead>((l) => ({
    id: l.id,
    personId: l.person_id,
    stageId: l.stage_id,
    name: l.person?.full_name ?? 'Sem nome',
    email: l.person?.email ?? null,
    phone: l.person?.phone_e164 ?? null,
    source: l.source?.name ?? null,
    campaign: l.source_note ?? l.utm_campaign,
    planName: l.plan?.name ?? null,
    planPriceCents: l.plan?.price_cents ?? null,
    planCycle: l.plan?.billing_cycle ?? null,
    fit: l.icp_fit,
    priority: l.ai_priority ?? 0,
    stageChangedAt: l.stage_changed_at,
    lostReason: l.lost_reason,
    lastContact: lastContact.get(l.id) ?? null,
  }))

  return {
    stages: (stagesRes.data ?? []) as Stage[],
    leads,
    tasks: ((tasksRes.data ?? []) as { id: string; lead_id: string; title: string; due_date: string | null }[]).map((t) => ({
      id: t.id,
      leadId: t.lead_id,
      title: t.title,
      dueDate: t.due_date,
    })),
    insights: ((insightsRes.data ?? []) as {
      id: string
      scope: Insight['scope']
      lead_id: string | null
      stage_id: string | null
      body: string
      action_label: string | null
      details: Record<string, unknown> | null
    }[]).map((i) => ({
      id: i.id,
      scope: i.scope,
      leadId: i.lead_id,
      stageId: i.stage_id,
      body: i.body,
      actionLabel: i.action_label,
      details: i.scope === 'analysis' ? (i.details as unknown as Analysis) : null,
    })),
  }
}

export async function loadHistory(leadId: string): Promise<HistoryItem[]> {
  const { data, error } = await supabase
    .from('m_activities')
    .select('id, kind, body, metadata, created_at')
    .eq('lead_id', leadId)
    .order('created_at', { ascending: false })
  fail(error, 'o histórico')
  const labels: Record<string, string> = {
    note: 'Nota',
    message: 'Mensagem',
    call: 'Ligação',
    email: 'E-mail',
    stage_change: 'Mudança de etapa',
    system: 'Sistema',
    meeting: 'Aula / visita',
  }
  return (data ?? []).map((a) => {
    const meta = (a.metadata ?? {}) as { title?: string }
    return {
      id: a.id as string,
      kind: a.kind as string,
      title: meta.title ?? labels[a.kind as string] ?? 'Atividade',
      body: (a.body as string | null) ?? null,
      createdAt: a.created_at as string,
    }
  })
}

export async function addLead(input: {
  tenantId: string
  stageId: string
  name: string
  phone: string | null
  email: string | null
}): Promise<void> {
  const { data: person, error: personError } = await supabase
    .from('m_people')
    .insert({ tenant_id: input.tenantId, full_name: input.name, phone_e164: input.phone, email: input.email })
    .select('id')
    .single()
  if (personError) throw new Error(friendlyError(personError.message))
  const { error } = await supabase
    .from('m_leads')
    .insert({ tenant_id: input.tenantId, person_id: person.id, stage_id: input.stageId })
  if (error) throw new Error(friendlyError(error.message))
}

/** Moves a lead to another funnel stage and records it in the lead history. */
export async function moveLead(input: {
  tenantId: string
  lead: Lead
  stage: Stage
  lostReason?: string | null
}): Promise<void> {
  const { data: auth } = await supabase.auth.getUser()
  const { error } = await supabase
    .from('m_leads')
    .update({
      stage_id: input.stage.id,
      stage_changed_at: new Date().toISOString(),
      lost_reason: input.stage.kind === 'lost' ? input.lostReason ?? null : null,
    })
    .eq('id', input.lead.id)
  if (error) throw new Error(friendlyError(error.message))
  const { error: actError } = await supabase.from('m_activities').insert({
    tenant_id: input.tenantId,
    person_id: input.lead.personId,
    lead_id: input.lead.id,
    kind: 'stage_change',
    body: input.stage.kind === 'lost' && input.lostReason ? `Motivo: ${input.lostReason}` : null,
    metadata: { title: `Movido para ${input.stage.name}` },
    created_by: auth.user?.id ?? null,
  })
  if (actError) throw new Error(friendlyError(actError.message))
}

export async function addTask(input: {
  tenantId: string
  leadId: string
  personId: string
  title: string
  dueDate: string | null
}): Promise<void> {
  const { data: auth } = await supabase.auth.getUser()
  const { error } = await supabase.from('m_tasks').insert({
    tenant_id: input.tenantId,
    lead_id: input.leadId,
    person_id: input.personId,
    title: input.title,
    due_date: input.dueDate,
    origin: 'manual',
    created_by: auth.user?.id ?? null,
  })
  if (error) throw new Error(friendlyError(error.message))
}

/** Records in the lead history that a proposal was sent by e-mail. */
export async function logProposalSent(input: { tenantId: string; lead: Lead; subject: string }): Promise<void> {
  const { data: auth } = await supabase.auth.getUser()
  const { error } = await supabase.from('m_activities').insert({
    tenant_id: input.tenantId,
    person_id: input.lead.personId,
    lead_id: input.lead.id,
    kind: 'email',
    body: input.subject,
    metadata: { title: 'Proposta enviada' },
    created_by: auth.user?.id ?? null,
  })
  if (error) throw new Error(friendlyError(error.message))
}

function friendlyError(message: string): string {
  if (message.includes('m_people_tenant_id_phone_e164_key')) return 'Já existe uma pessoa com esse telefone.'
  if (message.includes('phone_e164')) return 'Telefone inválido. Use o formato +5511999998888.'
  if (message.includes('email')) return 'E-mail inválido.'
  if (message.includes('row-level security')) return 'Seu usuário não tem permissão para isso.'
  return message
}
