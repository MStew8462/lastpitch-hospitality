# LastPitch Hospitality

**Premium last-minute sports hospitality inventory platform.**

Two-sided web app:
- **Club Portal** — Secure multi-club authentication. Clubs log in / sign up, release inventory, and manage their own listings.
- **Fan View** — Public, mobile-optimized feed of live standby packages. Instant updates via Supabase Realtime. Stripe-style checkout + digital voucher.

Built with a clean, modern, premium design (Tailwind + gold accents). Fully client-side SPA powered by Supabase (Auth + Postgres + Realtime).

## Live Demo Setup (5 minutes)

1. Create a free Supabase project at [supabase.com](https://supabase.com)
2. In the Supabase SQL Editor, paste and run the entire contents of `supabase-schema.sql`
3. Enable Email auth: Authentication → Providers → Email (you can disable "Confirm email" for easier testing)
4. Copy your **Project URL** and **anon public key** from Settings → API
5. Open `index.html` and replace the two placeholder values at the top of the `<script>`:
   ```js
   const SUPABASE_URL = 'https://xxxxxxxx.supabase.co'
   const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
   ```
6. Open `index.html` in any modern browser (or host on GitHub Pages / Vercel / Netlify)

That's it. Different clubs can now create accounts, release inventory, and fans instantly see it.

## Features

- Multi-club secure auth (email + password) with profiles
- Row Level Security so clubs only manage their own inventory
- Live inventory sync via Supabase Realtime
- Premium digital ticket cards
- Quantity-aware claiming + simulated Stripe payment modal (native, no redirect)
- Instant digital vouchers with booking reference
- Responsive / mobile-first Fan View
- Clean Club dashboard with stats + inventory table

## Project Structure

```
.
├── index.html              # Full SPA (frontend + all logic)
├── supabase-schema.sql     # Database tables + RLS + Realtime + claim function
├── README.md
└── SETUP.md                # Detailed step-by-step
```

## Tech

- Vanilla JS + Tailwind CDN (no build step)
- Supabase JS client (CDN)
- Supabase Auth + Postgres + Realtime
- LocalStorage only for personal vouchers (claims)

## Production Notes

- The public UPDATE policy on inventory is convenient for the demo claim flow. In production, remove it and call the `claim_seats` RPC (already included) after a real Stripe PaymentIntent succeeds on your backend.
- Add Stripe server-side confirmation + webhook for real payments.
- Deploy the static `index.html` anywhere (GitHub Pages, Cloudflare Pages, Vercel, Netlify, etc.).

---

Built for clean last-minute hospitality experiences.
