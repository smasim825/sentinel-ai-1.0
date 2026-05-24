const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Function: forceResetPassword
 * Called from the Flutter app after OTP has been verified.
 */
exports.forceResetPassword = onCall(async (request) => {
  const {email, otp, newPassword} = request.data;

  if (!email || !otp || !newPassword) {
    throw new HttpsError("invalid-argument", "Missing parameters.");
  }

  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password too short.");
  }

  // 1. Verify the OTP from Firestore
  const otpRef = db.collection("email_otps").doc(email.toLowerCase());
  const otpDoc = await otpRef.get();

  if (!otpDoc.exists) {
    throw new HttpsError("not-found", "OTP not found.");
  }

  const data = otpDoc.data();
  const expiresAt = data.expiresAt.toDate();
  const storedCode = data.code;

  if (new Date() > expiresAt) {
    await otpRef.delete();
    throw new HttpsError("deadline-exceeded", "OTP has expired.");
  }

  if (storedCode !== otp.trim()) {
    throw new HttpsError("permission-denied", "Invalid OTP.");
  }

  // 2. Delete the OTP
  await otpRef.delete();

  // 3. Find the user
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email.toLowerCase());
  } catch (err) {
    throw new HttpsError("not-found", "No account found.");
  }

  // 4. Update password
  await admin.auth().updateUser(userRecord.uid, {password: newPassword});

  return {success: true, message: "Password updated."};
});
