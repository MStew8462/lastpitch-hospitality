# Stripe Connect Integration – LastPitch

This guide takes you from the previous simulated payments to **real Stripe Connect** with automatic 85/15 splits and webhook-protected vouchers.

## Architecture

```
Fan clicks Claim
      │
      ▼
Edge Function: create-payment-intent
  • Looks up inventory + club’s stripe_account_id
  • Creates PaymentIntent with:
      - application_fee_amount = 15%
      - transfer_data.destination = club’s Connect account
      │
      ▼
Frontend mounts Stripe Payment Element
Fan pays with real card
      │
      ▼
Stripe fires payment_intent.succeeded
      │
      ▼
Edge Function: stripe-webhook
  • Verifies signature
  • Calls claim_seats() RPC (decrements inventory)
  • Inserts row into public.claims (the digital voucher)
      │
      ▼
Frontend polls claims table → shows voucher only after webhook success
```

## 1. Stripe Dashboard setup

1. Create / log into a Stripe account (test mode first).
2. **Enable Connect**
   - Dashboard → Connect → Get started → choose **Platform or marketplace**
   - Select **Express** accounts (recommended).
3. Note your keys:
   - **Publishable key** (`pk_test_…`) → goes in `index.html`
   - **Secret key** (`sk_test_…`) → goes into Supabase secrets
4. Create a webhook endpoint (after you deploy the function):
   - Developers → Webhooks → Add endpoint
   - URL: `https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/stripe-webhook`
   - Events: `payment_intent.succeeded`, `account.updated`
   - Copy the **Signing secret** (`whsec_…`)

## 2. Supabase secrets

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxxxxxxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxx
```

## 3. Deploy the Edge Functions

```bash
supabase functions deploy create-connect-account
supabase functions deploy create-account-link
supabase functions deploy create-payment-intent
supabase functions deploy stripe-webhook --no-verify-jwt
```

> Webhook must use `--no-verify-jwt` because Stripe does not send a Supabase JWT.

## 4. Update the database schema

Run the new `supabase-schema.sql` in the SQL Editor. It adds Stripe fields + the `claims` table.

## 5. Frontend config

In `index.html` set:

```js
const SUPABASE_URL = 'https://xxxx.supabase.co'
const SUPABASE_ANON_KEY = 'eyJ…'
const STRIPE_PUBLISHABLE_KEY = 'pk_test_…'
```

## 6. Club onboarding

1. Club logs in → sees **Connect with Stripe** banner
2. Completes Express onboarding on Stripe
3. Webhook marks `stripe_onboarding_complete = true`
4. Only then can fans buy that club’s inventory

## 7. Testing cards

| Card                  | Result             |
|-----------------------|--------------------|
| 4242 4242 4242 4242   | Success            |
| 4000 0000 0000 9995   | Insufficient funds |

After success you should see a new row in `claims` and seats decreased.
