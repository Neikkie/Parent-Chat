# Parent Chat — Improvement Suggestions & Roadmap

A living list of ideas to make the app better. Grouped by category and rough effort.

## High-impact Apple features (native, on-brand)

| Feature | Why it fits | Effort |
| --- | --- | --- |
| **Push notifications (APNs)** | Real push for new DMs and post replies — biggest retention lever now that messaging exists. `NotificationManager` already scaffolds local notifications. | Medium‑High |
| **Home / Lock Screen Widgets (WidgetKit)** | "Nearby activities today" or "unread messages" glanceable widget. | Medium |
| **App Intents + Siri / Spotlight** | "Post to ParentChat" via Siri; index activities into Spotlight search. | Medium |
| **Live Activities (ActivityKit)** | "Activity starting soon" countdown on Lock Screen & Dynamic Island. | Medium |
| **Translation framework** | Auto-translate posts/messages for multilingual parent communities. | Low‑Medium |
| **TipKit** | Contextual onboarding tips (e.g. "Tap ••• to message a parent"). | Low |

## UI / UX polish (Liquid Glass, iOS 26)

- Apply `.buttonStyle(.glass)` / `.glassEffect` to the compose FAB and the map/activity floating controls for consistency with the new header icons.
- Adopt system `.searchable` + `.searchToolbarBehavior(.minimize)` instead of the custom search header to get the new glass search field for free.
- Add `.scrollEdgeEffectStyle` so feed content fades under the header like first-party apps.
- Extend loading skeletons to the DM inbox and chat thread.

## Product / engagement

- **Feed filters**: "Following / Nearby / All" segmented control atop Home.
- **Post reactions** beyond like (❤️ 😂 🎉).
- **Rich DMs**: image/video in messages (reuse the existing upload + moderation pipeline).
- **Read receipts / typing indicators** in DMs.
- **Collections**: let parents organize saved posts/activities into named lists.
- **Group chats / neighborhood channels** as an extension of 1:1 DMs.

## Trust & safety (protects App Review standing)

- Real-time badges + push for the admin moderation queue (`AdminReportsView`).
- Rate-limiting on posts/messages to curb spam.
- Keep the nudity/sensitive-content hard block, reporting, blocking, and EULA — these are the Apple UGC (Guideline 1.2) requirements.

## Media handling

- Faster video uploads: transcode/compress to ~720p before upload and upload from a file URL (streamed) instead of loading the whole file into memory.
- Per-item "most visible" autoplay is implemented; consider a lightweight buffering indicator for slow networks.
