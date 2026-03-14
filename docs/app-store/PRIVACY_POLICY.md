# Privacy Policy — App Store Submission Reference

> Last updated: 2026-03-01

---

## Live URL

```
https://subtrkr.app/privacy
```

This is the URL to enter in App Store Connect. It is live and publicly accessible.

---

## What Was Built

### Landing site (`subtrkr.app`)

- `/privacy` route added via `react-router-dom` in the Vite/React app at `/Users/tyler/Development/SubTrkr-app`
- `vercel.json` SPA rewrite ensures direct URL visits don't 404
- Privacy Policy link added to the footer's **Trust** column (client-side nav via React Router `Link`)
- Deployed to Vercel — production alias: `https://www.subtrkr.app`

### iOS app

- **Settings → About** section has a Privacy Policy row that opens `subtrkr.app/privacy` in Safari
- Row uses `Link(destination: URL(string: "https://subtrkr.app/privacy")!)` with `Label("Privacy Policy", systemImage: "hand.raised.fill")`
- File: `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift`

---

## Policy Content Summary

The policy at `subtrkr.app/privacy` covers:

| Section | Summary |
|---------|---------|
| Data We Collect | Email address (auth) + user-entered subscription/bill/payment data |
| How We Use It | Core app functionality only — no ads, no selling, no third-party sharing |
| Third-Party Services | Supabase (data processor) — links to their privacy policy |
| Data Retention | Retained until account deletion; deletion is permanent |
| Your Rights | Edit/delete in-app; account deletion via Settings; contact for export requests |
| Children's Privacy | Not directed at children under 13 |
| Changes | "Last updated" date reflects most recent revision |
| Contact | privacy@subtrkr.app + GitHub Issues |

**Last updated date on the live policy:** February 28, 2026

---

## App Store Connect — Steps Still Required

These are manual steps in App Store Connect. Do these before submitting for review.

### 1. Enter Privacy Policy URL

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → SubTrkr → **App Information**
3. Scroll to **Privacy Policy URL**
4. Enter: `https://subtrkr.app/privacy`
5. Save

### 2. Fill Privacy Nutrition Labels

1. My Apps → SubTrkr → **App Privacy**
2. Click **Get Started** (or Edit if already started)
3. Declare the following data types:

| Data Type | Category | Purpose | Linked to User | Used for Tracking |
|-----------|----------|---------|----------------|-------------------|
| Email Address | Contact Info | App Functionality | Yes | No |
| User Content | App Content | App Functionality | Yes | No |

> **User Content** = the subscription/bill names, amounts, dates, categories, and payment records the user enters.

4. For **all other data types** (Location, Health, Financial, Browsing History, etc.) — select **"We do not collect this data"**
5. Save and publish

---

## Contact Email

**privacy@subtrkr.app** is listed in the policy as the privacy contact.

You need to make sure this email address actually receives mail before submitting. Options:
- Set up email forwarding in your domain registrar / Vercel DNS to forward `privacy@subtrkr.app` to your personal email
- Or swap it in the policy for your direct email if you haven't set up forwarding yet

---

## App Store Readiness Checklist (as of 2026-03-01)

- [x] Dark mode support
- [x] Account deletion option (Settings → Delete Account)
- [x] Password change option (Settings → Change Password)
- [x] App icon (light / dark / tinted variants)
- [x] Remove hardcoded credentials
- [x] Accessibility audit (VoiceOver, Dynamic Type) ✓
- [x] Privacy policy page live at `subtrkr.app/privacy`
- [x] Privacy Policy link in iOS Settings → About
- [ ] **Privacy Policy URL entered in App Store Connect**
- [ ] **Privacy Nutrition Labels completed in App Store Connect**
- [ ] Test on physical device

---

## Related Files

- Design doc: `docs/completed-plans/2026-02-28-privacy-policy-design.md`
- Implementation plan: `docs/completed-plans/2026-02-28-privacy-policy-plan.md`
- Landing site repo: `/Users/tyler/Development/SubTrkr-app`
