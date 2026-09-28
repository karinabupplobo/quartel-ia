#!/usr/bin/env bash
# Runs migrations + seed + RLS tests against a throwaway Postgres cluster.
# Needs only Postgres binaries (no Docker, no Supabase CLI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PORT:-54329}"

cleanup() { "$PGBIN/pg_ctl" -D "$WORK/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK" -l "$WORK/pg.log" start >/dev/null

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -d postgres -q -v ON_ERROR_STOP=1)

"${PSQL[@]}" -f "$ROOT/tests/supabase_stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "migrate: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
"${PSQL[@]}" -f "$ROOT/supabase/seed.sql"
"${PSQL[@]}" -o /dev/null -f "$ROOT/tests/core_rls.sql"
"${PSQL[@]}" -o /dev/null -f "$ROOT/tests/membership_rls.sql"
