// supabase/functions/stripe-webhook/index.ts
// Listens for payment_intent.succeeded and only then creates the voucher.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") as string, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
})

const cryptoProvider = Stripe.createSubtleCryptoProvider()

serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature")
  const body = await req.text()

  let event: Stripe.Event

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature!,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
      undefined,
      cryptoProvider
    )
  } catch (err) {
    console.error(`Webhook signature verification failed: ${err.message}`)
    return new Response(err.message, { status: 400 })
  }

  if (event.type === "payment_intent.succeeded") {
    const pi = event.data.object as Stripe.PaymentIntent
    const meta = pi.metadata || {}

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // Idempotency check
    const { data: existing } = await supabaseAdmin
      .from("claims")
      .select("id")
      .eq("stripe_payment_intent_id", pi.id)
      .maybeSingle()

    if (existing) {
      return new Response(JSON.stringify({ received: true }), { status: 200 })
    }

    const inventoryId = meta.inventory_id
    const qty = parseInt(meta.qty || "1", 10)
    const total = parseFloat(meta.total || "0")
    const platformFee = parseFloat(meta.platform_fee || "0")
    const clubAmount = parseFloat(meta.club_amount || "0")

    // Decrement seats
    await supabaseAdmin.rpc("claim_seats", {
      p_inventory_id: inventoryId,
      p_qty: qty,
    })

    // Generate booking ref
    const bookingRef =
      "LPH-" +
      Math.random().toString(36).substring(2, 6).toUpperCase() +
      Date.now().toString(36).toUpperCase().slice(-4)

    // Insert voucher
    await supabaseAdmin.from("claims").insert({
      inventory_id: inventoryId,
      club_id: meta.club_id,
      fixture_name: meta.fixture_name,
      club_name: meta.club_name,
      qty,
      unit_price: parseFloat(meta.unit_price || "0"),
      total_paid: total,
      platform_fee: platformFee,
      club_amount: clubAmount,
      package_details: meta.package_details,
      booking_ref: bookingRef,
      stripe_payment_intent_id: pi.id,
      buyer_email: pi.receipt_email || null,
    })

    console.log("Voucher created:", bookingRef)
  }

  // Mark onboarding complete
  if (event.type === "account.updated") {
    const account = event.data.object as Stripe.Account
    if (account.charges_enabled && account.payouts_enabled) {
      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      )
      await supabaseAdmin
        .from("profiles")
        .update({ stripe_onboarding_complete: true })
        .eq("stripe_account_id", account.id)
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
})
