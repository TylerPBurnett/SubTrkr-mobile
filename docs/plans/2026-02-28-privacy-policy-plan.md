# Privacy Policy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a privacy policy page at `subtrkr.app/privacy` for App Store Connect submission and surface the link in the iOS app's Settings screen.

**Architecture:** Add `react-router-dom` to the existing Vite/React landing site, create a `/privacy` route with a matching dark-themed page, and add a `vercel.json` rewrite so direct URL visits don't 404. In the iOS app, add a single `Link` row to `SettingsView`'s About section.

**Tech Stack:** React 18, react-router-dom v6, Tailwind CSS, Vite, Vercel CLI (landing site); SwiftUI (iOS app)

**Design doc:** `docs/plans/2026-02-28-privacy-policy-design.md`

---

## Repo Paths

- Landing site: `/Users/tyler/Development/SubTrkr-app`
- iOS app: `/Users/tyler/Development/SubTrkr-mobile`

---

### Task 1: Install react-router-dom and add vercel.json

**Files:**
- Modify: `/Users/tyler/Development/SubTrkr-app/package.json` (via bun)
- Create: `/Users/tyler/Development/SubTrkr-app/vercel.json`

**Step 1: Install react-router-dom**

```bash
cd /Users/tyler/Development/SubTrkr-app
bun add react-router-dom
```

Expected: `bun.lock` updated, `react-router-dom` appears in `package.json` dependencies.

**Step 2: Create `vercel.json`**

Create `/Users/tyler/Development/SubTrkr-app/vercel.json`:

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

This tells Vercel to serve `index.html` for all paths, letting React Router handle `/privacy` client-side.

**Step 3: Commit**

```bash
cd /Users/tyler/Development/SubTrkr-app
git add package.json bun.lock vercel.json
git commit -m "feat: add react-router-dom and vercel SPA rewrite"
```

---

### Task 2: Add routing to main.tsx and App.tsx

**Files:**
- Modify: `/Users/tyler/Development/SubTrkr-app/src/main.tsx`
- Modify: `/Users/tyler/Development/SubTrkr-app/src/App.tsx`

**Step 1: Wrap app in BrowserRouter**

Update `src/main.tsx`:

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App.tsx';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>
);
```

**Step 2: Add routes to App.tsx**

Update `src/App.tsx`:

```tsx
import { Routes, Route } from 'react-router-dom';
import { Header } from '@/components/landing/Header';
import { Hero } from '@/components/landing/Hero';
import { ProblemStatement } from '@/components/landing/ProblemStatement';
import { Features } from '@/components/landing/Features';
import { HowItWorks } from '@/components/landing/HowItWorks';
import { Screenshots } from '@/components/landing/Screenshots';
import { TechStack } from '@/components/landing/TechStack';
import { DownloadCTA } from '@/components/landing/DownloadCTA';
import { FAQ } from '@/components/landing/FAQ';
import { Footer } from '@/components/landing/Footer';
import { PrivacyPolicy } from '@/pages/PrivacyPolicy';

function LandingPage() {
  return (
    <div id="top" className="min-h-screen bg-surface-primary">
      <Header />
      <main>
        <Hero />
        <ProblemStatement />
        <Features />
        <HowItWorks />
        <Screenshots />
        <TechStack />
        <DownloadCTA />
        <FAQ />
      </main>
      <Footer />
    </div>
  );
}

function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/privacy" element={<PrivacyPolicy />} />
    </Routes>
  );
}

export default App;
```

**Step 3: Verify the dev server still loads**

```bash
cd /Users/tyler/Development/SubTrkr-app
bun run dev
```

Open `http://localhost:5173` — landing page should render identically. Open `http://localhost:5173/privacy` — you'll get a blank/error screen until Task 3 creates the component; that's fine.

**Step 4: Commit**

```bash
git add src/main.tsx src/App.tsx
git commit -m "feat: add react-router with landing and privacy routes"
```

---

