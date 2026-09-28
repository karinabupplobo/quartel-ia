import type { CSSProperties } from 'react'
import type { Lead, Stage } from '../lib/data'
import { brl } from '../lib/format'

export type Selection = string | 'all'

// Funnel silhouette: each open stage narrows from left to right.
const HEIGHT = 128
const EDGES = [128, 116, 104, 92, 80, 68]
const TINTS = ['#EFEDFC', '#E6E3FA', '#DCD8F8', '#D1CCF5', '#C8C2F2']
const GOAL = { tint: '#FCEFC7', ink: '#6B4700', active: '#E9B949', activeInk: '#3A2600' }

function stageValue(leads: Lead[]): string {
  const monthly = leads
    .filter((l) => l.planCycle === 'monthly' && l.planPriceCents != null)
    .reduce((sum, l) => sum + (l.planPriceCents ?? 0), 0)
  const annual = leads.filter((l) => l.planCycle === 'annual' && l.planPriceCents != null)
  if (monthly === 0 && annual.length === 0) return '—'
  if (monthly === 0) return `${brl(annual.reduce((s, l) => s + (l.planPriceCents ?? 0), 0))}/ano`
  return annual.length ? `${brl(monthly)}/mês + anual` : `${brl(monthly)}/mês`
}

function segmentStyle(index: number, active: boolean, isGoal: boolean): CSSProperties {
  const hl = EDGES[index] ?? 68
  const hr = EDGES[index + 1] ?? hl - 12
  const t1 = ((HEIGHT - hl) / 2 / HEIGHT) * 100
  const t2 = ((HEIGHT - hr) / 2 / HEIGHT) * 100
  const clip = `polygon(0% ${t1}%, 100% ${t2}%, 100% ${100 - t2}%, 0% ${100 - t1}%)`
  const bg = isGoal ? (active ? GOAL.active : GOAL.tint) : active ? '#5B4BDB' : TINTS[index] ?? TINTS[TINTS.length - 1]
  const color = isGoal ? (active ? GOAL.activeInk : GOAL.ink) : active ? '#FFFFFF' : '#2F2396'
  return { clipPath: clip, background: bg, color }
}

export function Pipeline({
  stages,
  leads,
  selected,
  onSelect,
  closeGoal,
  wonThisMonth,
}: {
  stages: Stage[]
  leads: Lead[]
  selected: Selection
  onSelect: (s: Selection) => void
  closeGoal: number | null
  wonThisMonth: number
}) {
  const funnelStages = stages.filter((s) => s.kind !== 'lost')
  const lostStage = stages.find((s) => s.kind === 'lost')
  const byStage = (id: string) => leads.filter((l) => l.stageId === id)
  const lostLeads = lostStage ? byStage(lostStage.id) : []
  const lastLostReason = lostLeads.find((l) => l.lostReason)?.lostReason

  return (
    <section className="card pipeline" aria-label="Funil de vendas">
      <div className="pipeline-head">
        <h2>Pipeline</h2>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <span className="hint">Clique em uma etapa para ver os leads</span>
          <button type="button" className="pill-btn" aria-pressed={selected === 'all'} onClick={() => onSelect('all')}>
            Todos · {leads.length}
          </button>
        </div>
      </div>
      <div className="funnel-row">
        <div className="funnel" role="group" aria-label="Etapas do funil">
          {funnelStages.map((stage, i) => {
            const isGoal = stage.kind === 'won'
            const inStage = byStage(stage.id)
            const active = selected === stage.id
            const count = isGoal && closeGoal ? `${wonThisMonth}/${closeGoal}` : String(inStage.length)
            const label = isGoal && closeGoal ? `${stage.name}/Objetivo` : stage.name
            const aria = isGoal && closeGoal
              ? `${stage.name}: ${wonThisMonth} de ${closeGoal} da meta do mês`
              : `${stage.name}: ${inStage.length} ${inStage.length === 1 ? 'lead' : 'leads'}`
            return (
              <button
                key={stage.id}
                type="button"
                className={`segment${isGoal ? ' goal' : ''}`}
                style={segmentStyle(i, active, isGoal)}
                aria-pressed={active}
                aria-label={aria}
                onClick={() => onSelect(stage.id)}
              >
                <span className="count">{count}</span>
                <span className="name">{label}</span>
                <span className="value">{isGoal && closeGoal ? 'meta do mês' : stageValue(inStage)}</span>
              </button>
            )
          })}
        </div>
        {lostStage && (
          <>
            <div className="funnel-divider" />
            <button
              type="button"
              className="lost"
              aria-pressed={selected === lostStage.id}
              aria-label={`${lostStage.name}: ${lostLeads.length} ${lostLeads.length === 1 ? 'lead' : 'leads'}`}
              onClick={() => onSelect(lostStage.id)}
            >
              <span className="count">{lostLeads.length}</span>
              <span className="name">{lostStage.name}</span>
              {lastLostReason && <span className="value">{lastLostReason.toLowerCase()}</span>}
            </button>
          </>
        )}
      </div>
    </section>
  )
}
