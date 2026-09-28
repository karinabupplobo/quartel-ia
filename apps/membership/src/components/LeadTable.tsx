import { useEffect, useMemo, useRef, useState } from 'react'
import type { CSSProperties, DragEvent, FormEvent } from 'react'
import type { Fit, Insight, Lead, Stage, Task } from '../lib/data'
import { CONTACT_LABEL } from '../lib/data'
import { agoLabel, daysLabel, daysSince, dueLabel, firstName, initials, phone, planPrice } from '../lib/format'
import { AssistantAvatar, IconClose, IconDownload, IconFilter, IconHistory, IconPlus } from './icons'

const FIT_LABEL: Record<Fit, string> = { high: 'Alto', medium: 'Médio', low: 'Baixo' }

export interface LeadRow {
  lead: Lead
  stageName: string
  closed: boolean
  task: Task | undefined
  /** The assistant's analysis (Proposta and Negociação). */
  analysis: Insight | undefined
  /** Open lead with nothing scheduled. */
  missingStep: boolean
}

/** Days without contact after which an open lead is flagged. */
const CONTACT_STALE_DAYS = 4

type ViewMode = 'sheet' | 'kanban'

interface Filters {
  text: string
  stage: string
  source: string
  campaign: string
  plan: string
  fit: string
  days: string
  contact: string
  task: string
}

const EMPTY: Filters = { text: '', stage: '', source: '', campaign: '', plan: '', fit: '', days: '', contact: '', task: '' }

const DAYS_OPTIONS: Record<string, string> = { '0-2': 'Até 2 dias', '3-4': '3 a 4 dias', '5+': '5 dias ou mais' }
const CONTACT_OPTIONS: Record<string, string> = { '0-2': 'Até 2 dias', '3-4': '3 a 4 dias', '5+': '5 dias ou mais', never: 'Nunca' }
const TASK_OPTIONS: Record<string, string> = {
  late: 'Atrasado',
  today: 'Para hoje',
  any: 'Agendado',
  none: 'Sem próximo passo',
}

function matches(r: LeadRow, f: Filters): boolean {
  const l = r.lead
  if (f.text) {
    const q = f.text.toLowerCase()
    const hay = [l.name, l.email ?? '', l.phone ?? '', phone(l.phone)].join(' ').toLowerCase()
    if (!hay.includes(q)) return false
  }
  if (f.stage && l.stageId !== f.stage) return false
  if (f.source && l.source !== f.source) return false
  if (f.campaign && l.campaign !== f.campaign) return false
  if (f.plan && l.planName !== f.plan) return false
  if (f.fit && l.fit !== f.fit) return false
  if (f.days) {
    const d = daysSince(l.stageChangedAt)
    if (f.days === '0-2' && d > 2) return false
    if (f.days === '3-4' && (d < 3 || d > 4)) return false
    if (f.days === '5+' && d < 5) return false
  }
  if (f.contact) {
    const d = l.lastContact ? daysSince(l.lastContact.at) : null
    if (f.contact === 'never' && d !== null) return false
    if (f.contact !== 'never' && d === null) return false
    if (d !== null && f.contact === '0-2' && d > 2) return false
    if (d !== null && f.contact === '3-4' && (d < 3 || d > 4)) return false
    if (d !== null && f.contact === '5+' && d < 5) return false
  }
  if (f.task) {
    const tone = r.task ? dueLabel(r.task.dueDate).tone : null
    if (f.task === 'late' && tone !== 'late') return false
    if (f.task === 'today' && tone !== 'today') return false
    if (f.task === 'any' && !r.task) return false
    if (f.task === 'none' && !r.missingStep) return false
  }
  return true
}

function uniq(values: (string | null)[]): string[] {
  return Array.from(new Set(values.filter((v): v is string => !!v))).sort((a, b) => a.localeCompare(b, 'pt-BR'))
}

