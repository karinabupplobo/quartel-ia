const DAY = 86_400_000

export function initials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((p) => p[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

export function firstName(name: string): string {
  return name.split(' ')[0] ?? name
}

export function brl(cents: number): string {
  return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })
}

export function planPrice(cents: number | null, cycle: string | null): string {
  if (cents == null) return ''
  const suffix = cycle === 'annual' ? '/ano' : cycle === 'semiannual' ? '/semestre' : cycle === 'quarterly' ? '/trimestre' : '/mês'
  return brl(cents) + suffix
}

/** "+55 11 90001-0050" from "+5511900010050" (Brazilian mobile); other numbers unchanged. */
export function phone(e164: string | null): string {
  if (!e164) return ''
  const m = /^\+55(\d{2})(\d{4,5})(\d{4})$/.exec(e164)
  return m ? `+55 ${m[1]} ${m[2]}-${m[3]}` : e164
}

function startOfDay(d: Date): number {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
}

export function daysSince(iso: string, now = new Date()): number {
  return Math.max(0, Math.round((startOfDay(now) - startOfDay(new Date(iso))) / DAY))
}

export function daysLabel(n: number): string {
  if (n === 0) return 'hoje'
  return n === 1 ? '1 dia' : `${n} dias`
}

export type DueTone = 'late' | 'today' | 'soon' | 'normal'

export function dueLabel(dueDate: string | null, now = new Date()): { text: string; tone: DueTone } {
  if (!dueDate) return { text: 'Sem prazo', tone: 'normal' }
  const [y, m, d] = dueDate.split('-').map(Number)
  const diff = Math.round((new Date(y, m - 1, d).getTime() - startOfDay(now)) / DAY)
  if (diff < 0) return { text: diff === -1 ? 'Atrasada · ontem' : `Atrasada · ${-diff} dias`, tone: 'late' }
  if (diff === 0) return { text: 'Hoje', tone: 'today' }
  if (diff === 1) return { text: 'Amanhã', tone: 'soon' }
  const date = new Date(y, m - 1, d)
  const weekday = date.toLocaleDateString('pt-BR', { weekday: 'short' }).replace('.', '')
  return { text: `${weekday}, ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}`, tone: 'normal' }
}

export function relativeTime(iso: string, now = new Date()): string {
  const date = new Date(iso)
  const days = daysSince(iso, now)
  const time = date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  if (days === 0) return `Hoje ${time}`
  if (days === 1) return `Ontem ${time}`
  return `${days} dias atrás`
}

/** "hoje", "ontem", "há 3 dias". */
export function agoLabel(iso: string, now = new Date()): string {
  const d = daysSince(iso, now)
  if (d === 0) return 'hoje'
  if (d === 1) return 'ontem'
  return `há ${d} dias`
}
