/**
 * Sends a push to the recipient when a new direct message is created at
 * /conversations/{conversationId}/messages/{messageId}.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { sendPushToUser } = require("./pushHelpers");

try { getApp(); } catch { initializeApp(); }

exports.notifyOnNewMessage = onDocumentCreated(
    "conversations/{conversationId}/messages/{messageId}",
    async (event) => {
        const msg = event.data?.data();
        if (!msg) return;

        const senderId = msg.senderId;
        const text = (msg.text || "").toString();

        const db = getFirestore();
        const convId = event.params.conversationId;
        const convSnap = await db.collection("conversations").doc(convId).get();
        if (!convSnap.exists) return;

        const conv = convSnap.data() || {};
        const participants = conv.participantIds || [];
        const recipientId = participants.find((id) => id !== senderId);
        if (!recipientId) return;

        const names = conv.participantNames || {};
        const senderName = (names[senderId] || "New message").toString().slice(0, 40);

        await sendPushToUser(
            recipientId,
            {
                title: senderName,
                body: text.slice(0, 140) || "Sent you a message",
            },
            {
                type: "message",
                conversationId: convId,
                senderId: senderId || "",
            }
        );
    }
);
