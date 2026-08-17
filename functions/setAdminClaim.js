/**
 * One-time bootstrap script to grant admin role via Firebase Custom Claims.
 *
 * USAGE — run ONCE locally, after `firebase login` and `firebase use <project>`:
 *
 *   cd functions
 *   npm install
 *   node setAdminClaim.js support.chaniiapps@gmail.com
 *
 * After running, the targeted user becomes admin. Their ID token will refresh
 * on next sign-in (or call authManager.refreshAdminClaim() in the app).
 *
 * Security rules can then check:
 *   request.auth.token.admin == true
 *
 * To revoke admin:
 *   node setAdminClaim.js support.chaniiapps@gmail.com --revoke
 */

const admin = require("firebase-admin");

admin.initializeApp({
    credential: admin.credential.applicationDefault(),
});

async function main() {
    const args = process.argv.slice(2);
    if (args.length < 1) {
        console.error("Usage: node setAdminClaim.js <email> [--revoke]");
        process.exit(1);
    }
    const email = args[0];
    const revoke = args.includes("--revoke");

    const user = await admin.auth().getUserByEmail(email);
    const claims = revoke ? {} : { admin: true };
    await admin.auth().setCustomUserClaims(user.uid, claims);

    console.log(`${revoke ? "Revoked" : "Granted"} admin claim for ${email} (uid: ${user.uid})`);
    console.log("User must sign out and back in for token to refresh, OR call authManager.refreshAdminClaim().");
    process.exit(0);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
