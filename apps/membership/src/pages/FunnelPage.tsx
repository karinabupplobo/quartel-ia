import { useCallback, useEffect, useMemo, useState } from 'react'
import type { FunnelData, Lead, Stage, Workspace } from '../lib/data'
import { addLead, addTask, loadFunnel, moveLead } from '../lib/data'
import { daysLabel, daysSince, dueLabel, firstName, initials } from '../lib/format'
import { Assistant } from '../components/Assistant'
import { HistoryDrawer } from '../components/HistoryDrawer'
import { IconImage, IconSearch } from '../components/icons'
import { LeadsView } from '../components/LeadTable'
import type { LeadRow, Note } from '../components/LeadTable'
import { Pipeline } from '../components/Pipeline'
import type { Selection } from '../components/Pipeline'
import { Sidebar } from '../components/Sidebar'

export function FunnelPage({ workspace, onSignOut }: { workspace: Workspace; onSignOut: () => void }) {
  const [data, setData] = useState<FunnelData | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<Selection | null>(null)
  const [query, setQuery] = useState('')
  const [historyLead, setHistoryLead] = useState<Lead | null>(null)
  const [assistantOpen, setAssistantOpen] = useState(false)
  const [toast, setToast] = useState<{ text: string; stageId: string } | null>(null)

  useEffect(() => {
    if (!toast) return
    const t = window.setTimeout(() => setToast(null), 5000)
    return () => window.clearTimeout(t)
  }, [toast])

  const refresh = useCallback(async () => {
    try {
      const d = await loadFunnel(workspace.tenantId)
      setData(d)
      setSelected((s) => s ?? d.stages[0]?.id ?? 'all')
    } catch (e) {
      setError((e as Error).message)
    }
  }, [workspace.tenantId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const stageById = useMemo(() => new Map((data?.stages ?? []).map((s) => [s.id, s])), [data])
  const wonThisMonth = useMemo(() => {
    if (!data) return 0
    return data.leads.filter((l) => stageById.get(l.stageId)?.kind === 'won' && daysSince(l.stageChangedAt) <= 30).length
  }, [data, stageById])

  if (error) return <div className="state" role="alert">{error}</div>
  if (!data || !selected) return <div className="state">Carregando funil…</div>

  const q = query.trim().toLowerCase()
  const nextTask = (leadId: string) => data.tasks.find((t) => t.leadId === leadId)
  const leadInsight = (leadId: string) => data.insights.find((i) => i.scope === 'lead' && i.leadId === leadId)

  const rows: LeadRow[] = data.leads
    .filter((l) => !q || l.name.toLowerCase().includes(q))
    .sort((a, b) => b.priority - a.priority)
    .map((lead) => {
      const stage = stageById.get(lead.stageId)
      const closed = stage?.kind !== 'open'
      const task = nextTask(lead.id)
      const insight = leadInsight(lead.id)
      // The assistant's notifications for this lead: its comment, plus task and stall alerts.
      const notes: Note[] = []
      if (insight) notes.push({ kind: 'ai', text: insight.body })
      if (task) {
        const due = dueLabel(task.dueDate)
        if (due.tone === 'late') notes.push({ kind: 'late', text: `Tarefa atrasada: ${task.title}.` })
        if (due.tone === 'today') notes.push({ kind: 'today', text: `Tarefa para hoje: ${task.title}.` })
      }
      const days = daysSince(lead.stageChangedAt)
      if (!closed && days >= 5) notes.push({ kind: 'stale', text: `Parado há ${daysLabel(days)} em ${stage?.name ?? 'esta etapa'}.` })
      return { lead, stageName: stage?.name ?? '', closed, task, insight, notes }
    })

  const firstStage = data.stages[0]
  const assistantMessage =
    (selected === 'all'
      ? data.insights.find((i) => i.scope === 'pipeline')
      : data.insights.find((i) => i.scope === 'stage' && i.stageId === selected)
    )?.body ?? null

  return (
    <div className="shell">
      <Sidebar userInitials={initials(workspace.userFirstName || workspace.tenantName)} onSignOut={onSignOut} />
      <main className="main">
        <header className="topbar">
          <div className="logo" aria-label="Logo da empresa">
            <span className="logo-mark"><IconImage size={20} /></span>
            <span className="logo-word">seu logo<span>.</span></span>
          </div>
          <label className="search">
            <IconSearch size={18} />
            <span className="sr-only">Buscar lead</span>
            <input type="search" placeholder="Buscar lead…" value={query} onChange={(e) => setQuery(e.target.value)} />
          </label>
        </header>

        <Pipeline
          stages={data.stages}
          leads={data.leads}
          selected={selected}
          onSelect={setSelected}
          closeGoal={workspace.closeGoal}
          wonThisMonth={wonThisMonth}
        />

        <LeadsView
          rows={rows}
          stages={data.stages}
          selected={selected}
          canAdd={!!firstStage && (selected === 'all' || selected === firstStage.id)}
          onOpenHistory={setHistoryLead}
          onAddLead={async (input) => {
            if (!firstStage) return
            await addLead({ tenantId: workspace.tenantId, stageId: firstStage.id, ...input })
            await refresh()
          }}
          onAddTask={async (lead, input) => {
            await addTask({ tenantId: workspace.tenantId, leadId: lead.id, personId: lead.personId, ...input })
            await refresh()
          }}
          onMove={async (lead: Lead, stage: Stage, lostReason?: string | null) => {
            await moveLead({ tenantId: workspace.tenantId, lead, stage, lostReason })
            await refresh()
            setToast({ text: `${firstName(lead.name)} foi para ${stage.name}`, stageId: stage.id })
          }}
        />
      </main>

      {historyLead && (
        <HistoryDrawer
          lead={historyLead}
          stageName={stageById.get(historyLead.stageId)?.name ?? ''}
          insight={leadInsight(historyLead.id)}
          onClose={() => setHistoryLead(null)}
        />
      )}

      {toast && (
        <div className="toast" role="status">
          {toast.text}
          <button type="button" onClick={() => { setSelected(toast.stageId); setToast(null) }}>Ver etapa</button>
        </div>
      )}

      <Assistant
        open={assistantOpen}
        onToggle={() => setAssistantOpen((o) => !o)}
        greetingName={workspace.userFirstName}
        message={assistantMessage}
        icpSummary={workspace.icpSummary}
      />
    </div>
  )
}
