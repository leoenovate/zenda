'use strict';

/**
 * Zenda Firestore migration runner.
 *
 * Reads every legacy collection, maps each doc to the new schema (mapping.js),
 * and writes the result to the new collections WITHOUT deleting the originals.
 *
 * Workflow:
 *   1. Keep DRY_RUN = true, run `npm run migrate`, review the log + summary.
 *   2. Set DRY_RUN = false, run again for real.
 *   3. Run `npm run verify`.
 *
 * See mapping.js KEEP_LEGACY_FIELDS for additive (default) vs. destructive mode.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const M = require('./mapping');

// When true: read everything, write NOTHING, just log what would happen.
const DRY_RUN = true;

// --- admin init ------------------------------------------------------------

function initAdmin() {
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: M.PROJECT_ID,
    });
    return 'GOOGLE_APPLICATION_CREDENTIALS';
  }
  if (fs.existsSync(keyPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(require(keyPath)),
      projectId: M.PROJECT_ID,
    });
    return 'serviceAccountKey.json';
  }
  // Last resort: application default discovery (gcloud / metadata server).
  admin.initializeApp({ projectId: M.PROJECT_ID });
  return 'application-default (no explicit key found)';
}

// --- migration engine ------------------------------------------------------

class Migrator {
  constructor(db) {
    this.db = db;
    this.FieldValue = admin.firestore.FieldValue;
    this.ops = []; // pending { ref, data, merge, log, label }
    this.migrated = 0;
    this.skipped = 0;
    this.errors = 0;
    this.noops = 0;
    this.perCollection = {}; // label -> { migrated, skipped, errors }
  }

  _bucket(label) {
    return (this.perCollection[label] ||= { migrated: 0, skipped: 0, errors: 0 });
  }

  skip(label, source, id, reason) {
    this.skipped++;
    this._bucket(label).skipped++;
    console.log(`[skipped] ${source}/${id} - ${reason}`);
  }

  fail(label, source, id, err) {
    this.errors++;
    this._bucket(label).errors++;
    const msg = err && err.message ? err.message : String(err);
    console.log(`[error] ${source}/${id} - ${msg}`);
  }

  noop(label, source, id) {
    this.migrated++;
    this.noops++;
    this._bucket(label).migrated++;
    console.log(`[migrated] ${source}/${id} -> ${source}/${id} (no change)`);
  }

  /**
   * Queue (or, in dry-run, just log) one write. Builds the canonical
   * `[migrated]` line so it can be printed exactly when the write succeeds.
   */
  async write(label, source, target, id, data, merge) {
    const log = `[migrated] ${source}/${id} -> ${target}/${id}`;
    if (DRY_RUN) {
      this.migrated++;
      this._bucket(label).migrated++;
      console.log(`${log} (dry-run)`);
      return;
    }
    this.ops.push({ ref: this.db.collection(target).doc(id), data, merge, log, label });
    if (this.ops.length >= M.BATCH_SIZE) await this.flush();
  }

  async flush() {
    if (this.ops.length === 0) return;
    const batchOps = this.ops;
    this.ops = [];
    const batch = this.db.batch();
    for (const op of batchOps) {
      batch.set(op.ref, op.data, op.merge ? { merge: true } : {});
    }
    try {
      await batch.commit();
      for (const op of batchOps) {
        this.migrated++;
        this._bucket(op.label).migrated++;
        console.log(op.log);
      }
    } catch (e) {
      // Whole batch failed; tally each doc as an error and continue.
      this.errors += batchOps.length;
      for (const op of batchOps) this._bucket(op.label).errors++;
      const msg = e && e.message ? e.message : String(e);
      console.log(`[error] batch commit failed for ${batchOps.length} doc(s) - ${msg}`);
    }
  }

  /** Apply FieldValue.delete() sentinels for cutover-mode field removals. */
  _withDeletes(data, deletes) {
    if (!deletes || deletes.length === 0) return data;
    const out = { ...data };
    for (const f of deletes) out[f] = this.FieldValue.delete();
    return out;
  }

  /** Run one straightforward source -> target pass. */
  async runPass({ source, target, transform, inPlace }) {
    const label = `${source} -> ${target}`;
    console.log(`\n--- ${label} ---`);
    let snap;
    try {
      snap = await this.db.collection(source).get();
    } catch (e) {
      console.log(`[error] failed to read collection ${source} - ${e.message}`);
      return;
    }
    if (snap.empty) {
      console.log(`(no documents in ${source})`);
      return;
    }
    for (const doc of snap.docs) {
      try {
        const res = transform(doc.id, doc.data());
        if (!res) {
          this.skip(label, source, doc.id, 'transform returned null');
          continue;
        }
        let data = { ...res.data };
        const hasDeletes = !M.KEEP_LEGACY_FIELDS && res.deletes && res.deletes.length > 0;
        if (hasDeletes) data = this._withDeletes(data, res.deletes);

        // In-place doc with nothing to add/remove: already in shape.
        if (inPlace && Object.keys(data).length === 0) {
          this.noop(label, source, doc.id);
          continue;
        }
        await this.write(label, source, target, doc.id, data, inPlace);
      } catch (e) {
        this.fail(label, source, doc.id, e);
      }
    }
    await this.flush();
  }

  /**
   * parents -> users, plus one deterministic Guardian role per org.
   * Guarded so a parent doc never overwrites a real (email/password) user.
   */
  async runParentsPass() {
    const label = 'parents -> users';
    console.log(`\n--- ${label} (+ guardian roles) ---`);
    let snap;
    try {
      snap = await this.db.collection('parents').get();
    } catch (e) {
      console.log(`[error] failed to read collection parents - ${e.message}`);
      return;
    }
    if (snap.empty) {
      console.log('(no documents in parents)');
      return;
    }

    // Build studentId -> orgId so a parent with no schoolId inherits the org
    // of their linked student(s).
    const studentOrgById = {};
    try {
      const studentsSnap = await this.db.collection('students').get();
      for (const s of studentsSnap.docs) {
        const org = s.data().schoolId;
        if (org) studentOrgById[s.id] = org;
      }
    } catch (e) {
      console.log(`[error] failed to read students for parent-org derivation - ${e.message}`);
    }

    // Resolve each parent's org once.
    const orgByParentId = {};
    for (const doc of snap.docs) {
      orgByParentId[doc.id] = M.resolveParentOrgId(doc.data(), studentOrgById);
    }

    // 1. Guardian role per distinct resolved org.
    const orgIds = new Set();
    for (const doc of snap.docs) {
      const org = orgByParentId[doc.id];
      if (org) orgIds.add(org);
    }
    const roleLabel = 'parents -> roles (guardian)';
    for (const orgId of orgIds) {
      try {
        const data = { ...M.guardianRoleDoc(orgId) };
        if (!DRY_RUN) {
          data.createdAt = this.FieldValue.serverTimestamp();
          data.updatedAt = this.FieldValue.serverTimestamp();
        }
        await this.write(roleLabel, 'parents', 'roles', M.guardianRoleId(orgId), data, true);
      } catch (e) {
        this.fail(roleLabel, 'parents', M.guardianRoleId(orgId), e);
      }
    }
    await this.flush();

    // 2. parents -> users (org/roleId derived above). Parents with no linked
    //    students are empty accounts -> skip them.
    let noOrg = 0;
    for (const doc of snap.docs) {
      try {
        const pdata = doc.data();
        if (!M.parentHasLinkedStudents(pdata)) {
          this.skip(label, 'parents', doc.id, 'no linked students');
          continue;
        }
        const orgId = orgByParentId[doc.id];
        if (!orgId) noOrg++;
        const res = M.transformParentToUser(doc.id, pdata, { orgId });
        if (!DRY_RUN) {
          const existing = await this.db.collection('users').doc(doc.id).get();
          if (existing.exists) {
            const ed = existing.data() || {};
            if (ed.email || ed.passwordHash || ed.passwordSalt) {
              this.skip(label, 'parents', doc.id,
                `users/${doc.id} already exists as a real user (id collision)`);
              continue;
            }
          }
        }
        await this.write(label, 'parents', 'users', doc.id, res.data, true);
      } catch (e) {
        this.fail(label, 'parents', doc.id, e);
      }
    }
    await this.flush();
    if (noOrg > 0) {
      console.log(`[warn] ${noOrg} parent(s) had no resolvable org ` +
        '(no schoolId and no linked student with one); orgId/roleId left null.');
    }
  }

  printSummary() {
    console.log('\n========== SUMMARY ==========');
    const labels = Object.keys(this.perCollection).sort();
    const pad = Math.max(20, ...labels.map((l) => l.length));
    console.log(`${'collection'.padEnd(pad)}  migrated  skipped  errors`);
    for (const l of labels) {
      const b = this.perCollection[l];
      console.log(
        `${l.padEnd(pad)}  ${String(b.migrated).padStart(8)}  ` +
        `${String(b.skipped).padStart(7)}  ${String(b.errors).padStart(6)}`,
      );
    }
    console.log('-----------------------------');
    console.log(`Total migrated: ${this.migrated}` + (this.noops ? ` (${this.noops} no-op)` : ''));
    console.log(`Total skipped:  ${this.skipped}`);
    console.log(`Total errors:   ${this.errors}`);
    console.log('=============================');
  }
}

