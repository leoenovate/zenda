# Zenda Firestore schema migration

One-off, **dry-run-first** migration that copies the legacy Zenda Firestore
collections into the new schema **without deleting the originals**, plus a
verification script.

This is **Phase 1** (data only). The Flutter app is refactored separately in
Phase 2; until then the live app keeps reading the old collections, so the
real run defaults to **non-destructive / additive** writes (see
`KEEP_LEGACY_FIELDS` below).

Target project: `enovate-zenda`.

## What it does

| Old collection        | New collection            | Notes |
|-----------------------|---------------------------|-------|
| `schools`             | `organizations`           | all fields carry over + `type: "school"` |
| `roles`               | `roles` (in place)        | adds `accessLevel`, `audienceKey`, `canLogIn`, `orgId` |
| `classes`             | `groups`                  | `orgId`, `supervisorId`, `memberIds` |
| `teachers`            | `members` (`kind:teacher`)| + `legacyClassId`, `subject` |
| `workers`             | `members` (`kind:worker`) | + `legacyRoleLabel` |
| `students`            | `members` (`kind:student`)| guardian fields, `legacySessionIds` |
| `users`               | `users` (in place)        | adds `orgId` |
| `parents`             | `users` + `roles`         | guardian user docs + one `Guardian` role per org |
| `sessions`            | `sessions` (in place)     | adds `orgId`/`groupIds`/`groupNames` |
| `worker_time_off`     | `time_off`                | `orgId`, `memberId`, `memberName` |
| `messages`            | `messages` (in place)     | adds `memberId` |
| `devices`             | `devices` (in place)      | adds `orgId` |
| `api_logs`            | `api_logs` (in place)     | adds `memberId`/`memberName` |
| `device_enrollments`  | `device_enrollments`      | adds `orgId` where present |
| `fingerprints`        | `fingerprints`            | adds `orgId` where present (usually no-op) |
| `system/config`       | `system/config`           | adds `orgId` where present (usually no-op) |

"New" collections (`organizations`, `groups`, `members`, `time_off`, and the
guardian docs added to `users`) are **brand new** — the legacy collections are
left fully intact. "In place" collections are the same-named collections that
get evolved.

## Prerequisites

- Node.js 18+ (project standard is Node 20).
- A Firebase **service account key** for `enovate-zenda` with Firestore access.

### Get a service account key

Firebase Console -> Project settings -> Service accounts -> *Generate new
private key*. Then either:

- save it as `migration/serviceAccountKey.json` (git-ignored), **or**
- set `GOOGLE_APPLICATION_CREDENTIALS` to its absolute path.

## Run it

```powershell
cd migration
npm install

# 1. DRY RUN (default): reads everything, writes NOTHING, logs what it would do.
npm run migrate

# 2. Review the [migrated]/[skipped]/[error] log and the summary.

# 3. Real run: open migrate.js, set DRY_RUN = false, then:
npm run migrate

# 4. Verify the result:
npm run verify
```

## Flags

- `DRY_RUN` (top of `migrate.js`, default `true`) — when true, nothing is
  written; every intended write is logged with a `(dry-run)` suffix.
- `KEEP_LEGACY_FIELDS` (top of `mapping.js`, default `true`) — controls the
  same-named "in place" collections only:
  - `true` (default, **safe**): purely additive. New fields are added and
    every original field/value is preserved, so the currently-deployed app
    (which still reads the old schema) keeps working. Value-renames
    (`messages.sender` `school->org`/`parent->guardian`) and legacy-field
    strips (session mirror fields, `studentId`, `schoolId`, ...) are **not**
    applied.
  - `false` (opt-in cutover): faithful to the spec — performs the true
    renames, the `messages.sender` value-rename, and strips the legacy
    session mirror fields. **Destructive to the old shape; only use once the
    new app is ready / after you have archived the originals.** Dry-run it
    first to preview exactly which fields get deleted.

The brand-new collections (`organizations`, `members`, `groups`, `time_off`,
guardian `users`) are always written in the faithful new shape regardless of
`KEEP_LEGACY_FIELDS`, because the originals are untouched anyway.

## Decisions / deviations from the raw spec

- **`name` is carried onto `members`.** The spec's field lists for
  teachers/workers/students omit `name`; that is treated as an oversight since
  a member record is unusable without it. `name` is copied for all member
  kinds.
- **`Guardian` role `canLogIn: true`.** The generic derivation would make a
  `viewer`-level role non-login-capable, but step 6 explicitly turns parents
  into login-capable users, so the auto-created `Guardian` role overrides
  `canLogIn` to `true`. The role doc id is deterministic (`guardian-<orgId>`)
  so the migration is idempotent and dry-run-safe.
- **Guardian org is derived from linked students.** Parent docs created via
  the parent-login flow have no `schoolId`, so each parent's `orgId` (and thus
  their `Guardian` role) is taken from the `schoolId` of their first linked
  student. Parents with no `schoolId` and no resolvable student org keep
  `orgId`/`roleId` = null (logged as a `[warn]`).
- **Parents with no linked students are skipped.** A guardian account with an
  empty `studentIds` is an empty account, so it is not migrated to `users`
  (logged as `[skipped] ... no linked students`). Originals are untouched.
- **Migrated guardian users have no password.** The script creates the user
  doc (`phone`, `linkedStudentIds`, `roleId`, `memberId: null`) but cannot set
  a credential the spec never defined. How guardians authenticate
  (phone-based login vs. issued password) is a Phase 2 decision.
- **Non-destructive by default** (`KEEP_LEGACY_FIELDS = true`) so the live app
  is not broken between Phase 1 and Phase 2. Flip it for the final cutover.
- **Old collections are never deleted.** Archive or drop them manually once
  `verify` looks correct.

## Verification (`verify.js`)

- Prints document counts for every old and new collection.
- Spot-checks 5 random docs per remapped collection (`organizations`,
  `groups`, `time_off`, `members`, guardian `users`): loads the old + new docs
  side by side and reports any field that is missing or mapped incorrectly.
- Flags any new doc whose `orgId` is null/undefined (on the brand-new
  collections, where an org is mandatory).
- Flags any `members` doc missing `kind`.
