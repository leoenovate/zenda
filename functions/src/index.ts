import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Promote a Firebase Auth user to a given role with optional schoolId.
 *
 * Callable only by an authenticated caller whose own custom claim
 * `role === "system_owner"`. Bootstrap: the very first call is allowed if
 * there is no existing user with the `system_owner` claim.
 */
export const setRoleClaim = onCall(async (request) => {
  const { email, role, schoolId } = request.data as {
    email?: string;
    role?: string;
    schoolId?: string | null;
  };

  if (!email || !role) {
    throw new HttpsError("invalid-argument", "email and role are required");
  }

  const caller = request.auth;
  if (!caller) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const callerRole = (caller.token.role as string | undefined) ?? null;
  if (callerRole !== "system_owner") {
    // Bootstrap: allow the very first owner to be promoted when none exists.
    const owners = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "system_owner")
      .limit(1)
      .get();
    if (!owners.empty) {
      throw new HttpsError(
        "permission-denied",
        "Only system_owner can assign roles"
      );
    }
    if (role !== "system_owner") {
      throw new HttpsError(
        "permission-denied",
        "Bootstrap can only promote the first system_owner"
      );
    }
  }

  const user = await admin.auth().getUserByEmail(email);
  const claims: Record<string, unknown> = { role };
  if (schoolId) claims.schoolId = schoolId;
  await admin.auth().setCustomUserClaims(user.uid, claims);

  // Mirror to users/{uid} so the Firestore rules fallback still works.
  await admin
    .firestore()
    .collection("users")
    .doc(user.uid)
    .set(
      {
        email,
        role,
        ...(schoolId ? { schoolId } : {}),
        claimsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { ok: true, uid: user.uid };
});

/**
 * Keep the `role` / `schoolId` custom claims in sync with changes to the
 * users/{uid} Firestore doc. Without this trigger, rules will always read
 * the user doc directly, which works but adds a `get()` per request.
 */
export const syncClaimsOnUserWrite = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const after = event.data?.after?.data();
    if (!after) {
      // User doc deleted: strip claims.
      try {
        await admin.auth().setCustomUserClaims(uid, {});
      } catch (_) {
        // ignore — auth user may have been deleted already
      }
      return;
    }
    const claims: Record<string, unknown> = {};
    if (typeof after.role === "string") claims.role = after.role;
    if (typeof after.schoolId === "string") claims.schoolId = after.schoolId;
    try {
      await admin.auth().setCustomUserClaims(uid, claims);
    } catch (err) {
      console.warn(`Failed to sync claims for ${uid}:`, err);
    }
  }
);