### Task 3: Create the PrivacyPolicy page component

**Files:**
- Create: `/Users/tyler/Development/SubTrkr-app/src/pages/PrivacyPolicy.tsx`

**Step 1: Create `src/pages/` directory and component**

Create `/Users/tyler/Development/SubTrkr-app/src/pages/PrivacyPolicy.tsx`:

```tsx
import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { Logo } from '@/components/Logo';
import { Footer } from '@/components/landing/Footer';

export function PrivacyPolicy() {
  return (
    <div className="min-h-screen bg-surface-primary flex flex-col">
      {/* Top bar */}
      <header className="border-b border-white/10 bg-surface-secondary">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="flex items-center justify-center" style={{ width: '32px', height: '32px' }}>
              <Logo className="w-full h-full" />
            </div>
            <span className="font-archivo text-lg text-white select-none" style={{ fontWeight: 800, letterSpacing: '-0.03em' }}>
              Sub<span className="text-brand-green">Trkr</span>
            </span>
          </Link>
          <Link
            to="/"
            className="flex items-center gap-1.5 text-sm text-zinc-400 hover:text-brand-green transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to home
          </Link>
        </div>
      </header>

      {/* Content */}
      <main className="flex-1">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <h1 className="font-archivo text-4xl font-extrabold text-white mb-2" style={{ letterSpacing: '-0.03em' }}>
            Privacy Policy
          </h1>
          <p className="text-sm text-zinc-500 mb-12">Last updated: February 28, 2026</p>

          <div className="space-y-10 text-zinc-300 leading-relaxed">

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Introduction</h2>
              <p>
                SubTrkr is a subscription and bill tracking app. This privacy policy explains what personal
                information we collect, how we use it, and your rights regarding that information.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Data We Collect</h2>
              <p className="mb-3">We collect only what is necessary to provide the app:</p>
              <ul className="space-y-2 list-none">
                <li className="flex gap-3">
                  <span className="text-brand-green mt-1 shrink-0">—</span>
                  <span>
                    <strong className="text-white">Account data:</strong> Your email address, collected when
                    you create an account.
                  </span>
                </li>
                <li className="flex gap-3">
                  <span className="text-brand-green mt-1 shrink-0">—</span>
                  <span>
                    <strong className="text-white">App data:</strong> Subscription and bill entries you
                    create — names, amounts, billing cycles, dates, categories, statuses, and payment records.
                    This data is entered by you and belongs to you.
                  </span>
                </li>
              </ul>
              <p className="mt-3">
                We do not collect analytics, crash reports, advertising identifiers, location data, or any
                other data beyond what is listed above.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">How We Use Your Data</h2>
              <p>
                Your data is used solely to provide SubTrkr's core functionality: tracking your subscriptions
                and bills, sending local payment reminders, and showing you spending analytics within the app.
              </p>
              <p className="mt-3">
                We do not sell your data, share it with advertisers, or use it for any purpose beyond
                operating the app.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Third-Party Services</h2>
              <p className="mb-3">
                SubTrkr uses <strong className="text-white">Supabase</strong> as its backend infrastructure
                provider. Your account data and app data are stored in Supabase-managed databases. Supabase
                acts as a data processor on our behalf and does not use your data for its own purposes.
              </p>
              <p>
                See the{' '}
                <a
                  href="https://supabase.com/privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-brand-green hover:underline"
                >
                  Supabase Privacy Policy
                </a>{' '}
                for details on how they handle data.
              </p>
              <p className="mt-3">No other third-party services have access to your data.</p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Data Retention</h2>
              <p>
                Your data is retained for as long as your account is active. When you delete your account
                (via Settings → Delete Account in the app), all associated data is permanently and
                irreversibly deleted from our systems.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Your Rights</h2>
              <p className="mb-3">You have control over your data at any time:</p>
              <ul className="space-y-2 list-none">
                <li className="flex gap-3">
                  <span className="text-brand-green mt-1 shrink-0">—</span>
                  <span>Edit or delete individual entries directly within the app.</span>
                </li>
                <li className="flex gap-3">
                  <span className="text-brand-green mt-1 shrink-0">—</span>
                  <span>Delete your entire account and all data via Settings → Delete Account.</span>
                </li>
                <li className="flex gap-3">
                  <span className="text-brand-green mt-1 shrink-0">—</span>
                  <span>
                    Request a data export or correction by contacting us at the address below.
                  </span>
                </li>
              </ul>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Children's Privacy</h2>
              <p>
                SubTrkr is not directed at children under the age of 13. We do not knowingly collect
                personal information from children under 13. If you believe a child has provided us with
                personal information, please contact us and we will delete it promptly.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Changes to This Policy</h2>
              <p>
                We may update this privacy policy from time to time. The "Last updated" date at the top of
                this page reflects the most recent revision. Continued use of the app after changes are
                posted constitutes your acceptance of the updated policy.
              </p>
            </section>

            <section>
              <h2 className="font-archivo text-xl font-bold text-brand-green mb-3">Contact</h2>
              <p>
                For privacy-related questions or data requests, contact us at{' '}
                <a
                  href="mailto:privacy@subtrkr.app"
                  className="text-brand-green hover:underline"
                >
                  privacy@subtrkr.app
                </a>
                {' '}or open an issue on our{' '}
                <a
                  href="https://github.com/TylerPBurnett/SubTrkr/issues"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-brand-green hover:underline"
                >
                  GitHub repository
                </a>.
              </p>
            </section>

          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
```

