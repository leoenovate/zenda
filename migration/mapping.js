'use strict';

/**
 * Single source of truth for the Zenda Firestore migration.
 *
 * Both migrate.js and verify.js import this module so the verification logic
 * can never drift from what the migration actually writes.
 *
 * Every transform is a PURE function of (id, data). It returns:
 *   { data: {<fields to write>}, deletes: [<field names to remove>] }
 *
 * `deletes` is only ever non-empty for in-place collections when
 * KEEP_LEGACY_FIELDS is false (the destructive cutover mode). migrate.js turns
 * those names into FieldValue.delete() sentinels.
 */

const PROJECT_ID = 'enovate-zenda';
const BATCH_SIZE = 400; // Firestore hard limit is 500; stay under it.

/**
 * Controls the same-named "in place" collections only.
 *
 *  - true  (default, SAFE): additive. New fields are added; every original
 *          field/value is preserved so the still-deployed app keeps working.
 *  - false (opt-in cutover): faithful to the spec — true renames, the
 *          messages.sender value-rename, and legacy session-field strips.
 *          Destructive to the old shape.
 *
 * Brand-new collections (organizations/members/groups/time_off, guardian
 * users) are always written in the faithful new shape regardless of this flag.
 */
const KEEP_LEGACY_FIELDS = true;

// --- helpers ---------------------------------------------------------------

/**
 * Lowercase slug: drop punctuation (incl. dots), spaces -> "_", collapse.
 * Matches the spec example: "I.T Officer" -> "it_officer".
 */
function slugify(name) {
  return String(name == null ? '' : name)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function accessLevelFor(roleName) {
  const s = slugify(roleName);
  if (s === 'system_owner' || s === 'admin' || s === 'school_admin') return 'admin';
  if (s === 'teacher' || s === 'staff') return 'staff';
  return 'viewer';
}

function canLogIn(accessLevel) {
  return accessLevel === 'admin' || accessLevel === 'staff';
}

function guardianRoleId(orgId) {
  return `guardian-${orgId}`;
}

function guardianRoleDoc(orgId) {
  // Guardians authenticate (they are migrated parents), so canLogIn is forced
  // true even though the derived accessLevel is "viewer".
  return {
    name: 'Guardian',
    description: 'Auto-created during migration for parent/guardian accounts.',
    schoolId: orgId,
    orgId,
    accessLevel: 'viewer',
    audienceKey: 'guardian',
    canLogIn: true,
    isActive: true,
  };
}

function setIfDefined(out, key, value) {
  if (value !== undefined) out[key] = value;
}

function pick(data, keys) {
  const out = {};
  for (const k of keys) if (data[k] !== undefined) out[k] = data[k];
  return out;
}

// --- transforms ------------------------------------------------------------

// 1. schools -> organizations  (all fields carry over + type)
function transformSchool(id, data) {
  return { data: { ...data, type: 'school' }, deletes: [] };
}

// 2. roles -> roles (in place, extended). schoolId is kept (also written as
//    orgId) per spec, so there is nothing to delete even in cutover mode.
function transformRole(id, data) {
  const accessLevel = accessLevelFor(data.name);
  const out = {
    accessLevel,
    audienceKey: slugify(data.name),
    canLogIn: canLogIn(accessLevel),
  };
  setIfDefined(out, 'orgId', data.schoolId);
  return { data: out, deletes: [] };
}

// 7. classes -> groups
function transformClassToGroup(id, data) {
  const out = {
    ...pick(data, ['name', 'grade', 'level']),
    orgId: data.schoolId !== undefined ? data.schoolId : null,
    supervisorId: data.teacherId !== undefined ? data.teacherId : null,
    memberIds: Array.isArray(data.studentIds) ? data.studentIds : [],
    isActive: data.isActive !== undefined ? data.isActive : true,
  };
  setIfDefined(out, 'createdAt', data.createdAt);
  return { data: out, deletes: [] };
}

// shared base for teacher/worker members
function memberCommon(data) {
  const out = {
    orgId: data.schoolId !== undefined ? data.schoolId : null,
    groupIds: [],
    isActive: data.isActive !== undefined ? data.isActive : true,
  };
  // `name` is not in the spec's field list but a member is unusable without it.
  setIfDefined(out, 'name', data.name);
  setIfDefined(out, 'roleId', data.roleId);
  setIfDefined(out, 'phone', data.phone);
  setIfDefined(out, 'email', data.email);
  setIfDefined(out, 'fingerprintData', data.fingerprintData);
  setIfDefined(out, 'fingerprintTimestamp', data.fingerprintTimestamp);
  setIfDefined(out, 'employeeId', data.employeeId);
  setIfDefined(out, 'createdAt', data.createdAt);
  return out;
}

// 4a. teachers -> members
function transformTeacherMember(id, data) {
  const out = memberCommon(data);
  out.kind = 'teacher';
  setIfDefined(out, 'subject', data.subject);
  setIfDefined(out, 'legacyClassId', data.classId);
  return { data: out, deletes: [] };
}

// 4b. workers -> members
function transformWorkerMember(id, data) {
  const out = memberCommon(data);
  out.kind = 'worker';
  // Legacy free-form label lived on `role`.
  setIfDefined(out, 'legacyRoleLabel', data.role);
  return { data: out, deletes: [] };
}

// 5. students -> members
function transformStudentMember(id, data) {
  const out = {
    orgId: data.schoolId !== undefined ? data.schoolId : null,
    groupIds: [],
    kind: 'student',
    isActive: true,
  };
  setIfDefined(out, 'name', data.name);
  setIfDefined(out, 'registrationNumber', data.registrationNumber);
  setIfDefined(out, 'gender', data.gender);
  setIfDefined(out, 'birthdate', data.birthdate);

  const primaryName = data.fatherName !== undefined ? data.fatherName : data.motherName;
  const primaryPhone = data.fatherPhone !== undefined ? data.fatherPhone : data.motherPhone;
  setIfDefined(out, 'guardianName', primaryName);
  setIfDefined(out, 'guardianPhone', primaryPhone);
  if (data.motherName !== undefined && data.motherName !== primaryName) {
    out.guardianName2 = data.motherName;
  }
  if (data.motherPhone !== undefined && data.motherPhone !== primaryPhone) {
    out.guardianPhone2 = data.motherPhone;
  }

  for (const f of ['country', 'province', 'district', 'sector', 'cell',
    'fingerprintData', 'fingerprintTimestamp']) {
    setIfDefined(out, f, data[f]);
  }
  out.attendanceHistory = Array.isArray(data.attendanceHistory) ? data.attendanceHistory : [];
  if (data.sessionIds !== undefined) out.legacySessionIds = data.sessionIds;
  setIfDefined(out, 'createdAt', data.createdAt);
  return { data: out, deletes: [] };
}

// 3. users -> users (in place). Add orgId; keep schoolId unless cutover.
function transformUser(id, data) {
  const out = {};
  setIfDefined(out, 'orgId', data.schoolId);
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS && data.schoolId !== undefined) deletes.push('schoolId');
  // memberId intentionally NOT populated (spec step 3 note).
  return { data: out, deletes };
}

