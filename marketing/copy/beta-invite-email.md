# Beta invite email (MailerLite)

> First beta wave, Android via Firebase App Distribution invite link.
> Replace `[INVITE_LINK]` with the link from Firebase Console → App Distribution → Invite links.

---

**Subject:** Your Ironbit beta access is ready — every rep builds your character

**Preheader:** Android beta is live. ~2 minutes to install. Offline-first, no account.

---

Hey {$name|there},

You signed up to beta test **Ironbit** — a workout tracker where every rep you log builds a real
RPG character. Your access is ready.

**What you're testing:** log real workouts (sets, reps, weight) and watch them feed a pixel-arcade
character — STR/AGI/END stats, levels, ranks, classes, quests, and loot. Everything is earned from
actual training. No account, no ads, no purchases — your workouts live on your phone. (The beta
collects anonymous usage + crash reports so I can fix things fast; analytics is opt-out in Settings.)

## Install (Android, ~2 minutes)

1. Open this link on your Android phone: **[INVITE_LINK]**
2. Sign in with Google when Firebase asks (this is just for app delivery — Ironbit itself has no login).
3. Install the small **App Tester** app when prompted, then download **Ironbit** from it.
4. Open Ironbit and create your character. That's it.

> App Tester is Google's official beta-delivery app — it also notifies you when I ship updates.

## What I'd love you to do

- Go through onboarding and log your **real workouts** for a week or two — the app is built around
  genuine training, and that's what I need tested.
- Note anything confusing, broken, or annoying — even small stuff. "This button felt wrong" is
  exactly the feedback I want.
- If it crashes: tell me what you were doing right before. That's gold.

**To send feedback, just reply to this email.** Screenshots welcome.

## Honest fine print

This is a first beta. Known rough edges exist; a future update *may* require a fresh install
(your character would restart — I'll warn you first if so). It's Android-only for now.

**Privacy:** your training data stays on your phone. The beta collects anonymous usage analytics
(opt-out any time in Settings → Data & Privacy) plus opt-in crash reports. Full policy:
https://quandaogit.github.io/ironbit-privacy/

Thanks for training with me from day one. Your character is waiting.

— Erik
Ironbit

---

## Notes (not part of the email)

- `{$name|there}` is MailerLite's personalization syntax — adjust to your field name.
- Voice check: identity hook in subject + closer, trust anchor ("no account / your workouts stay on
  your phone"; anonymous opt-out analytics + crash reports disclosed per ADR 0001), no body-language
  or weight framing, no claims beyond the shipped product. ✓
- The "fresh install" warning covers the S2 finding (fromJson hardening not done yet — a schema
  change between beta builds could require a data wipe).
- Follow-up cadence suggestion: a short check-in email after ~1 week ("what made you stop / keep
  opening it?") — that's the retention signal the beta exists to measure.
