# Push Notifications Setup (FCM + APNs)

The app and Cloud Functions are fully wired for remote push (new DMs and new
comments). The client FCM code is guarded with `#if canImport(FirebaseMessaging)`,
so it stays dormant until you complete step 1 below — then it activates
automatically. Do these one-time steps to turn real push on.

## 1. Link FirebaseMessaging into the app target (Xcode)
1. Xcode → project → **Parent Chat** target → **General** → *Frameworks, Libraries, and Embedded Content* → **+**.
2. Choose **FirebaseMessaging** from the already-added Firebase package → Add.
   - (The Firebase SPM package is already a dependency; you're just adding this product.)
3. Build. The `#if canImport(FirebaseMessaging)` blocks in `Parent_ChatApp.swift`
   and `NotificationManager.swift` now compile and run.

## 2. Add the Push Notifications capability
- Target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
  - This confirms the App ID has Push enabled and matches the `aps-environment`
    entitlement already added to `Parent Chat.entitlements`.
- (Optional) Add **Background Modes → Remote notifications** only if you later
  send silent/`content-available` pushes. Not needed for the alert pushes here.

## 3. Create an APNs key and give it to Firebase
1. [Apple Developer](https://developer.apple.com/account) → **Certificates, IDs & Profiles → Keys** → **+** → enable **Apple Push Notifications service (APNs)** → download the `.p8`. Note the **Key ID** and your **Team ID**.
2. Firebase Console → **Project Settings → Cloud Messaging → Apple app configuration** → upload the `.p8`, enter Key ID + Team ID.

## 4. Deploy the Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions:notifyOnNewMessage,functions:notifyOnNewComment
```
(Existing functions — `notifyOnNewPost`, `notifyAdminOnReport`, `rateLimitReports` — deploy the same way; run a plain `firebase deploy --only functions` to deploy all.)

## 5. Publish the Firestore rule for tokens
`FIRESTORE_SETUP.md` now includes a rule for `users/{uid}/fcmTokens/{token}`
(a user manages only their own device tokens). Publish the updated rules in
Firebase Console → Firestore → Rules.

---

## How it works end-to-end
1. On sign-in / when the user allows notifications, the app fetches its **FCM token**
   and saves it to `users/{uid}/fcmTokens/{token}` (`NotificationManager.handleFCMToken`).
2. When someone sends a **DM**, `notifyOnNewMessage` looks up the conversation's
   other participant and pushes to all their tokens.
3. When someone **comments** on a post, `notifyOnNewComment` pushes to the post's author.
4. Invalid/expired tokens are pruned automatically by `pushHelpers.sendPushToUser`.
5. On **sign-out**, the device's token is removed so it stops receiving pushes.

## What already works without any of the above
- The **foreground presentation delegate** (notifications show while the app is open).
- The **"Notifications are on" confirmation** local notification when a user grants permission.

## Testing
- Run on a **real device** (the iOS Simulator can receive some pushes on recent
  macOS, but a physical device is the reliable test).
- Sign in on two devices/accounts, send a DM from one → the other should get a banner
  even with the app backgrounded/closed.
