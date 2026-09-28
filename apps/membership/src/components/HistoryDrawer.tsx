import { useEffect, useState } from 'react'
import type { HistoryItem, Insight, Lead } from '../lib/data'
import { loadHistory } from '../lib/data'
import { initials, relativeTime } from '../lib/format'
import { AssistantAvatar, IconCalendar, IconChat, IconClose, IconFlag, IconMail, IconNote, IconPlus } from './icons'

function KindIcon({ kind }: { kind: string }) {
  switch (kind) {
    case 'message':
    case 'call':
      return <IconChat size={15} />
    case 'email':
      return <IconMail size={15} />
    case 'meeting':
      return <IconCalendar size={15} />
    case 'stage_change':
      return <IconFlag size={15} />
    case 'note':
      return <IconNote size={15} />
    default:
      return <IconPlus size={15} />
  }
}

export function HistoryDrawer({
  lead,
  stageName,
  insight,
  onClose,
}: {
  lead: Lead
  stageName: string
  insight: Insight | undefined
  onClose: () => void
}) {
  const [items, setItems] = useState<HistoryItem[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let alive = true
    loadHistory(lead.id)
      .then((h) => alive && setItems(h))
      .catch((e: Error) => alive && setError(e.message))
    return () => {
      alive = false
    }
  }, [lead.id])

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const entries: { key: string; ai: boolean; kind: string; title: string; when: string; text: string | null }[] = []
  if (insight) entries.push({ key: 'ai', ai: true, kind: 'ai', title: 'Assistente IA', when: 'Agora', text: insight.body })
  for (const h of items ?? []) {
    entries.push({ key: h.id, ai: false, kind: h.kind, title: h.title, when: relativeTime(h.createdAt), text: h.body })
  }

  return (
    <>
      <button type="button" className="scrim" aria-label="Fechar histórico" onClick={onClose} />
      <aside className="drawer" role="dialog" aria-modal="true" aria-label={`Histórico de ${lead.name}`}>
        <div className="drawer-head">
          <span className="initials" style={{ width: 40, height: 40, fontSize: 14 }}>{initials(lead.name)}</span>
          <div style={{ display: 'flex', flexDirection: 'column', flexGrow: 1 }}>
            <span className="title">{lead.name}</span>
            <span className="hint" style={{ fontSize: 12 }}>Histórico de interações · {stageName}</span>
          </div>
          <button type="button" className="close-btn" style={{ width: 36, height: 36, borderRadius: 10 }} aria-label="Fechar" onClick={onClose} autoFocus>
            <IconClose size={16} />
          </button>
        </div>
        <div className="drawer-body">
          {error && <p className="form-error">{error}</p>}
          {!items && !error && <p className="hint">Carregando histórico…</p>}
          {items && entries.length === 0 && <p className="hint">Nenhuma interação registrada ainda.</p>}
          <ol className="timeline">
            {entries.map((e, i) => (
              <li key={e.key}>
                <div className="tl-rail">
                  {e.ai ? <AssistantAvatar size={32} /> : <span className="tl-icon"><KindIcon kind={e.kind} /></span>}
                  {i < entries.length - 1 && <span className="tl-line" />}
                </div>
                <div className="tl-content">
                  <div>
                    <span className="tl-title">{e.title}</span>
                    <span className="tl-when">{e.when}</span>
                  </div>
                  {e.text && <span className="tl-text">{e.text}</span>}
                </div>
              </li>
            ))}
          </ol>
        </div>
      </aside>
    </>
  )
}
