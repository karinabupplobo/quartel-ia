import { IconChart, IconChat, IconFunnel, IconLogout, IconMembers, IconOverview, IconSettings, IconTasks } from './icons'

const soon = [
  { label: 'Visão geral', Icon: IconOverview },
  { label: 'Membros', Icon: IconMembers },
  { label: 'Tarefas', Icon: IconTasks },
  { label: 'Conversas', Icon: IconChat },
  { label: 'Painel de gestão', Icon: IconChart },
]

export function Sidebar({ userInitials, onSignOut }: { userInitials: string; onSignOut: () => void }) {
  return (
    <nav className="sidebar" aria-label="Navegação principal">
      <div style={{ height: 60 }} />
      <a className="nav-item" href="#" aria-label="Visão geral (em breve)" aria-disabled="true" onClick={(e) => e.preventDefault()}>
        <IconOverview size={22} />
      </a>
      <a className="nav-item" href="#" aria-label="Funil de leads" aria-current="page">
        <IconFunnel size={22} />
      </a>
      {soon.slice(1).map(({ label, Icon }) => (
        <a key={label} className="nav-item" href="#" aria-label={`${label} (em breve)`} title={`${label} · em breve`} aria-disabled="true" onClick={(e) => e.preventDefault()}>
          <Icon size={22} />
        </a>
      ))}
      <div className="nav-spacer" />
      <a className="nav-item" href="#" aria-label="Configurações (em breve)" aria-disabled="true" onClick={(e) => e.preventDefault()}>
        <IconSettings size={22} />
      </a>
      <button type="button" className="nav-item" aria-label="Sair" title="Sair" onClick={onSignOut}>
        <IconLogout size={22} />
      </button>
      <div className="me" aria-hidden="true">{userInitials}</div>
    </nav>
  )
}
