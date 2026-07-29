'use strict';

/**
 * Seed the Demo School org and built-in demo login accounts into Firestore.
 *
 * Mirrors the synthetic fallbacks in lib/services/auth_service.dart so every
 * credential on the login screen resolves to real documents:
 *   - owner@school.com / owner123        (system owner)
 *   - admin@school.com / admin123        (school admin)
 *   - teacher@school.com / teacher123    (teacher)
 *   - 0780000001 / guardian123           (guardian + STD001 student)
 *
 * Idempotent: uses stable doc ids and merge writes.
 *
 *   node seed_demo.js           # dry-run (default)
 *   node seed_demo.js --commit  # write to Firestore
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');
const M = require('./mapping');

const DRY_RUN = !process.argv.includes('--commit');

const DEMO_ORG_ID = 'demo-school';
const DEMO_STUDENT_ID = 'demo-student-STD001';
const DEMO_TEACHER_MEMBER_ID = 'demo-teacher';
const DEMO_DEVICE_DOC_ID = 'demo-device';
const DEMO_DEVICE_ID = 'DEMO0001';

const DEMO_USERS = [
  {
    id: 'demo-owner',
    email: 'owner@school.com',
    password: 'owner123',
    name: 'Demo Owner',
    role: 'system_owner',
    orgId: null,
  },
  {
    id: 'demo-admin',
    email: 'admin@school.com',
    password: 'admin123',
    name: 'Demo Admin',
    role: 'admin',
    orgId: DEMO_ORG_ID,
  },
  {
    id: 'demo-teacher',
    email: 'teacher@school.com',
    password: 'teacher123',
    name: 'Demo Teacher',
    role: 'teacher',
    orgId: DEMO_ORG_ID,
    memberId: DEMO_TEACHER_MEMBER_ID,
  },
];

const DEMO_GUARDIAN = {
  id: 'demo-guardian',
  phone: '0780000001',
  password: 'guardian123',
  name: 'Demo Guardian',
  role: 'parent',
  orgId: DEMO_ORG_ID,
  linkedStudentIds: [DEMO_STUDENT_ID],
};

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

function generateSalt() {
  return crypto.randomBytes(16).toString('hex');
}

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${salt}${password}`, 'utf8').digest('hex');
}

function userDoc({ email, password, name, role, orgId, phone, memberId, linkedStudentIds }) {
  const salt = generateSalt();
  const out = {
    email: email ? email.trim().toLowerCase() : '',
    name,
    role,
    passwordSalt: salt,
    passwordHash: hashPassword(password, salt),
    isActive: true,
    passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (orgId) {
    out.orgId = orgId;
    if (role === 'parent') {
      out.roleId = M.guardianRoleId(orgId);
    }
  }
  if (phone) out.phone = phone;
  if (memberId) out.memberId = memberId;
  if (linkedStudentIds) out.linkedStudentIds = linkedStudentIds;
  return out;
}

function demoStudentBirthdate() {
  const year = new Date().getFullYear() - 10;
  return new Date(year, 0, 1).toISOString();
}

async function main() {
  const via = initAdmin();
  const db = admin.firestore();
  const ts = admin.firestore.FieldValue.serverTimestamp();

  console.log('--------------------------------------------------------------');
  console.log(`Demo school seed  (project: ${M.PROJECT_ID})`);
  console.log(`Credentials via: ${via}`);
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'COMMIT (writing)'}`);
  console.log('--------------------------------------------------------------');

  const writes = [
    {
      label: `organizations/${DEMO_ORG_ID}`,
      ref: db.collection('organizations').doc(DEMO_ORG_ID),
      data: {
        type: 'school',
        name: 'Demo School',
        code: 'DEMO',
        tagline: 'Explore Zenda end-to-end',
        description: 'Built-in demo organization for onboarding and QA.',
        country: 'Rwanda',
        city: 'Kigali',
        isActive: true,
        createdAt: ts,
      },
    },
    {
      label: `roles/${M.guardianRoleId(DEMO_ORG_ID)}`,
      ref: db.collection('roles').doc(M.guardianRoleId(DEMO_ORG_ID)),
      data: {
        ...M.guardianRoleDoc(DEMO_ORG_ID),
        createdAt: ts,
        updatedAt: ts,
      },
    },
    {
      label: `devices/${DEMO_DEVICE_DOC_ID} (${DEMO_DEVICE_ID})`,
      ref: db.collection('devices').doc(DEMO_DEVICE_DOC_ID),
      data: {
        deviceId: DEMO_DEVICE_ID,
        deviceName: 'Demo Scanner',
        deviceType: 'fingerprint_scanner',
        orgId: DEMO_ORG_ID,
        schoolId: DEMO_ORG_ID,
        location: 'Demo School — Main entrance',
        isActive: true,
        status: 'active',
        isOnline: false,
        createdAt: ts,
      },
    },
    {
      label: `members/${DEMO_TEACHER_MEMBER_ID}`,
      ref: db.collection('members').doc(DEMO_TEACHER_MEMBER_ID),
      data: {
        kind: 'teacher',
        orgId: DEMO_ORG_ID,
        name: 'Demo Teacher',
        email: 'teacher@school.com',
        subject: 'General Studies',
        groupIds: [],
        isActive: true,
        createdAt: ts,
      },
    },
    {
      label: `members/${DEMO_STUDENT_ID}`,
      ref: db.collection('members').doc(DEMO_STUDENT_ID),
      data: {
        kind: 'student',
        orgId: DEMO_ORG_ID,
        name: 'Demo Student',
        registrationNumber: 'STD001',
        gender: 'Male',
        birthdate: demoStudentBirthdate(),
        guardianName: 'Demo Father',
        guardianPhone: '0780000001',
        guardianName2: 'Demo Mother',
        guardianPhone2: '0780000002',
        country: 'Rwanda',
        province: 'Kigali',
        district: 'Gasabo',
        sector: 'Kimironko',
        cell: 'Kibagabaga',
        groupIds: [],
        attendanceHistory: [],
        isActive: true,
        createdAt: ts,
      },
    },
    ...DEMO_USERS.map((u) => ({
      label: `users/${u.id} (${u.email})`,
      ref: db.collection('users').doc(u.id),
      data: {
        ...userDoc(u),
        createdAt: ts,
      },
    })),
    {
      label: `users/${DEMO_GUARDIAN.id} (${DEMO_GUARDIAN.phone})`,
      ref: db.collection('users').doc(DEMO_GUARDIAN.id),
      data: {
        ...userDoc(DEMO_GUARDIAN),
        createdAt: ts,
      },
    },
  ];

  for (const { label, ref, data } of writes) {
    console.log(`[seed] ${label}`);
    if (!DRY_RUN) {
      await ref.set(data, { merge: true });
    }
  }

  console.log('--------------------------------------------------------------');
  console.log(
    DRY_RUN
      ? `Would seed ${writes.length} documents. Re-run with --commit to write.`
      : `Seeded ${writes.length} documents.`,
  );
  console.log('Demo logins:');
  console.log('  owner@school.com / owner123');
  console.log('  admin@school.com / admin123');
  console.log('  teacher@school.com / teacher123');
  console.log('  0780000001 / guardian123  (student STD001)');
  console.log(`Device: ${DEMO_DEVICE_ID} (Demo Scanner)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
