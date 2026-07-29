'use strict';

/**
 * Post-migration verification for the Zenda Firestore migration.
 *
 *   1. Counts every old and new collection.
 *   2. Spot-checks 5 random docs per remapped collection (old vs new) using the
 *      same transforms migrate.js used (mapping.js), reporting missing or
 *      incorrectly-mapped fields.
 *   3. Flags any brand-new doc whose orgId is null/undefined.
 *   4. Flags any members doc missing `kind`.
 *
 * Read-only: never writes.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const M = require('./mapping');

const SAMPLE_SIZE = 5;

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
  admin.initializeApp({ projectId: M.PROJECT_ID });
  return 'application-default (no explicit key found)';
}

// --- helpers ---------------------------------------------------------------

async function countCollection(db, name) {
  try {
    const agg = await db.collection(name).count().get();
    return agg.data().count;
  } catch (_) {
    try {
      const snap = await db.collection(name).get();
      return snap.size;
    } catch (e) {
      return `error: ${e.message}`;
    }
  }
}

function jsonEq(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function sample(docs, n) {
  const a = docs.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a.slice(0, n);
}

/** Compare an expected (transformed) object against the actual stored doc. */
function diffExpected(expected, actual) {
  const problems = [];
  for (const k of Object.keys(expected)) {
    if (!(k in actual)) {
      problems.push(`missing "${k}"`);
    } else if (!jsonEq(actual[k], expected[k])) {
      problems.push(`"${k}" mismatch (expected ${short(expected[k])}, got ${short(actual[k])})`);
    }
  }
  return problems;
}

function short(v) {
  const s = JSON.stringify(v);
  if (s === undefined) return String(v);
  return s.length > 60 ? s.slice(0, 57) + '...' : s;
}

// --- spot checks -----------------------------------------------------------

/** Generic: new doc id == origin doc id in a single origin collection. */
async function spotCheckSimple(db, newColl, originColl, transform) {
  console.log(`\n# ${newColl}  (origin: ${originColl})`);
  let flags = 0;
  let snap;
  try {
    snap = await db.collection(newColl).get();
  } catch (e) {
    console.log(`  [error] cannot read ${newColl}: ${e.message}`);
    return 1;
  }
  if (snap.empty) {
    console.log('  (empty)');
    return 0;
  }
  for (const d of sample(snap.docs, SAMPLE_SIZE)) {
    const o = await db.collection(originColl).doc(d.id).get();
    if (!o.exists) {
      console.log(`  [FLAG] ${newColl}/${d.id} <- ${originColl}/${d.id}: origin missing`);
      flags++;
      continue;
    }
    const expected = transform(d.id, o.data()).data;
    const problems = diffExpected(expected, d.data());
    if (problems.length) {
      console.log(`  [FLAG] ${newColl}/${d.id}: ${problems.join('; ')}`);
      flags++;
    } else {
      console.log(`  [ok]   ${newColl}/${d.id} <- ${originColl}/${d.id}`);
    }
  }
  return flags;
}

/** members originate from teachers/workers/students depending on `kind`. */
async function spotCheckMembers(db) {
  console.log('\n# members  (origin: teachers / workers / students by kind)');
  const byKind = {
    teacher: { coll: 'teachers', fn: M.transformTeacherMember },
    worker: { coll: 'workers', fn: M.transformWorkerMember },
    student: { coll: 'students', fn: M.transformStudentMember },
  };
  let flags = 0;
  let snap;
  try {
    snap = await db.collection('members').get();
  } catch (e) {
    console.log(`  [error] cannot read members: ${e.message}`);
    return 1;
  }
  if (snap.empty) {
    console.log('  (empty)');
    return 0;
  }
  for (const d of sample(snap.docs, SAMPLE_SIZE)) {
    const data = d.data();
    const route = byKind[data.kind];
    if (!route) {
      console.log(`  [FLAG] members/${d.id}: missing/unknown kind "${data.kind}"`);
      flags++;
      continue;
    }
    const o = await db.collection(route.coll).doc(d.id).get();
    if (!o.exists) {
      console.log(`  [FLAG] members/${d.id} <- ${route.coll}/${d.id}: origin missing`);
      flags++;
      continue;
    }
    const expected = route.fn(d.id, o.data()).data;
    const problems = diffExpected(expected, data);
    if (problems.length) {
      console.log(`  [FLAG] members/${d.id} (${data.kind}): ${problems.join('; ')}`);
      flags++;
    } else {
      console.log(`  [ok]   members/${d.id} <- ${route.coll}/${d.id} (${data.kind})`);
    }
  }
  return flags;
}

