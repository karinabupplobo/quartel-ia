import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import type { Fit, Insight, Lead, Task } from '../lib/data'
import { daysLabel, daysSince, dueLabel, firstName, initials, phone, planPrice } from '../lib/format'
import { IconClose, IconDownload, IconHistory, IconPlus } from './icons'

const FIT_LABEL: Record<Fit, string> = { high: 'Alto', medium: 'Médio', low: 'Baixo' }
const FIT_OPTIONS: { id: Fit | 'all'; label: string }[] = [
  { id: 'all', label: 'Todos' },
  { id: 'high', label: 'Alto' },
  { id: 'medium', label: 'Médio' },
  { id: 'low', label: 'Baixo' },
]

/** Something the assistant flags about a lead (shown as the purple counter). */
export interface Note {
  kind: 'ai' | 'late' | 'today' | 'stale'
  text: string
}

export interface TableRow {
  lead: Lead
  stageName: string
  closed: boolean
  task: Task | undefined
  insight: Insight | undefined
  notes: Note[]
}

export function LeadTable({
  title,
  rows,
  showStage,
  canAdd,
  onOpenHistory,
  onAddLead,
  onAddTask,
}: {
  title: string
  rows: TableRow[]
  showStage: boolean
  canAdd: boolean
  onOpenHistory: (lead: Lead) => void
  onAddLead: (input: { name: string; phone: string | null; email: string | null }) => Promise<void>
  onAddTask: (lead: Lead, input: { title: string; dueDate: string | null }) => Promise<void>
}) {
  const [fit, setFit] = useState<Fit | 'all'>('all')
  const [source, setSource] = useState('all')
  const [openInsight, setOpenInsight] = useState<string | null>(null)
  const [taskFor, setTaskFor] = useState<string | null>(null)
  const [adding, setAdding] = useState(false)

  const sources = useMemo(
    () => Array.from(new Set(rows.map((r) => r.lead.source).filter((s): s is string => !!s))).sort(),
    [rows],
  )
  const visible = rows.filter(
    (r) => (fit === 'all' || r.lead.fit === fit) && (source === 'all' || r.lead.source === source),
  )

  // Close any popover with Escape.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        setOpenInsight(null)
        setTaskFor(null)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  function exportCsv() {
    const header = ['Nome', 'Telefone', 'E-mail', 'Etapa', 'Fonte', 'Campanha', 'Plano', 'Fit ICP', 'Dias na etapa', 'Próxima tarefa']
    const lines = visible.map((r) => [
      r.lead.name,
      phone(r.lead.phone),
      r.lead.email ?? '',
      r.stageName,
      r.lead.source ?? '',
      r.lead.campaign ?? '',
      r.lead.planName ?? '',
      r.lead.fit ? FIT_LABEL[r.lead.fit] : '',
      String(daysSince(r.lead.stageChangedAt)),
      r.task?.title ?? '',
    ])
    const csv = [header, ...lines].map((cols) => cols.map((c) => `"${c.replace(/"/g, '""')}"`).join(';')).join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `leads-${title.toLowerCase().replace(/\W+/g, '-')}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <section className="card table-card" aria-label={`Leads: ${title}`}>
      <div className="table-head">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <h2>{title}</h2>
          <span className="hint">{visible.length === 1 ? '1 lead' : `${visible.length} leads`}</span>
        </div>
        <div className="table-tools">
          <div className="segmented" role="group" aria-label="Filtrar por fit de ICP">
            <span className="segmented-label">Fit ICP</span>
            {FIT_OPTIONS.map((o) => (
              <button key={o.id} type="button" aria-pressed={fit === o.id} onClick={() => setFit(o.id)}>
                {o.label}
              </button>
            ))}
          </div>
          <label className="sr-only" htmlFor="fonte">Fonte</label>
          <select id="fonte" className="select" value={source} onChange={(e) => setSource(e.target.value)}>
            <option value="all">Fonte: todas</option>
            {sources.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
          <button type="button" className="icon-btn" aria-label="Exportar planilha (CSV)" title="Exportar planilha" onClick={exportCsv}>
            <IconDownload size={18} />
          </button>
        </div>
      </div>

      <div role="table" aria-label={title}>
        <div role="row" className="grid header">
          <span role="columnheader">Nome</span>
          <span role="columnheader">Contato</span>
          <span role="columnheader">Fonte / campanha</span>
          <span role="columnheader">Plano</span>
          <span role="columnheader">Fit ICP</span>
          <span role="columnheader">Na etapa</span>
          <span role="columnheader">Próxima tarefa</span>
          <span role="columnheader"><span className="sr-only">Histórico</span></span>
        </div>

        {visible.length === 0 && <div className="empty">Nenhum lead aqui com esses filtros.</div>}

        {visible.map(({ lead, stageName, closed, task, insight, notes }) => {
          const days = daysSince(lead.stageChangedAt)
          const stale = !closed && days >= 5
          const due = task ? dueLabel(task.dueDate) : null
          const first = firstName(lead.name)
          const insightOpen = openInsight === lead.id
          return (
            <div role="row" className="grid row" key={lead.id}>
              <div role="cell" className="person">
                <div className="avatar-wrap">
                  <span className="initials" aria-hidden="true">{initials(lead.name)}</span>
                  {notes.length > 0 && (
                    <button
                      type="button"
                      className="ai-badge"
                      aria-label={`${notes.length} ${notes.length === 1 ? 'notificação' : 'notificações'} da assistente sobre ${first}`}
                      aria-expanded={insightOpen}
                      onClick={() => {
                        setTaskFor(null)
                        setOpenInsight(insightOpen ? null : lead.id)
                      }}
                    >
                      {notes.length}
                    </button>
                  )}
                </div>
                <div className="cell-stack">
                  <span className="person-name">{lead.name}</span>
                  {showStage && <span className="sub">{stageName}</span>}
                </div>
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
                <span className={`days${stale ? ' stale' : ''}`}>{daysLabel(days)}</span>
              </div>
              <div role="cell" className="cell-stack">
                {task && due ? (
                  <>
                    <span className="strong">{task.title}</span>
                    <span className={`due ${due.tone}`}>{due.text}</span>
                  </>
                ) : closed ? (
                  <span className="hint">—</span>
                ) : (
                  <button
                    type="button"
                    className="link-btn"
                    onClick={() => {
                      setOpenInsight(null)
                      setTaskFor(taskFor === lead.id ? null : lead.id)
                    }}
                  >
                    + Criar tarefa
                  </button>
                )}
              </div>
              <div role="cell">
                <button type="button" className="icon-btn sm" aria-label={`Histórico de ${first}`} title="Histórico" onClick={() => onOpenHistory(lead)}>
                  <IconHistory size={18} />
                </button>
              </div>

              {insightOpen && notes.length > 0 && (
                <div className="popover ai" role="dialog" aria-label={`Notificações da assistente sobre ${first}`} style={{ top: 56, left: 20 }}>
                  <div className="popover-head">
                    <span className="eyebrow">Assistente IA · {first}</span>
                    <button type="button" className="close-btn" aria-label="Fechar" onClick={() => setOpenInsight(null)}>
                      <IconClose size={14} />
                    </button>
                  </div>
                  <ul className="notes">
                    {notes.map((n, i) => (
                      <li key={i}>
                        <span className={`dot${n.kind === 'late' ? ' risk' : n.kind === 'today' || n.kind === 'stale' ? ' warn' : ''}`} />
                        <span>{n.text}</span>
                      </li>
                    ))}
                  </ul>
                  <div className="actions">
                    {insight?.actionLabel && (
                      <button type="button" className="btn ai" disabled title="Ações automáticas chegam na próxima versão">
                        {insight.actionLabel}
                      </button>
                    )}
                    <button
                      type="button"
                      className="btn ghost ai"
                      onClick={() => {
                        setOpenInsight(null)
                        onOpenHistory(lead)
                      }}
                    >
                      Ver histórico
                    </button>
                  </div>
                </div>
              )}

              {taskFor === lead.id && (
                <TaskPopover
                  name={first}
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
    </section>
  )
}

function TaskPopover({
  name,
  onCancel,
  onSave,
}: {
  name: string
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
    <form className="popover" onSubmit={submit} aria-label={`Nova tarefa para ${name}`} style={{ top: 56, right: 60, width: 340 }}>
      <div className="popover-head">
        <span className="eyebrow">Nova tarefa · {name}</span>
        <button type="button" className="close-btn" aria-label="Cancelar" onClick={onCancel}>
          <IconClose size={14} />
        </button>
      </div>
      <label className="field">
        Tarefa
        <input ref={inputRef} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Ex.: Ligar para confirmar visita" />
      </label>
      <label className="field">
        Prazo
        <input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
      </label>
      {error && <span className="form-error" role="alert">{error}</span>}
      <div className="actions">
        <button type="submit" className="btn" disabled={busy}>{busy ? 'Salvando…' : 'Criar tarefa'}</button>
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
