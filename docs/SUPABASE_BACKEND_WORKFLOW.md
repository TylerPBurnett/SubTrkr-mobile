# Supabase Backend Workflow

This repo shares a Supabase backend with the desktop SubTrkr app. Treat backend work as production work unless you have explicitly pointed your Debug build somewhere else.

## Current setup

- Supabase CLI is linked to project `bpgsfyallqqvvtjorybl` (`SubTrkr`).
- Remote migration history has been fetched into `supabase/migrations/`.
- Release builds still target the production Supabase project.
- Debug builds no longer silently inherit production credentials.

## What "Debug no longer defaults to production" means

Debug builds now require you to choose a backend explicitly.

You have two supported ways to do that:

1. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Xcode scheme environment.
2. Create `SubTrkr/Secrets.xcconfig` from `SubTrkr/Secrets.example.xcconfig` and put your chosen project values there.

If you do neither, the app fails fast on launch with a configuration error. That is intentional. It prevents accidental schema or data work against production during normal development.

You do **not** need to change anything back later for release builds. Release uses `SubTrkr/Release.xcconfig`, which still contains the production project values.

## Day-to-day backend workflow

1. Check migration state:

   ```bash
   supabase migration list
   ```

2. Before a risky schema change, create a dump from the linked remote database:

   ```bash
   mkdir -p supabase/backups
   supabase db dump --linked --file supabase/backups/pre_change_YYYYMMDD.sql
   ```

3. Create a migration file:

   ```bash
   supabase migration new short_description
   ```

4. Write additive SQL first when possible.
   - Prefer adding nullable columns, new indexes, and new tables before destructive cleanup.
   - Split destructive follow-up work into a later migration after the app code has shipped.

5. Preview remote apply before pushing:

   ```bash
   supabase db push --dry-run
   ```

6. Apply when ready:

   ```bash
   supabase db push
   ```

7. Re-check history:

   ```bash
   supabase migration list
   ```

## If something goes wrong

- For a small schema mistake, prefer a new corrective migration.
- For migration-history drift, use `supabase migration repair` deliberately rather than editing the history table by hand.
- For serious data or schema damage, restore from a dump or use Supabase backups/PITR instead of trying to "git revert" the database.

Databases are versionable, but they are not as trivially reversible as source code. Git is the audit trail for SQL files. Recovery is still either a corrective migration or a restore.

## Local caveats

- `supabase status` is for the local Docker-based stack, not the hosted project.
- `supabase db pull` currently requires Docker Desktop on this machine because the CLI creates a shadow database to diff schema changes.
- `supabase migration fetch` is the correct way to bring existing remote migration history into a repo that was linked after the backend already existed.

## Files to know

- `supabase/config.toml` — CLI project config for this repo
- `supabase/migrations/` — tracked migration history for the shared backend
- `SubTrkr/Debug.xcconfig` — Debug build settings, intentionally blank by default
- `SubTrkr/Release.xcconfig` — Release build settings, production values
- `SubTrkr/Secrets.example.xcconfig` — template for local Debug credentials
