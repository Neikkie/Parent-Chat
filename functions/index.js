/**
 * Firebase Cloud Functions — Parent Chat moderation notifications.
 *
 * Sends you an email the moment any `/reports/{id}` document is created.
 * Designed to plug into the official "Trigger Email" Firebase Extension:
 *
 *   1. In Firebase Console → Extensions, install "Trigger Email from Firestore"
 *      (firebase/firestore-send-email). Configure with your SendGrid /
 *      Mailgun / SMTP credentials. Choose `mail` as the collection name.
 *
 *   2. Deploy this function:
 *        cd functions
 *        npm install firebase-functions firebase-admin
 *        firebase deploy --only functions:notifyAdminOnReport
 *
 *   3. Every new /reports doc → this function writes to /mail → the extension
 *      sends you an email at ADMIN_EMAIL.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Push notification when a new post is created.
exports.notifyOnNewPost = require("./notifyOnNewPost").notifyOnNewPost;

// Push the recipient when they receive a new direct message.
exports.notifyOnNewMessage = require("./notifyOnNewMessage").notifyOnNewMessage;

// Push a post's author when someone comments on their post.
exports.notifyOnNewComment = require("./notifyOnNewComment").notifyOnNewComment;

// Rate-limit user reports to prevent harassment-by-report abuse.
exports.rateLimitReports = require("./rateLimitReports").rateLimitReports;

// Change this to your moderator email(s).
const ADMIN_EMAIL = "support.chaniiapps@gmail.com";

exports.notifyAdminOnReport = onDocumentCreated("reports/{reportId}", async (event) => {
    const report = event.data?.data();
    if (!report) return;

    const reportId = event.params.reportId;
    const type = report.type || "content";
    const reason = report.reason || "(no reason given)";
    const reporter = report.reportedByUserId || "(unknown)";
    const contentId = report.contentId || "(unknown)";

    // Try to fetch the reported content for context.
    let contentPreview = "(content unavailable)";
    let authorId = "(unknown)";
    try {
        const collection = type === "comment" ? "comments" : "posts";
        const doc = await db.collection(collection).doc(contentId).get();
        if (doc.exists) {
            const data = doc.data() || {};
            contentPreview = (data.content || "").slice(0, 500);
            authorId = data.userId || "(unknown)";
        }
    } catch (e) {
        console.warn("Failed to fetch reported content", e);
    }

    const subject = `[Parent Chat] New ${type} report: ${reason}`;
    const html = `
        <h2>New report filed</h2>
        <p><strong>Type:</strong> ${type}</p>
        <p><strong>Reason:</strong> ${reason}</p>
        <p><strong>Reporter UID:</strong> ${reporter}</p>
        <p><strong>Author UID:</strong> ${authorId}</p>
        <p><strong>Content ID:</strong> ${contentId}</p>
        <hr/>
        <p><strong>Content preview:</strong></p>
        <blockquote>${escapeHtml(contentPreview)}</blockquote>
        <hr/>
        <p>Review in-app via Settings → Moderation Inbox, or in
        <a href="https://console.firebase.google.com/">Firebase Console</a>.</p>
        <p style="color:#888;font-size:12px">Report ID: ${reportId}</p>
    `;

    await db.collection("mail").add({
        to: ADMIN_EMAIL,
        message: { subject, html }
    });
});

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}