// 6. parents -> users (guardian account). Needs the org's Guardian role id.
function transformParentToUser(id, data) {
  const orgId = data.schoolId !== undefined ? data.schoolId : null;
  const out = {
    orgId,
    memberId: null,
    roleId: orgId ? guardianRoleId(orgId) : null,
    linkedStudentIds: Array.isArray(data.studentIds) ? data.studentIds : [],
  };
  setIfDefined(out, 'phone', data.phone);
  setIfDefined(out, 'name', data.name);
  setIfDefined(out, 'email', data.email);
  out.isActive = data.isActive !== undefined ? data.isActive : true;
  setIfDefined(out, 'createdAt', data.createdAt);
  setIfDefined(out, 'lastLogin', data.lastLogin);
  return { data: out, deletes: [] };
}

// 8. sessions -> sessions (in place). Add orgId/groupIds/groupNames; strip
//    legacy mirror fields only in cutover mode. attendees[].kind unchanged.
function transformSession(id, data) {
  const out = {};
  setIfDefined(out, 'orgId', data.schoolId);
  if (data.classIds !== undefined) out.groupIds = data.classIds;
  if (data.classNames !== undefined) out.groupNames = data.classNames;
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS) {
    const legacy = [
      'schoolId', 'classIds', 'classNames', 'audienceType', 'audienceMode',
      'audienceRole', 'assigneeKind', 'assigneeId', 'assigneeName',
      'classId', 'className', 'audienceLabel',
    ];
    for (const f of legacy) if (data[f] !== undefined) deletes.push(f);
  }
  return { data: out, deletes };
}

// 9. worker_time_off -> time_off
function transformTimeOff(id, data) {
  const out = { orgId: data.schoolId !== undefined ? data.schoolId : null };
  setIfDefined(out, 'memberId', data.assigneeId);
  setIfDefined(out, 'memberName', data.assigneeName);
  for (const f of ['startDate', 'endDate', 'type', 'notes', 'status',
    'attachmentBase64', 'attachmentContentType', 'attachmentFileName', 'createdAt']) {
    setIfDefined(out, f, data[f]);
  }
  // assigneeKind / workerId / workerName intentionally dropped.
  return { data: out, deletes: [] };
}

// 10. messages -> messages (in place). Add memberId; value-rename sender and
//     drop studentId only in cutover mode.
function transformMessage(id, data) {
  const out = {};
  setIfDefined(out, 'memberId', data.studentId);
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS) {
    if (data.studentId !== undefined) deletes.push('studentId');
    if (data.sender === 'school') out.sender = 'org';
    else if (data.sender === 'parent') out.sender = 'guardian';
  }
  return { data: out, deletes };
}