**Step 2: Verify in dev server**

```bash
cd /Users/tyler/Development/SubTrkr-app
bun run dev
```

Open `http://localhost:5173/privacy` — page should render with dark theme, logo, back link, all sections, and footer. Check that `http://localhost:5173/` still works correctly.

**Step 3: Commit**

```bash
git add src/pages/PrivacyPolicy.tsx
git commit -m "feat: add PrivacyPolicy page component"
```

---

### Task 4: Update siteConfig and Footer

**Files:**
- Modify: `/Users/tyler/Development/SubTrkr-app/src/config/site.ts`
- Modify: `/Users/tyler/Development/SubTrkr-app/src/components/landing/Footer.tsx`

**Step 1: Add privacyPolicy URL to siteConfig**

Update `src/config/site.ts`:

```ts
export const siteConfig = {
  appName: 'SubTrkr',
  githubRepo: 'https://github.com/TylerPBurnett/SubTrkr',
  githubReleases: 'https://github.com/TylerPBurnett/SubTrkr/releases/latest',
  githubReleaseNotes: 'https://github.com/TylerPBurnett/SubTrkr/releases',
  githubIssues: 'https://github.com/TylerPBurnett/SubTrkr/issues',
  documentation: 'https://github.com/TylerPBurnett/SubTrkr#readme',
  privacyPolicy: '/privacy',
} as const;
```

**Step 2: Add Privacy Policy to Footer's Trust column**

In `src/components/landing/Footer.tsx`, update the `trust` array in `footerLinks`:

```tsx
trust: [
  { label: 'Pricing', href: '#faq-pricing' },
  { label: 'Data Security', href: '#faq-security' },
  { label: 'Cloud Sync Model', href: '#faq-account' },
  { label: 'Privacy Policy', href: siteConfig.privacyPolicy },
],
```

**Step 3: Verify**

Visit `http://localhost:5173` and scroll to footer. The Trust column should show "Privacy Policy" as the last item. Click it — should navigate to `/privacy`.

**Step 4: Commit**

```bash
git add src/config/site.ts src/components/landing/Footer.tsx
git commit -m "feat: add privacy policy link to footer and siteConfig"
```

---

### Task 5: Build and deploy to Vercel

**Step 1: Run a production build to catch any type errors**

```bash
cd /Users/tyler/Development/SubTrkr-app
bun run build
```