export function LeadsView({
  rows,
  stages,
  selected,
  canAdd,
  onOpenHistory,
  onOpenAnalysis,
  onAddLead,
  onAddTask,
  onMove,
}: {
  rows: LeadRow[]
  stages: Stage[]
  selected: string | 'all'
  canAdd: boolean
  onOpenHistory: (lead: Lead) => void
  onOpenAnalysis: (lead: Lead) => void
  onAddLead: (input: { name: string; phone: string | null; email: string | null }) => Promise<void>
  onAddTask: (lead: Lead, input: { title: string; dueDate: string | null }) => Promise<void>
  onMove: (lead: Lead, stage: Stage, lostReason?: string | null) => Promise<void>
}) {
  const [mode, setMode] = useState<ViewMode>('sheet')
  const [filters, setFilters] = useState<Filters>(EMPTY)
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [taskFor, setTaskFor] = useState<string | null>(null)
  const [adding, setAdding] = useState(false)
  const [lostFor, setLostFor] = useState<{ lead: Lead; stage: Stage } | null>(null)
  const [moveError, setMoveError] = useState<string | null>(null)

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') setTaskFor(null)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const options = useMemo(
    () => ({
      source: uniq(rows.map((r) => r.lead.source)),
      campaign: uniq(rows.map((r) => r.lead.campaign)),
      plan: uniq(rows.map((r) => r.lead.planName)),
    }),
    [rows],
  )

  const stageName = (id: string) => stages.find((s) => s.id === id)?.name ?? ''
  const filtered = rows.filter((r) => matches(r, filters))
  // The sheet follows the funnel selection; the kanban always shows every stage.
  const sheetRows = selected === 'all' ? filtered : filtered.filter((r) => r.lead.stageId === selected)
  const selectedName = selected === 'all' ? 'Todos os leads' : stageName(selected)
  const count = mode === 'sheet' ? sheetRows.length : filtered.length

  const active = (Object.keys(EMPTY) as (keyof Filters)[]).filter((k) => filters[k])
  const chipLabel = (k: keyof Filters): string => {
    const v = filters[k]
    switch (k) {
      case 'text': return `Contém “${v}”`
      case 'stage': return `Etapa: ${stageName(v)}`
      case 'source': return `Fonte: ${v}`
      case 'campaign': return `Campanha: ${v}`
      case 'plan': return `Plano: ${v}`
      case 'fit': return `Fit: ${FIT_LABEL[v as Fit]}`
      case 'days': return `Na etapa: ${DAYS_OPTIONS[v]}`
      case 'contact': return `Último contato: ${CONTACT_OPTIONS[v]}`
      case 'task': return `Próximo passo: ${TASK_OPTIONS[v]}`
    }
  }

  async function requestMove(lead: Lead, stageId: string) {
    const stage = stages.find((s) => s.id === stageId)
    if (!stage || stage.id === lead.stageId) return
    setMoveError(null)
    if (stage.kind === 'lost') {
      setLostFor({ lead, stage })
      return
    }
    try {
      await onMove(lead, stage)
    } catch (e) {
      setMoveError((e as Error).message)
    }
  }

  function exportCsv() {
    const list = mode === 'sheet' ? sheetRows : filtered
    const header = ['Nome', 'Telefone', 'E-mail', 'Etapa', 'Fonte', 'Campanha', 'Plano', 'Fit', 'Dias na etapa', 'Último contato', 'Próximo passo']
    const lines = list.map((r) => [
      r.lead.name,
      phone(r.lead.phone),
      r.lead.email ?? '',
      r.stageName,
      r.lead.source ?? '',
      r.lead.campaign ?? '',
      r.lead.planName ?? '',
      r.lead.fit ? FIT_LABEL[r.lead.fit] : '',
      String(daysSince(r.lead.stageChangedAt)),
      r.lead.lastContact ? `${agoLabel(r.lead.lastContact.at)} (${CONTACT_LABEL[r.lead.lastContact.kind] ?? ''})` : 'Nunca',
      r.task?.title ?? (r.missingStep ? 'Sem próximo passo' : ''),
    ])
    const csv = [header, ...lines].map((cols) => cols.map((c) => `"${c.replace(/"/g, '""')}"`).join(';')).join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `leads-${selectedName.toLowerCase().replace(/\W+/g, '-')}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const set = (k: keyof Filters) => (v: string) => setFilters((f) => ({ ...f, [k]: v }))

  const shared: SharedProps = {
    stages,
    taskFor,
    setTaskFor,
    onOpenHistory,
    onOpenAnalysis,
    onAddTask,
    onMove: requestMove,
  }

  return (
    <section className="card table-card" aria-label={`Leads: ${selectedName}`}>
      <div className="table-head">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <h2>{mode === 'sheet' ? selectedName : 'Todas as etapas'}</h2>
          <span className="hint">{count === 1 ? '1 lead' : `${count} leads`}</span>
        </div>
        <div className="table-tools">
          <button
            type="button"
            className={`tool-btn${filtersOpen || active.length ? ' on' : ''}`}
            aria-expanded={filtersOpen}
            aria-controls="filtros"
            onClick={() => setFiltersOpen((o) => !o)}
          >
            <IconFilter size={16} />
            Filtros
            {active.length > 0 && <span className="count-pill">{active.length}</span>}
          </button>
          <div className="segmented" role="group" aria-label="Formato">
            <span className="segmented-label">Formato</span>
            <button type="button" aria-pressed={mode === 'sheet'} onClick={() => setMode('sheet')}>Planilha</button>
            <button type="button" aria-pressed={mode === 'kanban'} onClick={() => setMode('kanban')}>Kanban</button>
          </div>
          <button type="button" className="icon-btn" aria-label="Exportar (CSV)" title="Exportar" onClick={exportCsv}>
            <IconDownload size={18} />
          </button>
        </div>
      </div>

      {filtersOpen && (
        <div id="filtros" className="filter-panel" role="region" aria-label="Filtros">
          <label className="field">
            Nome, telefone ou e-mail
            <input value={filters.text} onChange={(e) => set('text')(e.target.value)} placeholder="Digite para filtrar" />
          </label>
          {mode === 'sheet' && selected === 'all' && (
            <FilterSelect label="Etapa" value={filters.stage} onChange={set('stage')} options={stages.map((s) => [s.id, s.name])} />
          )}
          <FilterSelect label="Fonte" value={filters.source} onChange={set('source')} options={options.source.map((v) => [v, v])} />
          <FilterSelect label="Campanha" value={filters.campaign} onChange={set('campaign')} options={options.campaign.map((v) => [v, v])} />
          <FilterSelect label="Plano" value={filters.plan} onChange={set('plan')} options={options.plan.map((v) => [v, v])} />
          <FilterSelect label="Fit" value={filters.fit} onChange={set('fit')} options={Object.entries(FIT_LABEL)} />
          <FilterSelect label="Na etapa" value={filters.days} onChange={set('days')} options={Object.entries(DAYS_OPTIONS)} />
          <FilterSelect label="Último contato" value={filters.contact} onChange={set('contact')} options={Object.entries(CONTACT_OPTIONS)} />
          <FilterSelect label="Próximo passo" value={filters.task} onChange={set('task')} options={Object.entries(TASK_OPTIONS)} />
        </div>
      )}

      {active.length > 0 && (
        <div className="chips" aria-label="Filtros ativos">
          {active.map((k) => (
            <span key={k} className="chip">
              {chipLabel(k)}
              <button type="button" aria-label={`Remover filtro ${chipLabel(k)}`} onClick={() => set(k)('')}>
                <IconClose size={12} />
              </button>
            </span>
          ))}
          <button type="button" className="link-btn" onClick={() => setFilters(EMPTY)}>Limpar filtros</button>
        </div>
      )}

      {moveError && <p className="form-error" role="alert" style={{ margin: '0 20px 12px' }}>{moveError}</p>}

      {mode === 'sheet' ? (
        <div role="table" aria-label={selectedName}>
          <div role="row" className="grid header">
            <span role="columnheader">Nome</span>
            <span role="columnheader">Etapa</span>
            <span role="columnheader">Contato</span>
            <span role="columnheader">Fonte / campanha</span>
            <span role="columnheader">Plano</span>
            <span role="columnheader">Fit</span>
            <span role="columnheader">Último contato</span>
            <span role="columnheader">Próximo passo</span>
            <span role="columnheader"><span className="sr-only">Histórico</span></span>
          </div>

          {sheetRows.length === 0 && <div className="empty">Nenhum lead aqui com esses filtros.</div>}

          {sheetRows.map((row) => {
            const { lead, closed } = row
            const days = daysSince(lead.stageChangedAt)
            const first = firstName(lead.name)
            return (
              <div role="row" className={`grid row${row.missingStep ? ' flagged' : ''}`} key={lead.id}>
                <div role="cell" className="person">
                  <span className="initials" aria-hidden="true">{initials(lead.name)}</span>
                  <div className="cell-stack" style={{ gap: 5, alignItems: 'flex-start' }}>
                    <span className="person-name">{lead.name}</span>
                    {row.analysis && <AnalysisButton lead={lead} onOpen={onOpenAnalysis} />}
                  </div>
                </div>
                <div role="cell" className="cell-stack" style={{ gap: 5, alignItems: 'flex-start' }}>
                  <StageSelect lead={lead} stages={stages} onMove={requestMove} />
                  <span className={`days${!closed && days >= 5 ? ' stale' : ''}`} title="Tempo nesta etapa">há {daysLabel(days)}</span>
                </div>
                <div role="cell" className="cell-stack">
                  <span className="mono" style={{ fontSize: 12 }}>{phone(lead.phone) || '—'}</span>
                  <span className="sub">{lead.email ?? ''}</span>
                </div>
                <div role="cell" className="cell-stack">
                  <span className="strong">{lead.source ?? '—'}</span>
                  {lead.campaign && <span className="sub">{lead.campaign}</span>}
                </div>
                <div role="cell" className="cell-stack">
                  <span className="strong">{lead.planName ?? '—'}</span>
                  <span className="sub mono">{planPrice(lead.planPriceCents, lead.planCycle)}</span>
                </div>
                <div role="cell">
                  {lead.fit ? <span className={`tag ${lead.fit}`}>{FIT_LABEL[lead.fit]}</span> : <span className="hint">—</span>}
                </div>
                <div role="cell">
                  <LastContact row={row} />
                </div>
                <div role="cell">
                  <NextStep row={row} {...shared} />
                </div>
                <div role="cell">
                  <button type="button" className="icon-btn sm" aria-label={`Histórico de ${first}`} title="Histórico" onClick={() => onOpenHistory(lead)}>
                    <IconHistory size={18} />
                  </button>
                </div>

                {taskFor === lead.id && (
                  <TaskPopover
                    name={first}
                    style={{ top: 56, right: 60 }}
                    onCancel={() => setTaskFor(null)}
                    onSave={async (input) => {
                      await onAddTask(lead, input)
                      setTaskFor(null)
                    }}
                  />
                )}
              </div>
            )
          })}

          {canAdd && !adding && (
            <button type="button" className="add-row" onClick={() => setAdding(true)} style={{ width: '100%' }}>
              <IconPlus size={16} />
              Adicionar lead
            </button>
          )}
          {canAdd && adding && <AddLeadForm onCancel={() => setAdding(false)} onSave={async (input) => { await onAddLead(input); setAdding(false) }} />}
        </div>
      ) : (
        <Kanban rows={filtered} selected={selected} {...shared} />
      )}

      {lostFor && (
        <LostDialog
          name={firstName(lostFor.lead.name)}
          onCancel={() => setLostFor(null)}
          onConfirm={async (reason) => {
            await onMove(lostFor.lead, lostFor.stage, reason)
            setLostFor(null)
          }}
        />
      )}
    </section>
  )
}

// ---- Pieces shared by the sheet and the kanban -------------------------------------

interface SharedProps {
  stages: Stage[]
  taskFor: string | null
  setTaskFor: (id: string | null) => void
  onOpenHistory: (lead: Lead) => void
  onOpenAnalysis: (lead: Lead) => void
  onAddTask: (lead: Lead, input: { title: string; dueDate: string | null }) => Promise<void>
  onMove: (lead: Lead, stageId: string) => void
}

function AnalysisButton({ lead, onOpen }: { lead: Lead; onOpen: (lead: Lead) => void }) {
  return (
    <button type="button" className="analysis-btn" onClick={() => onOpen(lead)} aria-label={`Análise IA de ${firstName(lead.name)}`}>
      <AssistantAvatar size={20} />
      Análise IA
    </button>
  )
}

function LastContact({ row }: { row: LeadRow }) {
  const c = row.lead.lastContact
  if (!c) return <span className={row.closed ? 'hint' : 'due late'}>{row.closed ? '—' : 'Nunca contatado'}</span>
  const d = daysSince(c.at)
  const stale = !row.closed && d >= CONTACT_STALE_DAYS
  return (
    <div className="cell-stack">
      <span className={stale ? 'due late' : 'strong'}>{agoLabel(c.at)}</span>
      <span className="sub">{CONTACT_LABEL[c.kind] ?? c.kind}</span>
    </div>
  )
}

function NextStep({ row, setTaskFor, taskFor }: { row: LeadRow } & Pick<SharedProps, 'taskFor' | 'setTaskFor'>) {
  const { lead, task, closed } = row
  if (task) {
    const due = dueLabel(task.dueDate)
    return (
      <div className="cell-stack">
        <span className="strong">{task.title}</span>
        <span className={`due ${due.tone}`}>{due.text}</span>
      </div>
    )
  }
  if (closed) return <span className="hint">—</span>
  return (
    <div className="missing-step">
      <span className="missing-label">Sem próximo passo</span>
      <button type="button" className="link-btn" onClick={() => setTaskFor(taskFor === lead.id ? null : lead.id)}>
        + Agendar
      </button>
    </div>
  )
}

function StageSelect({ lead, stages, onMove, compact }: { lead: Lead; stages: Stage[]; onMove: (lead: Lead, stageId: string) => void; compact?: boolean }) {
  const current = stages.find((s) => s.id === lead.stageId)
  return (
    <label className={`stage-select ${current?.kind ?? 'open'}${compact ? ' compact' : ''}`}>
      <span className="sr-only">Mover {lead.name} para outra etapa</span>
      <select value={lead.stageId} onChange={(e) => onMove(lead, e.target.value)}>
        {stages.map((s) => (
          <option key={s.id} value={s.id}>{s.name}</option>
        ))}
      </select>
    </label>
  )
}

function FilterSelect({ label, value, onChange, options }: { label: string; value: string; onChange: (v: string) => void; options: [string, string][] }) {
  return (
    <label className="field">
      {label}
      <select className="select" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Todos</option>
        {options.map(([v, text]) => (
          <option key={v} value={v}>{text}</option>
        ))}
      </select>
    </label>
  )
}

// ---- Kanban -------------------------------------------------------------------------

function Kanban({ rows, selected, ...shared }: { rows: LeadRow[]; selected: string | 'all' } & SharedProps) {
  const { stages, taskFor, setTaskFor, onOpenHistory, onOpenAnalysis, onAddTask, onMove } = shared
  const [dragging, setDragging] = useState<string | null>(null)
  const [over, setOver] = useState<string | null>(null)
  const colRefs = useRef<Record<string, HTMLDivElement | null>>({})

  useEffect(() => {
    if (selected !== 'all') colRefs.current[selected]?.scrollIntoView({ behavior: 'smooth', inline: 'nearest', block: 'nearest' })
  }, [selected])

  function drop(e: DragEvent, stageId: string) {
    e.preventDefault()
    const id = e.dataTransfer.getData('text/plain')
    setOver(null)
    setDragging(null)
    const row = rows.find((r) => r.lead.id === id)
    if (row) onMove(row.lead, stageId)
  }

  return (
    <div className="kanban" role="list" aria-label="Kanban por etapa">
      {stages.map((stage) => {
        const cards = rows.filter((r) => r.lead.stageId === stage.id)
        return (
          <div
            key={stage.id}
            ref={(el) => {
              colRefs.current[stage.id] = el
            }}
            role="listitem"
            className={`kcol ${stage.kind}${selected === stage.id ? ' focus' : ''}${over === stage.id ? ' over' : ''}`}
            onDragOver={(e) => {
              if (!dragging) return
              e.preventDefault()
              setOver(stage.id)
            }}
            onDragLeave={() => setOver((o) => (o === stage.id ? null : o))}
            onDrop={(e) => drop(e, stage.id)}
          >
            <div className="kcol-head">
              <span>{stage.name}</span>
              <span className="count-pill neutral">{cards.length}</span>
            </div>
            {cards.length === 0 && <div className="kempty">Arraste um lead para cá</div>}
            {cards.map((row) => {
              const { lead, closed } = row
              const days = daysSince(lead.stageChangedAt)
              const first = firstName(lead.name)
              return (
                <article
                  key={lead.id}
                  className={`kcard${dragging === lead.id ? ' dragging' : ''}${row.missingStep ? ' flagged' : ''}`}
                  draggable
                  onDragStart={(e) => {
                    e.dataTransfer.setData('text/plain', lead.id)
                    e.dataTransfer.effectAllowed = 'move'
                    setDragging(lead.id)
                  }}
                  onDragEnd={() => {
                    setDragging(null)
                    setOver(null)
                  }}
                >
                  <div className="kcard-top">
                    <span className="initials" aria-hidden="true">{initials(lead.name)}</span>
                    <div className="cell-stack" style={{ flexGrow: 1 }}>
                      <span className="person-name" style={{ fontSize: 13 }}>{lead.name}</span>
                      <span className="sub">{lead.source ?? '—'}</span>
                    </div>
                    <button type="button" className="icon-btn sm" style={{ width: 30, height: 30 }} aria-label={`Histórico de ${first}`} title="Histórico" onClick={() => onOpenHistory(lead)}>
                      <IconHistory size={15} />
                    </button>
                  </div>
                  <div className="kcard-meta">
                    {lead.fit && <span className={`tag ${lead.fit}`}>{FIT_LABEL[lead.fit]}</span>}
                    <span className="sub">{lead.planName ?? ''}</span>
                    <span className={`days${!closed && days >= 5 ? ' stale' : ''}`} style={{ marginLeft: 'auto' }}>{daysLabel(days)}</span>
                  </div>
                  {!closed && (
                    <div className="kcard-contact">
                      <span className="hint" style={{ fontSize: 11 }}>Último contato</span>
                      <LastContactInline row={row} />
                    </div>
                  )}
                  {!closed || row.task ? (
                    <div className={`kcard-task${row.missingStep ? ' missing' : ''}`}>
                      <NextStep row={row} taskFor={taskFor} setTaskFor={setTaskFor} />
                    </div>
                  ) : null}
                  {row.analysis && <AnalysisButton lead={lead} onOpen={onOpenAnalysis} />}
                  <StageSelect lead={lead} stages={stages} onMove={onMove} compact />
                  {taskFor === lead.id && (
                    <TaskPopover
                      name={first}
                      style={{ top: 48, left: 8, width: 300 }}
                      onCancel={() => setTaskFor(null)}
                      onSave={async (input) => {
                        await onAddTask(lead, input)
                        setTaskFor(null)
                      }}
                    />
                  )}
                </article>
              )
            })}
          </div>
        )
      })}
    </div>
  )
}

function LastContactInline({ row }: { row: LeadRow }) {
  const c = row.lead.lastContact
  if (!c) return <span className={row.closed ? 'hint' : 'due late'} style={{ fontSize: 12 }}>{row.closed ? '—' : 'Nunca'}</span>
  const stale = !row.closed && daysSince(c.at) >= CONTACT_STALE_DAYS
  return (
    <span className={stale ? 'due late' : 'strong'} style={{ fontSize: 12 }}>
      {agoLabel(c.at)} · {CONTACT_LABEL[c.kind] ?? c.kind}
    </span>
  )
}

// ---- Dialogs & forms ------------------------------------------------------------------

function LostDialog({ name, onCancel, onConfirm }: { name: string; onCancel: () => void; onConfirm: (reason: string | null) => Promise<void> }) {
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const ref = useRef<HTMLInputElement>(null)
  useEffect(() => ref.current?.focus(), [])

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await onConfirm(reason.trim() || null)
    } catch (err) {
      setError((err as Error).message)
      setBusy(false)
    }
  }

  return (
    <>
      <button type="button" className="scrim" aria-label="Cancelar" onClick={onCancel} />
      <form className="dialog" role="dialog" aria-modal="true" aria-label={`Marcar ${name} como perdido`} onSubmit={submit}>
        <div className="popover-head">
          <span className="eyebrow">Marcar {name} como perdido</span>
          <button type="button" className="close-btn" aria-label="Cancelar" onClick={onCancel}>
            <IconClose size={14} />
          </button>
        </div>
        <label className="field">
          Motivo da perda
          <input ref={ref} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Ex.: Achou caro, mora longe…" />
        </label>
        {error && <span className="form-error" role="alert">{error}</span>}
        <div className="actions">
          <button type="submit" className="btn danger" disabled={busy}>{busy ? 'Salvando…' : 'Marcar como perdido'}</button>
          <button type="button" className="btn ghost" onClick={onCancel}>Cancelar</button>
        </div>
      </form>
    </>
  )
}

function TaskPopover({
  name,
  style,
  onCancel,
  onSave,
}: {
  name: string
  style: CSSProperties
  onCancel: () => void
  onSave: (input: { title: string; dueDate: string | null }) => Promise<void>
}) {
  const [title, setTitle] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  useEffect(() => inputRef.current?.focus(), [])

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!title.trim()) return setError('Dê um título para a tarefa.')
    setBusy(true)
    setError(null)
    try {
      await onSave({ title: title.trim(), dueDate: dueDate || null })
    } catch (err) {
      setError((err as Error).message)
      setBusy(false)
    }
  }

  return (
    <form className="popover" onSubmit={submit} aria-label={`Nova tarefa para ${name}`} style={{ width: 340, ...style }}>
      <div className="popover-head">
        <span className="eyebrow">Próximo passo · {name}</span>
        <button type="button" className="close-btn" aria-label="Cancelar" onClick={onCancel}>
          <IconClose size={14} />
        </button>
      </div>
      <label className="field">
        Tarefa
        <input ref={inputRef} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Ex.: Ligar para agendar aula experimental" />
      </label>
      <label className="field">
        Prazo
        <input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
      </label>
      {error && <span className="form-error" role="alert">{error}</span>}
      <div className="actions">
        <button type="submit" className="btn" disabled={busy}>{busy ? 'Salvando…' : 'Agendar'}</button>
      </div>
    </form>
  )
}

function AddLeadForm({
  onCancel,
  onSave,
}: {
  onCancel: () => void
  onSave: (input: { name: string; phone: string | null; email: string | null }) => Promise<void>
}) {
  const [name, setName] = useState('')
  const [tel, setTel] = useState('')
  const [email, setEmail] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const nameRef = useRef<HTMLInputElement>(null)
  useEffect(() => nameRef.current?.focus(), [])

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!name.trim()) return setError('Informe o nome.')
    const digits = tel.replace(/\D/g, '')
    const e164 = digits ? (digits.startsWith('55') ? `+${digits}` : `+55${digits}`) : null
    setBusy(true)
    setError(null)
    try {
      await onSave({ name: name.trim(), phone: e164, email: email.trim() || null })
    } catch (err) {
      setError((err as Error).message)
      setBusy(false)
    }
  }

  return (
    <form className="inline-form" onSubmit={submit} aria-label="Adicionar lead">
      <div className="fields">
        <label className="field">
          Nome
          <input ref={nameRef} value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome completo" />
        </label>
        <label className="field">
          Telefone
          <input value={tel} onChange={(e) => setTel(e.target.value)} placeholder="11 99999-8888" inputMode="tel" />
        </label>
        <label className="field">
          E-mail
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="nome@email.com" />
        </label>
        <button type="submit" className="btn" disabled={busy} style={{ height: 38 }}>{busy ? 'Salvando…' : 'Adicionar'}</button>
        <button type="button" className="btn ghost" onClick={onCancel} style={{ height: 38 }}>Cancelar</button>
      </div>
      {error && <span className="form-error" role="alert">{error}</span>}
      <span className="notice">O lead entra na etapa Lead.</span>
    </form>
  )
}
