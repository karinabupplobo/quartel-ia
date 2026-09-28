import { AssistantAvatar, IconArrowRight, IconChevronDown } from './icons'

export function Assistant({
  open,
  onToggle,
  greetingName,
  message,
  icpSummary,
}: {
  open: boolean
  onToggle: () => void
  greetingName: string
  message: string | null
  icpSummary: string | null
}) {
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
            <button type="button" className="close-btn" style={{ width: 36, height: 36, borderRadius: 10 }} aria-label="Minimizar assistente" onClick={onToggle}>
              <IconChevronDown size={18} />
            </button>
          </div>
          <div className="assistant-body">
            <div className="speech">
              Oi{greetingName ? `, ${greetingName}` : ''}! {message ?? 'Ainda não tenho comentários sobre esta etapa.'}
            </div>
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
        aria-label={open ? 'Minimizar assistente de IA' : 'Abrir assistente de IA'}
        aria-expanded={open}
        onClick={onToggle}
      >
        <AssistantAvatar size={56} />
        <span className="online-dot" />
      </button>
    </>
  )
}
