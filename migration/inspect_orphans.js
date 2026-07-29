'use strict';
// READ-ONLY diagnostic: find parents that won't resolve an org during
// migration, list their linked students, and suggest a school from any class
// the student belongs to. Writes nothing.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const M = require('./mapping');

function initAdmin() {
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: M.PROJECT_ID });
  } else if (fs.existsSync(keyPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(keyPath)), projectId: M.PROJECT_ID });
  } else {
    admin.initializeApp({ projectId: M.PROJECT_ID });
  }
}

async function main() {
  initAdmin();
  const db = admin.firestore();

  const schoolsSnap = await db.collection('schools').get();
  const schoolName = {};
  console.log('\n# Schools');
  for (const d of schoolsSnap.docs) {
    schoolName[d.id] = d.data().name || '(no name)';
    console.log(`  ${d.id}  "${schoolName[d.id]}"`);
  }

  const studentsSnap = await db.collection('students').get();
  const studentById = {};
  const studentOrgById = {};
  let studentsNoOrg = 0;
  for (const s of studentsSnap.docs) {
    studentById[s.id] = s.data();
    const org = s.data().schoolId;
    if (org) studentOrgById[s.id] = org;
    else studentsNoOrg++;
  }
  console.log(`\n# Students: ${studentsSnap.size} total, ${studentsNoOrg} with no schoolId`);

  // class membership -> school hint
  const classesSnap = await db.collection('classes').get();
  const classByStudent = {};
  for (const c of classesSnap.docs) {
    const cd = c.data();
    for (const sid of (Array.isArray(cd.studentIds) ? cd.studentIds : [])) {
      (classByStudent[sid] ||= []).push({ name: cd.name || c.id, schoolId: cd.schoolId || null });
    }
  }

  const parentsSnap = await db.collection('parents').get();
  console.log('\n# Parents with NO resolvable org');
  let n = 0;
  for (const p of parentsSnap.docs) {
    const pd = p.data();
    if (M.resolveParentOrgId(pd, studentOrgById)) continue;
    n++;
    console.log(`\nparent ${p.id}  name="${pd.name || '-'}"  phone=${pd.phone || '-'}  schoolId=${pd.schoolId || 'null'}`);
    const ids = Array.isArray(pd.studentIds) ? pd.studentIds : [];
    if (ids.length === 0) {
      console.log('  (no linked studentIds)');
      continue;
    }
    for (const sid of ids) {
      const sd = studentById[sid];
      if (!sd) {
        console.log(`  student ${sid}  -> MISSING from students collection`);
        continue;
      }
      const cls = classByStudent[sid] || [];
      const hint = cls.length
        ? cls.map((c) => `${c.name} (school ${c.schoolId || 'null'})`).join(', ')
        : 'no class';
      console.log(`  student ${sid}  name="${sd.name || '-'}"  schoolId=${sd.schoolId || 'null'}  classHint=[${hint}]`);
    }
  }
  if (n === 0) console.log('  (none)');
  console.log(`\nUnresolved parents: ${n}`);
}

main().then(() => process.exit(0)).catch((e) => {
  console.error('FATAL:', e && e.stack ? e.stack : e);
  process.exit(1);
});