// 11. devices -> devices (in place).
function transformDevice(id, data) {
  const out = {};
  setIfDefined(out, 'orgId', data.schoolId);
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS && data.schoolId !== undefined) deletes.push('schoolId');
  return { data: out, deletes };
}

// 12. api_logs -> api_logs (in place).
function transformApiLog(id, data) {
  const out = {};
  setIfDefined(out, 'memberId', data.studentId);
  setIfDefined(out, 'memberName', data.studentName);
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS) {
    if (data.studentId !== undefined) deletes.push('studentId');
    if (data.studentName !== undefined) deletes.push('studentName');
  }
  return { data: out, deletes };
}

// 13a. device_enrollments -> device_enrollments (rename schoolId -> orgId).
function transformDeviceEnrollment(id, data) {
  const out = {};
  setIfDefined(out, 'orgId', data.schoolId);
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS && data.schoolId !== undefined) deletes.push('schoolId');
  return { data: out, deletes };
}

// 13b. fingerprints -> fingerprints (copy as-is; rename schoolId if present).
function transformFingerprint(id, data) {
  const out = {};
  if (data.schoolId !== undefined) out.orgId = data.schoolId;
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS && data.schoolId !== undefined) deletes.push('schoolId');
  return { data: out, deletes };
}

// 13c. system/config -> system/config (rename schoolId if present).
function transformSystemDoc(id, data) {
  const out = {};
  if (data.schoolId !== undefined) out.orgId = data.schoolId;
  const deletes = [];
  if (!KEEP_LEGACY_FIELDS && data.schoolId !== undefined) deletes.push('schoolId');
  return { data: out, deletes };
}

// --- collection map --------------------------------------------------------

// Straight per-collection passes. `parents` is handled by a dedicated pass in
// migrate.js because it also creates the per-org Guardian roles.
const MIGRATIONS = [
  { source: 'schools', target: 'organizations', transform: transformSchool, inPlace: false },
  { source: 'roles', target: 'roles', transform: transformRole, inPlace: true },
  { source: 'classes', target: 'groups', transform: transformClassToGroup, inPlace: false },
  { source: 'teachers', target: 'members', transform: transformTeacherMember, inPlace: false },
  { source: 'workers', target: 'members', transform: transformWorkerMember, inPlace: false },
  { source: 'students', target: 'members', transform: transformStudentMember, inPlace: false },
  { source: 'users', target: 'users', transform: transformUser, inPlace: true },
  { source: 'sessions', target: 'sessions', transform: transformSession, inPlace: true },
  { source: 'worker_time_off', target: 'time_off', transform: transformTimeOff, inPlace: false },
  { source: 'messages', target: 'messages', transform: transformMessage, inPlace: true },
  { source: 'devices', target: 'devices', transform: transformDevice, inPlace: true },
  { source: 'api_logs', target: 'api_logs', transform: transformApiLog, inPlace: true },
  { source: 'device_enrollments', target: 'device_enrollments', transform: transformDeviceEnrollment, inPlace: true },
  { source: 'fingerprints', target: 'fingerprints', transform: transformFingerprint, inPlace: true },
  { source: 'system', target: 'system', transform: transformSystemDoc, inPlace: true },
];

// Every collection name verify.js should count, in a friendly order.
const COUNT_COLLECTIONS = [
  'schools', 'organizations',
  'classes', 'groups',
  'teachers', 'workers', 'students', 'members',
  'roles',
  'users', 'parents',
  'sessions',
  'worker_time_off', 'time_off',
  'messages', 'devices', 'api_logs',
  'device_enrollments', 'fingerprints', 'system',
];

// Brand-new collections where orgId is mandatory (hard-flagged by verify).
const ORG_REQUIRED_COLLECTIONS = ['organizations', 'members', 'groups', 'time_off'];

module.exports = {
  PROJECT_ID,
  BATCH_SIZE,
  KEEP_LEGACY_FIELDS,
  MIGRATIONS,
  COUNT_COLLECTIONS,
  ORG_REQUIRED_COLLECTIONS,
  // helpers
  slugify,
  accessLevelFor,
  canLogIn,
  guardianRoleId,
  guardianRoleDoc,
  // transforms (exported so verify.js can recompute expectations)
  transformSchool,
  transformRole,
  transformClassToGroup,
  transformTeacherMember,
  transformWorkerMember,
  transformStudentMember,
  transformUser,
  transformParentToUser,
  transformSession,
  transformTimeOff,
  transformMessage,
  transformDevice,
  transformApiLog,
  transformDeviceEnrollment,
  transformFingerprint,
  transformSystemDoc,
};
