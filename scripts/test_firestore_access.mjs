#!/usr/bin/env node

/**
 * Client-side Firestore access smoke test.
 *
 * This script intentionally uses Firebase Auth ID tokens + Firestore REST,
 * not the Admin SDK for reads, so it exercises the same security rules that
 * the Flutter app hits.
 *
 * Usage:
 *   node scripts/test_firestore_access.mjs --email admin@ucc-hcs.com --password "..."
 *
 * Or, when you have a service account and want to test a known Firebase Auth
 * uid without knowing the password:
 *   node scripts/test_firestore_access.mjs --uid gjMuiBGhmrbKDIMWfBNNSJFdMn72 --service-account C:\i\zenda-api-v2\api\serviceAccountKey.json
 */

import crypto from 'node:crypto';
import fs from 'node:fs';

const firebaseConfig = {
  apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
  projectId: 'enovate-zenda',
};

const args = parseArgs(process.argv.slice(2));

main().catch((error) => {
  console.error('\nFAILED');
  console.error(error.message || error);
  process.exit(1);
});

async function main() {
  if (args.help) {
    printUsage();
    return;
  }

  const auth = await signIn();
  const tokenPayload = decodeJwtPayload(auth.idToken);
  const uid = auth.localId || tokenPayload.user_id || tokenPayload.sub;

  console.log('Signed in');
  console.log(`  uid: ${uid}`);
  console.log(`  email: ${auth.email || tokenPayload.email || '(custom token)'}`);

  const profile = await getDocument(`users/${uid}`, auth.idToken);
  const role = profile?.role || tokenPayload.role || '(missing)';
  const schoolId = profile?.schoolId || tokenPayload.schoolId || '';

  console.log('\nProfile');
  console.log(`  role: ${role}`);
  console.log(`  schoolId: ${schoolId || '(missing)'}`);
  console.log(`  name: ${profile?.name || '(missing)'}`);

  if (!schoolId && role !== 'system_owner') {
    console.log('\nSkipping scoped reads: non-owner profile has no schoolId.');
    process.exitCode = 2;
    return;
  }

  console.log('\nFirestore reads');
  if (schoolId && role !== 'system_owner') {
    await tryGetSchool(schoolId, auth.idToken);
    await tryScopedCollection('devices', schoolId, auth.idToken);
    await tryScopedCollection('sessions', schoolId, auth.idToken);
    await tryScopedCollection('students', schoolId, auth.idToken);
    await tryScopedCollection('teachers', schoolId, auth.idToken);
  } else {
    await tryCollectionList('schools', auth.idToken);
    await tryCollectionList('devices', auth.idToken);
    await tryCollectionList('sessions', auth.idToken);
    await tryCollectionList('students', auth.idToken);
  }
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') out.help = true;
    else if (arg.startsWith('--')) out[arg.slice(2)] = argv[++i];
  }
  out.email ||= process.env.FIREBASE_TEST_EMAIL;
  out.password ||= process.env.FIREBASE_TEST_PASSWORD;
  out.uid ||= process.env.FIREBASE_TEST_UID;
  out['service-account'] ||= process.env.FIREBASE_SERVICE_ACCOUNT;
  return out;
}

function printUsage() {
  console.log(`Usage:
  node scripts/test_firestore_access.mjs --email <email> --password <password>
  node scripts/test_firestore_access.mjs --uid <firebase-uid> --service-account <serviceAccountKey.json>

Environment alternatives:
  FIREBASE_TEST_EMAIL
  FIREBASE_TEST_PASSWORD
  FIREBASE_TEST_UID
  FIREBASE_SERVICE_ACCOUNT`);
}

async function signIn() {
  if (args.email && args.password) {
    const url =
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseConfig.apiKey}`;
    return jsonFetch(url, {
      method: 'POST',
      body: {
        email: args.email,
        password: args.password,
        returnSecureToken: true,
      },
    });
  }

  if (args.uid && args['service-account']) {
    const customToken = mintCustomToken(args.uid, args['service-account']);
    const url =
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${firebaseConfig.apiKey}`;
    return jsonFetch(url, {
      method: 'POST',
      body: {
        token: customToken,
        returnSecureToken: true,
      },
    });
  }

  printUsage();
  throw new Error('Provide email/password or uid/service-account.');
}

function mintCustomToken(uid, serviceAccountPath) {
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    iat: now,
    exp: now + 60 * 60,
    uid,
  };
  const unsigned = `${base64urlJson(header)}.${base64urlJson(payload)}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(unsigned)
    .sign(serviceAccount.private_key);
  return `${unsigned}.${base64url(signature)}`;
}

async function getDocument(path, idToken) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${firebaseConfig.projectId}/databases/(default)/documents/${path}`;
  const data = await jsonFetch(url, { idToken });
  return documentToObject(data);
}

async function tryGetSchool(schoolId, idToken) {
  try {
    const school = await getDocument(`schools/${schoolId}`, idToken);
    console.log(`  schools/${schoolId}: OK (${school.name || 'unnamed'})`);
  } catch (e) {
    console.log(`  schools/${schoolId}: DENIED/FAILED (${e.message})`);
  }
}

async function tryScopedCollection(collectionId, schoolId, idToken) {
  const body = {
    structuredQuery: {
      from: [{ collectionId }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'schoolId' },
          op: 'EQUAL',
          value: { stringValue: schoolId },
        },
      },
      limit: 20,
    },
  };

  try {
    const rows = await runQuery(body, idToken);
    console.log(`  ${collectionId}.where(schoolId == ${schoolId}): OK (${rows.length})`);
    printSamples(rows);
  } catch (e) {
    console.log(`  ${collectionId}.where(schoolId == ${schoolId}): DENIED/FAILED (${e.message})`);
  }
}

async function tryCollectionList(collectionId, idToken) {
  const body = {
    structuredQuery: {
      from: [{ collectionId }],
      limit: 20,
    },
  };

  try {
    const rows = await runQuery(body, idToken);
    console.log(`  ${collectionId}: OK (${rows.length})`);
    printSamples(rows);
  } catch (e) {
    console.log(`  ${collectionId}: DENIED/FAILED (${e.message})`);
  }
}

async function runQuery(body, idToken) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${firebaseConfig.projectId}/databases/(default)/documents:runQuery`;
  const result = await jsonFetch(url, {
    method: 'POST',
    idToken,
    body,
  });
  return result
    .filter((row) => row.document)
    .map((row) => documentToObject(row.document));
}

function printSamples(rows) {
  for (const row of rows.slice(0, 3)) {
    const label =
      row.deviceName ||
      row.name ||
      row.className ||
      row.teacherName ||
      row.email ||
      row.id;
    console.log(`    - ${label}`);
  }
}

async function jsonFetch(url, { method = 'GET', idToken, body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = data?.error?.message || `${response.status} ${response.statusText}`;
    throw new Error(message);
  }
  return data;
}

function documentToObject(doc) {
  const name = doc.name || '';
  const id = name.substring(name.lastIndexOf('/') + 1);
  return {
    id,
    ...fieldsToObject(doc.fields || {}),
  };
}

function fieldsToObject(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, firestoreValueToJs(value)]),
  );
}

function firestoreValueToJs(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(firestoreValueToJs);
  }
  if ('mapValue' in value) return fieldsToObject(value.mapValue.fields || {});
  return value;
}

function decodeJwtPayload(jwt) {
  const payload = jwt.split('.')[1];
  return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
}

function base64urlJson(value) {
  return base64url(Buffer.from(JSON.stringify(value)));
}

function base64url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}
