import { useCallback, useEffect, useMemo, useState } from 'react'
import type { FunnelData, Lead, Stage, Workspace } from '../lib/data'
import { addLead, addTask, loadFunnel, logProposalSent, moveLead } from '../lib/data'
import { daysSince, dueLabel, firstName, initials } from '../lib/format'
import { AnalysisDrawer } from '../components/AnalysisDrawer'
import { Assistant } from '../components/Assistant'
import type { AssistantMessage } from '../components/Assistant'
import { HistoryDrawer } from '../components/HistoryDrawer'
import { IconImage, IconSearch } from '../components/icons'
import { LeadsView } from '../components/LeadTable'
import type { LeadRow } from '../components/LeadTable'
import { Pipeline } from '../components/Pipeline'
import type { Selection } from '../components/Pipeline'
import { Sidebar } from '../components/Sidebar'

export function FunnelPage({ workspace, onSignOut }: { workspace: Workspace; onSignOut: () => void }) {
  const [data, setData] = useState<FunnelData | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<Selection | null>(null)
  const [query, setQuery] = useState('')
  const [historyLead, setHistoryLead] = useState<Lead | null>(null)
  const [analysisLeadId, setAnalysisLeadId] = useState<string | null>(null)
  const [assistantOpen, setAssistantOpen] = useState(false)
  const [toast, setToast] = useState<{ text: string; action: string; onAction: () => void } | null>(null)

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
  const leadAnalysis = (leadId: string) => data.insights.find((i) => i.scope === 'analysis' && i.leadId === leadId && i.details)

  const allRows: LeadRow[] = data.leads
    .slice()
    .sort((a, b) => b.priority - a.priority)
    .map((lead) => {
      const stage = stageById.get(lead.stageId)
      const closed = stage?.kind !== 'open'
      const task = nextTask(lead.id)
      return { lead, stageName: stage?.name ?? '', closed, task, analysis: leadAnalysis(lead.id), missingStep: !closed && !task }
    })
  const rows = allRows.filter((r) => !q || r.lead.name.toLowerCase().includes(q))

  // What the assistant flags: open leads without a next step, late tasks,
  // leads going cold, then its suggestions for open leads.
  const messages: AssistantMessage[] = []
  for (const r of allRows.filter((x) => !x.closed)) {
    const who = firstName(r.lead.name)
    const c = r.lead.lastContact
    const contactDays = c ? daysSince(c.at) : null
    const cold = contactDays === null ? 'e ainda não foi contatado(a).' : contactDays >= 4 ? `e está sem contato há ${contactDays} dias.` : null
    if (r.missingStep) {
      messages.push({ id: `missing:${r.lead.id}`, leadId: r.lead.id, tone: 'risk', who, text: `está sem próximo passo em ${r.stageName}${cold ? ` ${cold}` : '.'} Agende uma interação.` })
      continue
    }
    if (r.task && dueLabel(r.task.dueDate).tone === 'late') {
      messages.push({ id: `late:${r.task.id}`, leadId: r.lead.id, tone: 'risk', who, text: `tem um próximo passo atrasado: ${r.task.title}.` })
    }
    if (contactDays !== null && contactDays >= 4) {
      messages.push({ id: `cold:${r.lead.id}:${c!.at}`, leadId: r.lead.id, tone: 'warn', who, text: `está sem contato há ${contactDays} dias.` })
    }
  }
  messages.sort((a, b) => (a.tone === b.tone ? 0 : a.tone === 'risk' ? -1 : 1))
  for (const r of allRows.filter((x) => !x.closed)) {
    const i = leadInsight(r.lead.id)
    if (i) messages.push({ id: `ai:${i.id}`, leadId: r.lead.id, tone: 'ai', who: firstName(r.lead.name), text: i.body.replace(/^(A|O) \S+ /, '') })
  }

  const firstStage = data.stages[0]
  const missingIn = allRows.filter((r) => r.missingStep && (selected === 'all' || r.lead.stageId === selected))
  const missingNote =
    missingIn.length === 0
      ? ''
      : missingIn.length === 1
        ? ` Atenção: ${firstName(missingIn[0].lead.name)} está sem próximo passo.`
        : ` Atenção: ${missingIn.length} leads estão sem próximo passo (${missingIn.map((r) => firstName(r.lead.name)).join(', ')}).`
  const summary =
    (selected === 'all'
      ? data.insights.find((i) => i.scope === 'pipeline')
      : data.insights.find((i) => i.scope === 'stage' && i.stageId === selected)
    )?.body ?? null
  // Stage summaries already name the leads without a next step; the pipeline one gets the live count.
  const assistantMessage = summary ? summary + (selected === 'all' ? missingNote : '') : missingNote.trim() || null

  const analysisRow = analysisLeadId ? allRows.find((r) => r.lead.id === analysisLeadId) : undefined
  const openLead = (leadId: string) => {
    const row = allRows.find((r) => r.lead.id === leadId)
    if (!row) return
    if (row.analysis) setAnalysisLeadId(leadId)
    else setHistoryLead(row.lead)
  }

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
          onOpenAnalysis={(lead) => setAnalysisLeadId(lead.id)}
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
            setToast({ text: `${firstName(lead.name)} foi para ${stage.name}`, action: 'Ver etapa', onAction: () => setSelected(stage.id) })
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

      {analysisRow?.analysis?.details && (
        <AnalysisDrawer
          lead={analysisRow.lead}
          stageName={analysisRow.stageName}
          analysis={analysisRow.analysis.details}
          task={analysisRow.task}
          onClose={() => setAnalysisLeadId(null)}
          onScheduleStep={async (title) => {
            const today = new Date()
            const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
            await addTask({ tenantId: workspace.tenantId, leadId: analysisRow.lead.id, personId: analysisRow.lead.personId, title, dueDate: iso })
            await refresh()
          }}
          onProposalSent={async (subject) => {
            const lead = analysisRow.lead
            await logProposalSent({ tenantId: workspace.tenantId, lead, subject })
            await refresh()
            const current = stageById.get(lead.stageId)
            const next = data.stages.find((s) => current && s.kind === 'open' && s.position === current.position + 1)
            setToast(
              next
                ? {
                    text: `Proposta de ${firstName(lead.name)} registrada no histórico`,
                    action: `Mover para ${next.name}`,
                    onAction: () => {
                      void moveLead({ tenantId: workspace.tenantId, lead, stage: next }).then(refresh)
                    },
                  }
                : { text: `Proposta de ${firstName(lead.name)} registrada no histórico`, action: 'Ok', onAction: () => {} },
            )
          }}
        />
      )}

      {toast && (
        <div className="toast" role="status">
          {toast.text}
          <button type="button" onClick={() => { toast.onAction(); setToast(null) }}>{toast.action}</button>
        </div>
      )}

      <Assistant
        open={assistantOpen}
        onToggle={() => setAssistantOpen((o) => !o)}
        greetingName={workspace.userFirstName}
        message={assistantMessage}
        icpSummary={workspace.icpSummary}
        messages={messages}
        onOpenLead={openLead}
      />
    </div>
  )
}