/** Guardian users carry linkedStudentIds; their origin is parents/{id}. */
async function spotCheckGuardianUsers(db) {
  console.log('\n# users (guardian)  (origin: parents)');
  let flags = 0;
  let snap;
  try {
    snap = await db.collection('users').get();
  } catch (e) {
    console.log(`  [error] cannot read users: ${e.message}`);
    return 1;
  }
  const guardians = snap.docs.filter((d) => d.data().linkedStudentIds !== undefined);
  if (guardians.length === 0) {
    console.log('  (no guardian-origin users found)');
    return 0;
  }
  // Same org derivation migrate.js used (parent schoolId -> linked student's).
  const studentOrgById = {};
  try {
    const studentsSnap = await db.collection('students').get();
    for (const s of studentsSnap.docs) {
      const org = s.data().schoolId;
      if (org) studentOrgById[s.id] = org;
    }
  } catch (_) {
    // best effort; falls back to parent.schoolId
  }
  for (const d of sample(guardians, SAMPLE_SIZE)) {
    const o = await db.collection('parents').doc(d.id).get();
    if (!o.exists) {
      console.log(`  [FLAG] users/${d.id} <- parents/${d.id}: origin missing`);
      flags++;
      continue;
    }
    const orgId = M.resolveParentOrgId(o.data(), studentOrgById);
    const expected = M.transformParentToUser(d.id, o.data(), { orgId }).data;
    const problems = diffExpected(expected, d.data());
    if (problems.length) {
      console.log(`  [FLAG] users/${d.id}: ${problems.join('; ')}`);
      flags++;
    } else {
      console.log(`  [ok]   users/${d.id} <- parents/${d.id}`);
    }
  }
  return flags;
}

// --- field flags -----------------------------------------------------------

async function flagOrgIdRequired(db) {
  console.log('\n# orgId presence (brand-new collections)');
  let flags = 0;
  for (const coll of M.ORG_REQUIRED_COLLECTIONS) {
    let snap;
    try {
      snap = await db.collection(coll).get();
    } catch (e) {
      console.log(`  [error] cannot read ${coll}: ${e.message}`);
      flags++;
      continue;
    }
    let bad = 0;
    for (const d of snap.docs) {
      const dd = d.data();
      const o = dd.orgId;
      if (o === null || o === undefined) {
        const hint = [
          dd.kind ? `kind=${dd.kind}` : null,
          dd.name ? `name="${dd.name}"` : null,
        ].filter(Boolean).join(' ');
        console.log(`  [FLAG] ${coll}/${d.id}: orgId is ${o}${hint ? `  (${hint})` : ''}`);
        bad++;
      }
    }
    flags += bad;
    if (bad === 0) console.log(`  [ok]   ${coll}: all ${snap.size} doc(s) have orgId`);
  }
  return flags;
}

async function flagMemberKind(db) {
  console.log('\n# members kind presence');
  let snap;
  try {
    snap = await db.collection('members').get();
  } catch (e) {
    console.log(`  [error] cannot read members: ${e.message}`);
    return 1;
  }
  let bad = 0;
  for (const d of snap.docs) {
    if (!d.data().kind) {
      console.log(`  [FLAG] members/${d.id}: missing kind`);
      bad++;
    }
  }
  if (bad === 0) console.log(`  [ok]   all ${snap.size} member(s) have kind`);
  return bad;
}

// --- main ------------------------------------------------------------------

async function main() {
  const credSource = initAdmin();
  const db = admin.firestore();

  console.log('========================================');
  console.log(`Zenda migration verify  |  project: ${M.PROJECT_ID}`);
  console.log(`KEEP_LEGACY_FIELDS: ${M.KEEP_LEGACY_FIELDS}`);
  console.log(`credentials:        ${credSource}`);
  console.log('========================================');

  console.log('\n========== DOCUMENT COUNTS ==========');
  const pad = Math.max(...M.COUNT_COLLECTIONS.map((c) => c.length));
  for (const coll of M.COUNT_COLLECTIONS) {
    const n = await countCollection(db, coll);
    console.log(`${coll.padEnd(pad)}  ${n}`);
  }

  console.log('\n========== SPOT CHECKS (5 random / collection) ==========');
  let flags = 0;
  flags += await spotCheckSimple(db, 'organizations', 'schools', M.transformSchool);
  flags += await spotCheckSimple(db, 'groups', 'classes', M.transformClassToGroup);
  flags += await spotCheckSimple(db, 'time_off', 'worker_time_off', M.transformTimeOff);
  flags += await spotCheckMembers(db);
  flags += await spotCheckGuardianUsers(db);

  console.log('\n========== FIELD FLAGS ==========');
  flags += await flagOrgIdRequired(db);
  flags += await flagMemberKind(db);

  console.log('\n========== RESULT ==========');
  if (flags === 0) {
    console.log('No problems found.');
  } else {
    console.log(`${flags} flag(s) raised - review the [FLAG] lines above.`);
  }
  console.log('============================');
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
