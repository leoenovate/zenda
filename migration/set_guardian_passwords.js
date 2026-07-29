'use strict';

/**
 * Seed login passwords for migrated guardian (parent) `users` documents.
 *
 * The schema migration (migrate.js) creates guardian login accounts in
 * `users` from the old `parents` collection, but parents never had a
 * password, so those accounts cannot sign in yet. This one-off script
 * writes a `passwordHash` / `passwordSalt` (same algorithm as the Flutter
 * `AuthService.hashPassword`: SHA-256 hex of `salt + password`) plus
 * `mustChangePassword: true` so guardians can log in with a temporary
 * password and be forced to change it.
 *
 * Workflow:
 *   1. Keep DRY_RUN = true, run `node set_guardian_passwords.js`, review.
 *   2. Set DRY_RUN = false (or pass --commit), run again to write.
 *
 * A guardian user is any `users` doc that looks like a parent account:
 *   - has a non-empty `linkedStudentIds` array, OR
 *   - has `roleId` starting with `guardian-`, OR
 *   - has `role` == 'guardian' | 'parent'.
 *
 * Accounts that already have a `passwordHash` are left untouched (idempotent).
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');
const M = require('./mapping');

// When true: read everything, write NOTHING, just log what would happen.
const DRY_RUN = !process.argv.includes('--commit');

// Temporary password handed to every seeded guardian. Override with
// TEMP_PASSWORD=... in the environment. Guardians are flagged
// mustChangePassword so the app can prompt them to set their own.
const TEMP_PASSWORD = process.env.TEMP_PASSWORD || 'guardian123';

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
  admin.initializeApp({ projectId: M.PROJECT_ID });
  return 'application-default (no explicit key found)';
}

// --- password hashing (mirrors lib/services/auth_service.dart) -------------

function generateSalt() {
  // 16 random bytes -> 32 lowercase hex chars (matches Dart generateSalt()).
  return crypto.randomBytes(16).toString('hex');
}

function hashPassword(password, salt) {
  // SHA-256 hex of (salt + password), same as Dart hashPassword().
  return crypto.createHash('sha256').update(`${salt}${password}`, 'utf8').digest('hex');
}

function isGuardianDoc(data) {
  const linked = Array.isArray(data.linkedStudentIds) ? data.linkedStudentIds : [];
  const roleId = typeof data.roleId === 'string' ? data.roleId : '';
  const role = typeof data.role === 'string' ? data.role : '';
  return (
    linked.length > 0 ||
    roleId.startsWith('guardian-') ||
    role === 'guardian' ||
    role === 'parent'
  );
}

async function main() {
  const via = initAdmin();
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  console.log('--------------------------------------------------------------');
  console.log(`Guardian password seeding  (project: ${M.PROJECT_ID})`);
  console.log(`Credentials via: ${via}`);
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'COMMIT (writing)'}`);
  console.log(`Temp password: "${TEMP_PASSWORD}"  (mustChangePassword=true)`);
  console.log('--------------------------------------------------------------');

  const snap = await db.collection('users').get();
  let guardians = 0;
  let seeded = 0;
  let alreadySet = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!isGuardianDoc(data)) continue;
    guardians++;

    const label = data.name || data.phone || data.email || doc.id;
    const hasHash = typeof data.passwordHash === 'string' && data.passwordHash.length > 0;
    if (hasHash) {
      alreadySet++;
      console.log(`[skip]   ${label} - password already set`);
      continue;
    }

    const salt = generateSalt();
    const hash = hashPassword(TEMP_PASSWORD, salt);
    seeded++;
    console.log(`[seed]   ${label} (${doc.id})`);

    if (!DRY_RUN) {
      await doc.ref.set(
        {
          passwordSalt: salt,
          passwordHash: hash,
          mustChangePassword: true,
          passwordUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  }

  console.log('--------------------------------------------------------------');
  console.log(`Guardian users found : ${guardians}`);
  console.log(`Already had password : ${alreadySet}`);
  console.log(`Seeded this run      : ${seeded}${DRY_RUN ? ' (dry-run, not written)' : ''}`);
  console.log('--------------------------------------------------------------');
  if (DRY_RUN) {
    console.log('Dry run only. Re-run with --commit (or DRY_RUN=false) to write.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seeding failed:', err);
    process.exit(1);
  });
