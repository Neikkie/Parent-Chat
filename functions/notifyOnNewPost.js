/**
 * Sends a push notification to every device subscribed to the "new-posts"
 * topic when a new /posts/{postId} document is created.
 *
 * SETUP (one-time):
 *   1. Apple Developer Console → Keys → create an APNs auth key (.p8).
 *      Copy the Key ID and Team ID.
 *   2. Firebase Console → Project Settings → Cloud Messaging → Apple app
 *      configuration → upload the .p8, fill in Key ID and Team ID.
 *   3. In the iOS app, add the FirebaseMessaging SPM product to the target.
 *   4. cd functions && npm install && firebase deploy --only functions:notifyOnNewPost
 *
 * Once deployed, every device whose user enabled "New Community Posts" in
 * Notification Settings (which calls Messaging.subscribe(toTopic:"new-posts"))
 * will receive a banner when anyone posts.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

try { getApp(); } catch { initializeApp(); }

exports.notifyOnNewPost = onDocumentCreated("posts/{postId}", async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const authorName = (post.userName || "A parent").toString().slice(0, 40);
    const preview = (post.content || "").toString().slice(0, 120);

    const message = {
        topic: "new-posts",
        notification: {
            title: `${authorName} shared an update`,
            body: preview || "Tap to read more",
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    "mutable-content": 1,
                },
            },
        },
        data: {
            postId: event.params.postId,
            authorUid: post.userId || "",
        },
    };

    try {
        await getMessaging().send(message);
    } catch (e) {
        console.error("Failed to send new-post notification", e);
    }
});
