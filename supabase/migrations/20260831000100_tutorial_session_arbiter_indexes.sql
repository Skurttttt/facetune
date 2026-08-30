-- Repair the `tutorial_v4_sessions` ON CONFLICT arbiter indexes.
--
-- 20260830000100_tutorial_persistence.sql created these two indexes as PARTIAL
-- unique indexes (`where <column> is not null`). The predicate was a storage
-- micro-optimisation: exactly one of the two columns is populated per row, so
-- the other half of the table would never be indexed.
--
-- That optimisation silently broke the idempotency mechanism it was written to
-- support. `analyze-tutorial-manifest-v4` upserts the session with
-- `onConflict: "canonical_generated_image_id"`, which PostgREST emits as
-- `ON CONFLICT (<column>)` with no index predicate. PostgreSQL only infers a
-- partial index as an arbiter when the statement supplies a WHERE clause
-- implying the index predicate, and PostgREST cannot emit one — so every
-- tutorial open failed at parse analysis with:
--
--   42P10: there is no unique or exclusion constraint matching the
--          ON CONFLICT specification
--
-- Reproduced against this database with `explain insert ... on conflict
-- (canonical_generated_image_id) do nothing`, which raises 42P10 before any
-- row is touched.
--
-- Ordinary unique indexes on these nullable columns are semantically identical
-- here: NULLs are distinct by default, so the many rows holding NULL in the
-- unused column still coexist, while non-null canonical preview ids stay
-- unique. NULLS NOT DISTINCT is deliberately NOT used — that would forbid more
-- than one row per mode and break the opposite case.
--
-- Indexes only. No table, column, data, RLS, or storage change.

drop index if exists public.tutorial_v4_sessions_canonical_preview_idx;
drop index if exists public.tutorial_v4_sessions_kit_canonical_preview_idx;

create unique index tutorial_v4_sessions_canonical_preview_idx
  on public.tutorial_v4_sessions (canonical_generated_image_id);

create unique index tutorial_v4_sessions_kit_canonical_preview_idx
  on public.tutorial_v4_sessions (canonical_kit_generated_image_id);
