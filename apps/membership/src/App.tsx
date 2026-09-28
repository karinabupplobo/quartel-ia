import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import { loadWorkspace } from './lib/data'
import type { Workspace } from './lib/data'
import { LoginPage } from './pages/LoginPage'
import { FunnelPage } from './pages/FunnelPage'

type State =
  | { status: 'loading' }
  | { status: 'signed-out' }
  | { status: 'no-access' }
  | { status: 'error'; message: string }
  | { status: 'ready'; workspace: Workspace }

export default function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined)
  const [state, setState] = useState<State>({ status: 'loading' })

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s))
    return () => data.subscription.unsubscribe()
  }, [])

  // Changes when the auth state is first known, on sign-in and on sign-out.
  const sessionKey = session === undefined ? 'pending' : session ? session.user.id : 'signed-out'

  useEffect(() => {
    if (session === undefined) return
    if (!session) {
      setState({ status: 'signed-out' })
      return
    }
    setState({ status: 'loading' })
    loadWorkspace()
      .then((w) => setState(w ? { status: 'ready', workspace: w } : { status: 'no-access' }))
      .catch((e: Error) => setState({ status: 'error', message: e.message }))
  }, [sessionKey]) // eslint-disable-line react-hooks/exhaustive-deps

  const signOut = () => void supabase.auth.signOut()

  switch (state.status) {
    case 'loading':
      return <div className="state">Carregando…</div>
    case 'signed-out':
      return <LoginPage />
    case 'no-access':
      return (
        <div className="state">
          <div>
            <p>Seu usuário ainda não tem acesso a nenhuma empresa.</p>
            <button type="button" className="btn" onClick={signOut}>Sair</button>
          </div>
        </div>
      )
    case 'error':
      return <div className="state" role="alert">{state.message}</div>
    case 'ready':
      return <FunnelPage workspace={state.workspace} onSignOut={signOut} />
  }
}
