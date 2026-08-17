/**
 * Sends a push to a post's author when someone else comments on it.
 * Trigger: /comments/{commentId}.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { sendPushToUser } = require("./pushHelpers");

try { getApp(); } catch { initializeApp(); }

exports.notifyOnNewComment = onDocumentCreated(
    "comments/{commentId}",
    async (event) => {
        const comment = event.data?.data();
        if (!comment) return;

        const commenterId = comment.userId;
        const postId = comment.postId;
        if (!postId) return;

        const db = getFirestore();
        const postSnap = await db.collection("posts").doc(postId).get();
        if (!postSnap.exists) return;

        const ownerId = (postSnap.data() || {}).userId;
        if (!ownerId || ownerId === commenterId) return; // don't notify yourself

        const commenterName = (comment.userName || "Someone").toString().slice(0, 40);
        const preview = (comment.content || "").toString().slice(0, 140);

        await sendPushToUser(
            ownerId,
            {
                title: `${commenterName} commented`,
                body: preview || "Tap to view",
            },
            {
                type: "comment",
                postId: postId,
            }
        );
    }
);
