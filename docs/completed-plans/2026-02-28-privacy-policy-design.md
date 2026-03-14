# Privacy Policy — Design Doc

> Date: 2026-02-28
> Status: Approved

---

## Goal

Add a publicly accessible privacy policy at `subtrkr.app/privacy` for App Store Connect submission, and surface the link in the iOS app's Settings screen.

---

## Scope

Two repos are touched:

| Repo | Change |
|------|--------|
| `SubTrkr-app` (landing site) | Add `/privacy` route + page + footer link |
| `SubTrkr-mobile` (iOS app) | Add Privacy Policy row in Settings → About |

---

## SubTrkr-app Changes

### 1. Dependencies

Install `react-router-dom` — the site currently has no routing. One new dependency for two routes.

### 2. `vercel.json`

Add SPA rewrite so direct visits to `subtrkr.app/privacy` don't 404:

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

### 3. Routing

Wrap `main.tsx` in `BrowserRouter`. Update `App.tsx` to use `Routes`:

- `/` → existing landing page layout (all current sections)
- `/privacy` → `PrivacyPolicy` page component

### 4. `src/pages/PrivacyPolicy.tsx`

Styled to match the landing site:
- Dark background (`bg-surface-primary`, `#0a0a0b`)
- Archivo font, brand green (`#22c55e`) for section headings
- Same `max-w-4xl mx-auto px-4` container as other sections
- Top bar: SubTrkr logo + "← Back to home" link
- Footer reused from landing page

### 5. Privacy Policy Content

Sections:

**Last Updated:** 2026-02-28

1. **Introduction** — SubTrkr is a subscription and bill tracker. This policy explains what data is collected and how it is used.

2. **Data We Collect**
   - *Account data:* Email address, collected when you create an account via Supabase Auth
   - *App data:* Subscription and bill entries you create (name, amount, billing cycle, dates, category, status, payment records). This data is entered by you and is yours.
   - *No analytics, no crash reporting, no advertising identifiers.*

3. **How We Use Your Data**
   - Solely to provide the app's core functionality: tracking, reminders, and analytics within the app.
   - We do not sell, share, or use your data for advertising.

4. **Third-Party Services**
   - **Supabase** — our backend infrastructure provider. Your data is stored in Supabase-managed PostgreSQL databases. Supabase is a data processor acting on our behalf. See [Supabase Privacy Policy](https://supabase.com/privacy).
   - No other third-party services have access to your data.

5. **Data Retention**
   - Your data is retained for as long as your account is active. When you delete your account, all associated data is permanently deleted from our systems.

6. **Your Rights**
   - You may access, correct, or delete your data at any time via the app's Settings screen.
   - To delete your account and all data: Settings → Delete Account.
   - To request a data export or correction outside the app, contact us at the address below.

7. **Children's Privacy**
   - SubTrkr is not directed at children under the age of 13. We do not knowingly collect personal information from children under 13.

8. **Changes to This Policy**
   - We may update this policy from time to time. The "Last Updated" date at the top reflects the most recent revision. Continued use of the app after changes constitutes acceptance.

9. **Contact**
   - For privacy-related questions: `privacy@subtrkr.app` (or GitHub Issues as fallback)

### 6. `siteConfig` Update

Add `privacyPolicy: 'https://subtrkr.app/privacy'` to `src/config/site.ts`.

### 7. Footer Update

Add "Privacy Policy" link to the existing **Trust** column in `Footer.tsx`. Uses internal `href="/privacy"` (not external — same site).

---

## SubTrkr-mobile Changes

### `SettingsView.swift` — About Section

Add a Privacy Policy row between Version/Platform info and the existing About section footer. Tapping opens `subtrkr.app/privacy` in Safari via `Link`:

```swift
Link(destination: URL(string: "https://subtrkr.app/privacy")!) {
    Label("Privacy Policy", systemImage: "hand.raised.fill")
        .foregroundStyle(.textPrimary)
}
```

---

## App Store Connect — Privacy Nutrition Labels

Separate from the policy URL — must be filled out in App Store Connect under "App Privacy":

| Data Type | Purpose | Required |
|-----------|---------|---------|
| Email Address | Account | Yes |
| User Content (subscription/bill data) | App Functionality | Yes |

Select: "Data linked to you" for both. No tracking, no analytics, no crash data to declare.

---

## Deployment

1. Build the landing site: `bun run build` (or `npm run build`) in `SubTrkr-app`
2. Deploy via Vercel CLI: `vercel --prod` from `SubTrkr-app`
3. Verify `subtrkr.app/privacy` resolves and the page renders
4. Paste URL into App Store Connect → App Information → Privacy Policy URL
5. Build and verify iOS app in Xcode

---

## Success Criteria

- [ ] `subtrkr.app/privacy` loads correctly (direct visit, no 404)
- [ ] Privacy policy link appears in landing site footer
- [ ] Privacy Policy row appears in iOS Settings → About
- [ ] URL is entered in App Store Connect
- [ ] App Store Privacy Nutrition Labels filled out
