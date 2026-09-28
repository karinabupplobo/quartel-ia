import { useEffect, useState } from 'react'
import type { Analysis, Lead, Task } from '../lib/data'
import { dueLabel, firstName } from '../lib/format'
import { AssistantAvatar, IconClose, IconFlag, IconMail } from './icons'

/**
 * The assistant's analysis of a lead in Proposta or Negociação: what was said,
 * tips, the next step and, for proposals, a ready-to-send e-mail.
 */
export function AnalysisDrawer({
  lead,
  stageName,
  analysis,
  task,
  onClose,
  onScheduleStep,
  onProposalSent,
}: {
  lead: Lead
  stageName: string
  analysis: Analysis
  task: Task | undefined
  onClose: () => void
  onScheduleStep: (title: string) => Promise<void>
  onProposalSent: (subject: string) => Promise<void>
}) {
  const first = firstName(lead.name)
  const isProposal = analysis.kind === 'proposal'
  const [draftOpen, setDraftOpen] = useState(false)
  const [subject, setSubject] = useState(analysis.proposal?.subject ?? '')
  const [body, setBody] = useState(analysis.proposal?.body ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [sent, setSent] = useState(false)

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const mailto = lead.email
    ? `mailto:${encodeURIComponent(lead.email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
    : null

  async function schedule() {
    setBusy(true)
    setError(null)
    try {
      await onScheduleStep(analysis.next_step)
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  async function logSent() {
    setError(null)
    try {
      await onProposalSent(subject)
      setSent(true)
    } catch (e) {
      setError((e as Error).message)
    }
  }

  const due = task ? dueLabel(task.dueDate) : null

  return (
    <>
      <button type="button" className="scrim" aria-label="Fechar análise" onClick={onClose} />
      <aside className="drawer analysis" role="dialog" aria-modal="true" aria-label={`Análise IA de ${lead.name}`}>
        <div className="drawer-head">
          <AssistantAvatar size={40} />
          <div style={{ display: 'flex', flexDirection: 'column', flexGrow: 1 }}>
            <span className="title">Análise IA · {first}</span>
            <span className="hint" style={{ fontSize: 12 }}>
              {isProposal ? 'Para montar a proposta' : 'Negociação em andamento'} · {stageName}
            </span>
          </div>
          <button type="button" className="close-btn" style={{ width: 36, height: 36, borderRadius: 10 }} aria-label="Fechar" onClick={onClose} autoFocus>
            <IconClose size={16} />
          </button>
        </div>

        <div className="drawer-body analysis-body">
          <section>
            <h3>Resumo</h3>
            <p>{analysis.summary}</p>
          </section>

          <section>
            <h3>{isProposal ? 'Conversas e aulas' : 'Conversas após a proposta'}</h3>
            <ul className="a-list">
              {analysis.conversations.map((c, i) => <li key={i}>{c}</li>)}
            </ul>
          </section>

          {analysis.negotiation && analysis.negotiation.length > 0 && (
            <section>
              <h3>Negociação da proposta</h3>
              <ul className="a-list">
                {analysis.negotiation.map((c, i) => <li key={i}>{c}</li>)}
              </ul>
            </section>
          )}

          <section>
            <h3>{isProposal ? 'Dicas para a proposta' : 'Dicas para fechar'}</h3>
            <ul className="a-list tips">
              {analysis.tips.map((c, i) => <li key={i}>{c}</li>)}
            </ul>
          </section>

          <section className="next-step-box">
            <div className="next-step-head">
              <IconFlag size={15} />
              <span>Próximo passo</span>
            </div>
            <p>{analysis.next_step}</p>
            {task && due ? (
              <span className="scheduled">
                Agendado: {task.title} · <span className={`due ${due.tone}`}>{due.text}</span>
              </span>
            ) : (
              <div className="unscheduled">
                <span className="missing-label">Ainda não está agendado</span>
                <button type="button" className="btn" disabled={busy} onClick={schedule}>
                  {busy ? 'Agendando…' : 'Agendar para hoje'}
                </button>
              </div>
            )}
          </section>

          {isProposal && analysis.proposal && (
            <section>
              {!draftOpen ? (
                <button type="button" className="btn ai wide" onClick={() => setDraftOpen(true)}>
                  Criar proposta automática
                </button>
              ) : (
                <div className="proposal-draft">
                  <h3>Proposta para {first}</h3>
                  <label className="field">
                    Assunto
                    <input value={subject} onChange={(e) => setSubject(e.target.value)} />
                  </label>
                  <label className="field">
                    Mensagem
                    <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={14} />
                  </label>
                  <span className="notice">Revise e edite à vontade antes de enviar.</span>
                  {mailto ? (
                    <a className="btn wide mail" href={mailto} onClick={() => void logSent()}>
                      <IconMail size={16} />
                      Enviar por e-mail
                    </a>
                  ) : (
                    <span className="form-error">{first} não tem e-mail cadastrado.</span>
                  )}
                  {sent && (
                    <span className="notice" role="status">
                      Abrimos o seu e-mail com a proposta para {lead.email}. O envio ficou registrado no histórico.
                    </span>
                  )}
                </div>
              )}
            </section>
          )}

          {error && <p className="form-error" role="alert">{error}</p>}
        </div>
      </aside>
    </>
  )
}
