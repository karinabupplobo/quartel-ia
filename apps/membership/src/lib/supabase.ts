import { createClient } from '@supabase/supabase-js'

// Publishable settings of the quartel-ia demo project. These are public by
// design (every table is protected by Row Level Security), so they live in the
// code as defaults; VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_KEY override
// them, e.g. to point a local build at another project.
const DEFAULT_URL = 'https://tyrabcwygujoxrmgzqyo.supabase.co'
const DEFAULT_KEY = 'sb_publishable_30J-Rxe-Ra_xve3LQACl2g_x4NrfIte'

const url = (import.meta.env.VITE_SUPABASE_URL as string | undefined) || DEFAULT_URL
const key = (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined) || DEFAULT_KEY

export const supabase = createClient(url, key, {
  auth: { persistSession: true, autoRefreshToken: true },
})
