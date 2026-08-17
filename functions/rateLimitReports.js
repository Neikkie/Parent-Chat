/**
 * Rate-limit user reports to prevent harassment-by-report.
 * If a user files more than MAX_REPORTS_PER_WINDOW within RATE_WINDOW_MS,
 * subsequent reports from that uid are auto-marked as "rate_limited" and
 * dismissed (the admin still sees them in the queue but they're flagged).
 *
 * Deploy:
 *   firebase deploy --only functions:rateLimitReports
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp, getApp } = require("firebase-admin/app");

try { getApp(); } catch { initializeApp(); }

const MAX_REPORTS_PER_WINDOW = 5;
const RATE_WINDOW_MS = 60 * 60 * 1000; // 1 hour

exports.rateLimitReports = onDocumentCreated("reports/{reportId}", async (event) => {
    const db = getFirestore();
    const report = event.data?.data();
    if (!report) return;

    const reporterUid = report.reportedByUserId;
    if (!reporterUid) return;

    const since = new Date(Date.now() - RATE_WINDOW_MS);
    const recent = await db.collection("reports")
        .where("reportedByUserId", "==", reporterUid)
        .where("createdAt", ">=", since)
        .get();

    if (recent.size > MAX_REPORTS_PER_WINDOW) {
        await event.data.ref.update({
            status: "rate_limited",
            rateLimitedAt: FieldValue.serverTimestamp(),
            rateLimitReason: `Reporter exceeded ${MAX_REPORTS_PER_WINDOW} reports per hour.`,
        });
        console.warn(`Rate-limited report ${event.params.reportId} from ${reporterUid}`);
    }
});
