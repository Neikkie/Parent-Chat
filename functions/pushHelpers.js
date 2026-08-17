/**
 * Shared helper: push an FCM notification to every device a user has
 * registered (stored under /users/{uid}/fcmTokens/{token}). Invalid tokens
 * are cleaned up automatically.
 */

const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

async function sendPushToUser(userId, notification, data = {}) {
    if (!userId) return;

    const db = getFirestore();
    const snap = await db
        .collection("users").doc(userId)
        .collection("fcmTokens").get();

    const tokens = snap.docs.map((d) => d.id).filter(Boolean);
    if (tokens.length === 0) return;

    // FCM data payloads must be all-strings.
    const stringData = {};
    for (const [k, v] of Object.entries(data)) stringData[k] = String(v ?? "");

    const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification,
        data: stringData,
        apns: { payload: { aps: { sound: "default" } } },
    });

    // Prune tokens that are no longer valid so we don't keep retrying them.
    const deletions = [];
    response.responses.forEach((r, i) => {
        if (r.success) return;
        const code = r.error?.code || "";
        if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-registration-token") ||
            code.includes("invalid-argument")
        ) {
            deletions.push(
                db.collection("users").doc(userId)
                    .collection("fcmTokens").doc(tokens[i]).delete()
            );
        }
    });
    await Promise.allSettled(deletions);
}

module.exports = { sendPushToUser };