Expected: `dist/` folder created with no TypeScript errors.

**Step 2: Deploy to production**

```bash
vercel --prod
```

If not logged in: `vercel login` first.

**Step 3: Verify live URL**

Open `https://subtrkr.app/privacy` in a browser. Check:
- Page loads (no 404)
- Direct URL visit works (tests the `vercel.json` rewrite)
- Logo links back to `subtrkr.app`
- Footer renders
- All sections visible

**Step 4: No commit needed** — Vercel deploys from the working directory or git. If Vercel is connected to the git repo, push instead:

```bash
git push origin main
```

---

### Task 6: Add Privacy Policy link in iOS SettingsView

**Files:**
- Modify: `/Users/tyler/Development/SubTrkr-mobile/SubTrkr/SubTrkr/Views/Settings/SettingsView.swift`

**Step 1: Add Privacy Policy row to the About section**

In `SettingsView.swift`, find the About section (around line 95–116). Add the Privacy Policy `Link` after the Platform row:

```swift
// About
Section {
    HStack {
        Label("Version", systemImage: "info.circle")
            .foregroundStyle(.textPrimary)
        Spacer()
        Text("1.0.0")
            .font(.subheadline)
            .foregroundStyle(.textMuted)
    }

    HStack {
        Label("Platform", systemImage: "iphone")
            .foregroundStyle(.textPrimary)
        Spacer()
        Text("iOS")
            .font(.subheadline)
            .foregroundStyle(.textMuted)
    }

    Link(destination: URL(string: "https://subtrkr.app/privacy")!) {
        Label("Privacy Policy", systemImage: "hand.raised.fill")
            .foregroundStyle(.textPrimary)
    }
} header: {
    Text("About")
}
```

**Step 2: Build and verify in Xcode**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build
```

Expected: build succeeds. Then install and launch:

```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

Navigate to Settings — the About section should show Version, Platform, and Privacy Policy rows. Tap Privacy Policy — Safari opens `subtrkr.app/privacy`.

**Step 3: Commit**

```bash
cd /Users/tyler/Development/SubTrkr-mobile
git add SubTrkr/SubTrkr/Views/Settings/SettingsView.swift
git commit -m "feat: add Privacy Policy link in Settings About section"
```

---

### Task 7: App Store Connect — enter the URL and fill Nutrition Labels

This task is manual in App Store Connect (no code).

**Step 1: Enter privacy policy URL**

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Select SubTrkr → App Information
3. Find **Privacy Policy URL** field
4. Enter: `https://subtrkr.app/privacy`
5. Save

**Step 2: Fill Privacy Nutrition Labels**

1. In App Store Connect → SubTrkr → App Privacy
2. Click "Get Started" (or edit existing)
3. Declare the following:

| Data type | Category | Linked to user | Used for tracking |
|-----------|----------|----------------|-------------------|
| Email Address | Contact Info | Yes | No |
| User Content (subscription/bill entries) | User Content | Yes | No |

4. For all other data types — select "We do not collect this data"
5. Save and confirm

**Step 3: Verify checklist**

- [ ] `subtrkr.app/privacy` loads (no 404, direct URL works)
- [ ] Privacy Policy link visible in landing site footer
- [ ] Privacy Policy row appears in iOS Settings → About
- [ ] URL entered in App Store Connect → App Information
- [ ] Privacy Nutrition Labels completed in App Store Connect

---

## Summary of Files Changed

**SubTrkr-app:**
- `package.json` + `bun.lock` — react-router-dom added
- `vercel.json` — new, SPA rewrite
- `src/main.tsx` — BrowserRouter wrapper
- `src/App.tsx` — Routes for `/` and `/privacy`
- `src/pages/PrivacyPolicy.tsx` — new page component
- `src/config/site.ts` — privacyPolicy URL added
- `src/components/landing/Footer.tsx` — Privacy Policy link in Trust column

**SubTrkr-mobile:**
- `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift` — Privacy Policy Link row
