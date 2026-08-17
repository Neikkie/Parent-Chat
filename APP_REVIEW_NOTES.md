# App Review Notes — Parent Chat

Paste the relevant sections into **App Store Connect → your app → the version → App Review Information → Notes**, and fill in the demo account fields below.

---

## Demo account (required — app is behind sign-in)

The app requires an account to use. Please sign in with the email/password demo account below (tap **"Continue with Email" → "Sign In"** on the welcome screen — you do **not** need Sign in with Apple to review the app):

- **Email:** `REVIEW_DEMO_EMAIL_HERE`
- **Password:** `REVIEW_DEMO_PASSWORD_HERE`

> Notes for the reviewer:
> - On first launch after sign-in you'll pass a one-time **age gate (18+)** and a **Community Agreement** — both are required and expected.
> - The demo account is pre-populated so you can see the feed, activities, map, and messaging immediately.
> - If you'd like a second account to test 1:1 messaging, blocking, and reporting between two users:
>   - **Email:** `REVIEW_DEMO_EMAIL_2_HERE`
>   - **Password:** `REVIEW_DEMO_PASSWORD_2_HERE`

---

## What the app is

Parent Chat is an **adults-only (18+)** community for parents: a shared feed of posts (text, photos, and short videos), local kid-friendly activities and a map, and 1:1 direct messages between parents.

---

## User-generated content safety (Guideline 1.2)

We implement all of the required UGC safeguards:

**1. Age assurance**
- A date-of-birth age gate blocks anyone under 18 before they can use the app. We store only a boolean confirmation, not the date of birth.

**2. Agreement to terms (EULA) with zero tolerance**
- Every user must accept a Community Agreement before posting. It requires them to confirm they are 18+, that they have the right/consent to share what they post, and that there is **zero tolerance for objectionable or exploitative content**. Users are re-prompted whenever the agreement is updated.

**3. Content filtering**
- **Text:** posts, comments, and messages are screened against a blocked-terms list; matches are soft-flagged for moderator review.
- **Images & video:** every uploaded image and video is scanned **on-device** with Apple's SensitiveContentAnalysis framework. Nudity / sexually explicit content is a **hard block** — it is removed and never uploaded.
- Every media upload is written to an audit log for moderation.

**4. Reporting objectionable content**
- Any post or comment can be reported via the **••• menu → Report** on that item. Reports are stored server-side for moderator review.

**5. Blocking abusive users**
- The **••• menu → Block** hides all content from that user and prevents further interaction. Blocked users are managed in **Settings → Blocked Users**.

**6. Acting on reports within 24 hours**
- Reports flow into a moderator inbox. Objectionable content is removed and repeat offenders are removed from the platform. The moderation contact is **support.chaniiapps@gmail.com**.

---

## Where to find each control (quick reviewer walkthrough)

| Action | Where |
| --- | --- |
| Age gate | Shown automatically on first sign-in |
| Community Agreement / EULA | Shown automatically on first sign-in |
| Report a post/comment | ••• menu on the item → **Report** |
| Block a user | ••• menu on the item → **Block** |
| Manage blocked users | **Me** tab → **Settings** → **Blocked Users** |
| Message another parent | ••• menu on a post → **Message**, or the paper-plane icon on Home |
| Delete your account | **Me** tab → **Settings** → **Delete Account** (removes all data) |

---

## Account deletion (Guideline 5.1.1(v))
Users can permanently delete their account and all associated data in **Settings → Delete Account**. A reversible **Deactivate** option is also provided.

---

## Privacy
- Sign in with Apple and email/password are supported.
- We do **not** store user email addresses in our database (email lives in Firebase Auth only).
- Location is used only to surface nearby activities and to optionally tag posts; permission is requested in-context.

---

## How to contact us during review
For anything blocking review, email **support.chaniiapps@gmail.com** and we will respond promptly.
