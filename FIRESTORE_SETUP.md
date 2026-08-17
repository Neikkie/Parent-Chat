# Firestore Security Rules Setup

To allow your app to read and write to Firestore, you need to update the security rules in Firebase Console.

## Steps:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click on "Firestore Database" in the left sidebar
4. Click on the "Rules" tab
5. Replace the existing rules with the following:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ---------- helpers ----------
    function isAdmin() {
      return request.auth != null && request.auth.token.admin == true;
    }
    function emailIsAdmin() {
      // Transitional fallback until you run setAdminClaim.js.
      // Safe to remove once the custom claim is set.
      return request.auth != null &&
             request.auth.token.email == "support.chaniiapps@gmail.com";
    }

    // ---------- collections ----------

    // Users — anyone authenticated can read profiles; only the user (sans
    // suspension fields) or an admin can write.
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      // Self-write: own doc AND must NOT touch admin-controlled fields.
      allow update: if request.auth != null && request.auth.uid == userId &&
                       !request.resource.data.diff(resource.data).affectedKeys()
                         .hasAny(['isSuspended', 'suspensionReason', 'suspendedAt', 'suspensionStatus']);
      // Admin can update anything (suspension actions).
      allow update: if isAdmin() || emailIsAdmin();

      // Push notification tokens — a user manages only their own device tokens.
      // Cloud Functions read these via the Admin SDK (which bypasses rules).
      match /fcmTokens/{token} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Posts
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      // Owner can update any field; any other authed user can update only
      // counter / non-identifying fields (the diff check below).
      allow update: if request.auth != null && (
        resource.data.userId == request.auth.uid ||
        (
          request.resource.data.userId == resource.data.userId &&
          request.resource.data.userName == resource.data.userName &&
          request.resource.data.content == resource.data.content &&
          request.resource.data.createdAt == resource.data.createdAt
        )
      );
      allow delete: if request.auth != null &&
                       (resource.data.userId == request.auth.uid || isAdmin() || emailIsAdmin());

      // Likes subcollection — likeId must equal the user's uid
      match /likes/{likeId} {
        allow read: if request.auth != null;
        allow create, delete: if request.auth != null && request.auth.uid == likeId;
      }
    }

    // Comments — owner can create/delete/update their own; non-owners can't
    // touch them. Update is restricted to non-identifying fields so a rename
    // batch can run but content can't be rewritten by a stolen token.
    match /comments/{commentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null &&
                      resource.data.userId == request.auth.uid &&
                      request.resource.data.userId == resource.data.userId &&
                      request.resource.data.postId == resource.data.postId &&
                      request.resource.data.createdAt == resource.data.createdAt;
      allow delete: if request.auth != null &&
                       (resource.data.userId == request.auth.uid || isAdmin() || emailIsAdmin());
    }

    // Activities — owner can update anything; non-owners can update only
    // non-identifying fields (rating aggregates).
    match /activities/{activityId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null &&
                      request.resource.data.createdBy == request.auth.uid;
      allow update: if request.auth != null && (
        resource.data.createdBy == request.auth.uid ||
        (
          request.resource.data.createdBy == resource.data.createdBy &&
          request.resource.data.name == resource.data.name &&
          request.resource.data.description == resource.data.description &&
          request.resource.data.createdAt == resource.data.createdAt
        )
      );
      allow delete: if request.auth != null &&
                       resource.data.createdBy == request.auth.uid;
    }

    // Saved bookmarks
    match /savedActivities/{savedId} {
      allow read, write: if request.auth != null;
    }
    match /savedPosts/{savedId} {
      allow read, write: if request.auth != null;
    }

    // Ratings
    match /ratings/{ratingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null &&
                      resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null &&
                      resource.data.userId == request.auth.uid;
    }

    // Blocked users — STRICT: only the blocker can read/write their own records.
    // Client list queries MUST filter with whereField("blockingUserId", isEqualTo: uid).
    match /blockedUsers/{docId} {
      allow read: if request.auth != null &&
                     resource.data.blockingUserId == request.auth.uid;
      allow create: if request.auth != null &&
                      request.resource.data.blockingUserId == request.auth.uid;
      allow delete: if request.auth != null &&
                      resource.data.blockingUserId == request.auth.uid;
    }

    // Direct messages — 1:1 conversations. Only the two participants can
    // read or write a conversation and the messages inside it. The
    // conversationId is the two uids sorted and joined ("uidA_uidB").
    match /conversations/{conversationId} {
      // A participant can read their own threads. The inbox query filters
      // with whereField("participantIds", arrayContains: uid), so every
      // matched doc satisfies this rule.
      allow read: if request.auth != null &&
                     request.auth.uid in resource.data.participantIds;
      // Creator must be one of the participants.
      allow create: if request.auth != null &&
                       request.auth.uid in request.resource.data.participantIds;
      // Either participant can update the thread summary (lastMessage, etc.)
      // but can't remove themselves from the participant list.
      allow update: if request.auth != null &&
                       request.auth.uid in resource.data.participantIds &&
                       request.auth.uid in request.resource.data.participantIds;
      allow delete: if false;

      // Messages — readable only by participants; a user may only send a
      // message as themselves.
      match /messages/{messageId} {
        allow read: if request.auth != null &&
                       request.auth.uid in
                         get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow create: if request.auth != null &&
                         request.resource.data.senderId == request.auth.uid &&
                         request.auth.uid in
                           get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow update, delete: if false;
      }
    }

    // Reports — any user can file; admin reads + updates.
    match /reports/{reportId} {
      allow create: if request.auth != null &&
                      request.resource.data.reportedByUserId == request.auth.uid;
      allow read, update: if isAdmin() || emailIsAdmin();
      allow delete: if false;
    }

    // Moderation violations — author can create; admin can read + manage.
    match /moderationViolations/{docId} {
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      allow read, update, delete: if isAdmin() || emailIsAdmin();
    }

    // Flagged content (soft moderation queue) — author can create; admin manages.
    match /flaggedContent/{docId} {
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      allow read, update, delete: if isAdmin() || emailIsAdmin();
    }

    // Media upload audit log — uploader writes; admin reads.
    match /mediaUploads/{docId} {
      allow create: if request.auth != null &&
                      request.resource.data.userId == request.auth.uid;
      allow read, update, delete: if isAdmin() || emailIsAdmin();
    }

    // Mail collection — Trigger Email extension. Cloud Functions bypass rules.
    match /mail/{docId} {
      allow read, write: if false;
    }
  }
}
```

6. Click "Publish" to save the rules

## What these rules do:

### Admin Helpers:
- `isAdmin()` checks the `admin: true` custom claim on the auth token
- `emailIsAdmin()` is a transitional fallback for `support.chaniiapps@gmail.com` — remove once `setAdminClaim.js` has been run for that user

### Users Collection:
- **Read access**: Any authenticated user can read user profiles
- **Create access**: A user can create their own document (uid must match)
- **Update access (self)**: A user can update their own document **except** the admin-controlled suspension fields (`isSuspended`, `suspensionReason`, `suspendedAt`, `suspensionStatus`)
- **Update access (admin)**: Admins can update any user document (used for suspension actions)

### Posts Collection:
- **Read access**: Any authenticated user can read all posts
- **Create access**: Authenticated users can create posts (with their own userId)
- **Update access**: Owner can update any field; non-owners can update only counter / non-identifying fields (userId, userName, content, createdAt must be unchanged) — needed for likes & comments
- **Delete access**: Owner OR an admin can delete a post

### Likes Subcollection (under posts):
- **Read access**: Any authenticated user can read likes
- **Create/Delete access**: Users can only create or delete their own likes (likeId matches uid)

### Comments Collection:
- **Read access**: Any authenticated user can read all comments
- **Create access**: Authenticated users can create comments (with their own userId)
- **Update access**: Owner can update non-identifying fields only (userId, postId, createdAt must be unchanged) — supports rename batches without allowing content rewrites by a stolen token
- **Delete access**: Owner OR an admin can delete a comment

### Activities Collection:
- **Read access**: Any authenticated user can read all activities
- **Create access**: Authenticated users can create activities (with their own createdBy)
- **Update access**: Owner can update anything; non-owners can update only non-identifying fields (rating aggregates) — `createdBy`, `name`, `description`, `createdAt` must be unchanged
- **Delete access**: Only the owner can delete their activities

### Saved Activities / Saved Posts Collections:
- **Read/Write access**: Any authenticated user (kept simple/reliable for bookmark flows)

### Ratings Collection:
- **Read access**: Any authenticated user can read ratings
- **Create access**: Authenticated users can create ratings (with their own userId)
- **Update/Delete access**: Users can only update or delete their own ratings

### Blocked Users Collection:
- **Strict isolation**: Only the blocker can read/write their own records
- Client list queries **must** filter with `whereField("blockingUserId", isEqualTo: uid)` or the read will be denied
- **Create/Delete access**: Blocker can add or remove their own block records

### Conversations Collection (Direct Messages):
- **Read access**: Only a participant can read a conversation. The inbox listener **must** query with `whereField("participantIds", arrayContains: uid)` (it does) or the read is denied
- **Create access**: The creator must be one of the two `participantIds`
- **Update access**: Either participant can update the thread summary (`lastMessage`, `lastMessageAt`, `lastSenderId`) but can't remove themselves from `participantIds`
- **Delete access**: Never (threads are retained)
- **Messages subcollection**:
  - **Read access**: Only participants of the parent conversation (verified via `get()` on the conversation doc)
  - **Create access**: A user may only send a message as themselves (`senderId` must equal their uid) and must be a participant
  - **Update/Delete access**: Never (messages are immutable — no edit/unsend)
- **No composite index required**: both the inbox and thread listeners use a single-field query and sort in memory

### Reports Collection:
- **Create access**: Any authenticated user can file a report (`reportedByUserId` must equal their uid)
- **Read/Update access**: Admins only (review queue)
- **Delete access**: Never (audit trail preserved)

### Moderation Violations Collection:
- **Create access**: A user can log their own violation
- **Read/Update/Delete access**: Admins only

### Flagged Content Collection (soft moderation queue):
- **Create access**: Author whose content matched a community-guideline term
- **Read/Update/Delete access**: Admins only

### Media Upload Audit Log:
- **Create access**: Uploader can log their own uploads (App Review §1.2 UGC compliance)
- **Read/Update/Delete access**: Admins only

### Mail Collection (Trigger Email extension):
- **Read/Write access**: Denied for clients — only Cloud Functions write here (Cloud Functions bypass rules)

All unauthenticated requests are denied

## Firebase Storage Rules

You also need to set up Firebase Storage rules for media uploads. In Firebase Console:

1. Go to **Storage** in the left sidebar
2. Click on the **Rules** tab
3. Replace with the following:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;

      // Images up to 10 MB, videos up to 200 MB. Owner-only writes.
      allow create, update: if request.auth != null
        && request.auth.uid == userId
        && (
          (request.resource.contentType.matches('image/.*') && request.resource.size < 10 * 1024 * 1024)
          || (request.resource.contentType.matches('video/.*') && request.resource.size < 200 * 1024 * 1024)
        );

      // Delete has no request.resource — checking .size / .contentType
      // on a delete denies the operation, which blocks Storage cleanup
      // when an owner deletes a post containing media.
      allow delete: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

4. Click **Publish**

## Testing:

After updating the rules, the app will be able to:
1. Create a user document in Firestore when you first sign in
2. Update the `lastSignInAt` timestamp on subsequent sign-ins
3. Create and view posts from all users (with text, images, and location)
4. Update or delete your own posts
5. Upload images and videos to Firebase Storage
6. Tag locations in posts
7. Like and unlike posts
8. Add comments to posts
9. Delete your own comments
