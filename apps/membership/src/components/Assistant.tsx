import { useState } from 'react'
import { AssistantAvatar, IconArrowRight, IconChevronDown } from './icons'

/** Something the assistant flags or suggests (missing next step, late task, tip…). */
export interface AssistantMessage {
  id: string
  leadId: string | null
  tone: 'risk' | 'warn' | 'ai'
  who: string
  text: string
}

const SEEN_KEY = 'quartel-membership:assistant-seen'

function readSeen(): Set<string> {
  try {
    return new Set(JSON.parse(localStorage.getItem(SEEN_KEY) ?? '[]') as string[])
  } catch {
    return new Set()
  }
}

function writeSeen(ids: string[]) {
  try {
    localStorage.setItem(SEEN_KEY, JSON.stringify(ids))
  } catch {
    // Private mode or storage blocked: the counter just resets next visit.
  }
}

export function Assistant({
  open,
  onToggle,
  greetingName,
  message,
  icpSummary,
  messages,
  onOpenLead,
}: {
  open: boolean
  onToggle: () => void
  greetingName: string
  message: string | null
  icpSummary: string | null
  messages: AssistantMessage[]
  onOpenLead: (leadId: string) => void
}) {
  const [seen, setSeen] = useState<Set<string>>(readSeen)
  const unread = messages.filter((m) => !seen.has(m.id)).length

  // Opening or closing the panel marks everything listed as read.
  function toggle() {
    const ids = messages.map((m) => m.id)
    setSeen(new Set(ids))
    writeSeen(ids)
    onToggle()
  }

  return (
    <>
      {open && (
        <aside className="assistant-panel" aria-label="Assistente de IA">
          <div className="assistant-head">
            <AssistantAvatar size={40} />
            <div className="who">
              <strong>Assistente IA</strong>
              <span className="status">Online · acompanhando seu funil</span>
            </div>
            <button type="button" className="close-btn" style={{ width: 36, height: 36, borderRadius: 10 }} aria-label="Minimizar assistente" onClick={toggle}>
              <IconChevronDown size={18} />
            </button>
          </div>
          <div className="assistant-body">
            <div className="speech">
              Oi{greetingName ? `, ${greetingName}` : ''}! {message ?? 'Ainda não tenho comentários sobre esta etapa.'}
            </div>

            {messages.length > 0 && (
              <div className="a-messages">
                <span className="a-messages-head">Para você agora · {messages.length}</span>
                <ul>
                  {messages.map((m) => (
                    <li key={m.id}>
                      <button type="button" disabled={!m.leadId} onClick={() => m.leadId && onOpenLead(m.leadId)}>
                        <span className={`dot ${m.tone}`} />
                        <span>
                          <strong>{m.who}</strong> {m.text}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {icpSummary && (
              <div className="icp">
                <div className="icp-head">
                  <span>Seu ICP</span>
                </div>
                <p>{icpSummary}</p>
              </div>
            )}
          </div>
          <label className="ask">
            <span className="sr-only">Pergunte algo sobre seus leads</span>
            <input type="text" placeholder="Pergunte algo sobre seus leads…" disabled />
            <span className="icon-btn" aria-hidden="true" style={{ width: 34, height: 34, background: '#5B4BDB', color: '#fff', border: 'none', opacity: 0.5 }}>
              <IconArrowRight size={16} />
            </span>
          </label>
          <p className="ask-note">O chat com a assistente chega na próxima versão.</p>
        </aside>
      )}
      <button
        type="button"
        className="assistant-bubble"
        aria-label={
          open
            ? 'Minimizar assistente de IA'
            : unread > 0
              ? `Abrir assistente de IA: ${unread} ${unread === 1 ? 'mensagem nova' : 'mensagens novas'}`
              : 'Abrir assistente de IA'
        }
        aria-expanded={open}
        onClick={toggle}
      >
        <AssistantAvatar size={56} />
        {unread > 0 && !open ? <span className="bubble-count">{unread}</span> : <span className="online-dot" />}
      </button>
    </>
  )
}
