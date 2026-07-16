# LastPitch – Full Setup Guide

## 1. Create Supabase Project (free)

1. Go to https://supabase.com and sign in / sign up
2. Click **New Project**
3. Choose organization, name it e.g. `lastpitch`, set a strong database password, pick a region close to you
4. Wait ~1–2 minutes for the project to provision

## 2. Run the Database Schema

1. In the left sidebar go to **SQL Editor**
2. Click **New query**
3. Copy the entire contents of `supabase-schema.sql` from this repo
4. Paste into the editor and click **Run**
5. You should see “Success. No rows returned”

This creates:
- `profiles` table (linked to Auth users)
- `inventory` table
- Proper Row Level Security (RLS) policies
- Realtime publication so Fan View updates live
- Optional `claim_seats` RPC for safe seat decrementing

## 3. Configure Authentication

1. Go to **Authentication → Providers**
2. Make sure **Email** is enabled
3. (Recommended for demo) Turn **off** “Confirm email” so new clubs can log in immediately after signup
4. Optional: customize the email templates under Authentication → Email Templates

## 4. Get Your API Keys

1. Go to **Project Settings** (gear icon) → **API**
2. Copy:
   - **Project URL** (looks like `https://abcdefghijklmnop.supabase.co`)
   - **anon public** key (long JWT starting with `eyJ...`)

## 5. Configure the Frontend

Open `index.html` in a code editor and find this section near the top of the main `<script>`:

```js
// ============================================================
// SUPABASE CONFIG – REPLACE THESE TWO VALUES
// ============================================================
const SUPABASE_URL = 'YOUR_SUPABASE_URL'
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'
```

Replace the two placeholders with the real values you just copied.

Save the file.

## 6. Run the App

Simply open `index.html` in Chrome / Safari / Firefox / Edge.

Or serve it:

```bash
# Any static server works
npx serve .
# or
python3 -m http.server 8080
```

Then visit http://localhost:8080

## 7. First Use

### As a Club
1. Click **Club Portal**
2. Switch to the **Sign Up** tab
3. Enter email, password, and Club Name (e.g. “Manchester United Hospitality”)
4. After signup you are automatically logged in
5. Click **Release New Inventory**, fill the form, submit
6. The listing appears instantly on the Fan View for everyone

### As a Fan
1. Stay on (or switch to) **Fan View**
2. See all live packages from every club
3. Click **Claim Now** → choose quantity → complete the simulated Stripe payment
4. Receive your digital voucher
5. Vouchers are saved under **My Vouchers** (local to your browser)

## Multi-Club Testing

Open the app in two different browsers (or one normal + one private window):
- Browser A: sign up as “Old Trafford Hospitality”
- Browser B: sign up as “Emirates Suite”
- Release inventory from each
- Fan View (either browser) will show both clubs’ listings live

## Optional Improvements

- Deploy to GitHub Pages / Vercel / Netlify (static)
- Add real Stripe (Payment Element + server-side PaymentIntent)
- Use the included `claim_seats` RPC after successful payment for race-condition safety
- Add club logos to the profiles table
- Enable Google / Apple login in Supabase Auth

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Invalid API key” | Double-check you pasted the **anon** key, not the service_role key |
| Sign up works but inventory empty | Make sure you ran the full schema SQL (especially RLS policies) |
| Realtime not updating | In Supabase go to Database → Replication and ensure `inventory` is enabled |
| Can’t claim seats | The public UPDATE policy must be present (it is in the schema) |

Need help? Open an issue on the repo.

Enjoy building last-minute hospitality experiences!