// --- main ------------------------------------------------------------------

async function main() {
  const credSource = initAdmin();
  const db = admin.firestore();
  const m = new Migrator(db);

  console.log('========================================');
  console.log(`Zenda migration  |  project: ${M.PROJECT_ID}`);
  console.log(`mode:             ${DRY_RUN ? 'DRY RUN (no writes)' : 'LIVE (writing)'}`);
  console.log(`KEEP_LEGACY_FIELDS: ${M.KEEP_LEGACY_FIELDS}` +
    (M.KEEP_LEGACY_FIELDS ? ' (additive / non-destructive)' : ' (DESTRUCTIVE cutover)'));
  console.log(`credentials:      ${credSource}`);
  console.log('========================================');

  for (const mig of M.MIGRATIONS) {
    await m.runPass(mig);
  }
  await m.runParentsPass();

  m.printSummary();

  if (DRY_RUN) {
    console.log('\nDRY RUN complete - nothing was written. Set DRY_RUN = false to apply.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('\nFATAL:', e && e.stack ? e.stack : e);
    console.error(
      '\nIf this is a credentials error, set GOOGLE_APPLICATION_CREDENTIALS or place ' +
      'a serviceAccountKey.json in the migration/ folder (see README.md).',
    );
    process.exit(1);
  });
