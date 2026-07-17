// supabase/functions/create-payment-intent/index.ts
// Creates a PaymentIntent that automatically splits 85% to the club and keeps 15% as platform fee.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") as string, {
      apiVersion: "2023-10-16",
      httpClient: Stripe.createFetchHttpClient(),
    })

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const { inventory_id, qty } = await req.json()

    if (!inventory_id || !qty || qty < 1) {
      return new Response(JSON.stringify({ error: "inventory_id and qty are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { data: item, error: itemError } = await supabaseAdmin
      .from("inventory")
      .select(`
        id, fixture_name, seats_available, package_details, standby_price, club_id,
        profiles ( club_name, stripe_account_id, stripe_onboarding_complete )
      `)
      .eq("id", inventory_id)
      .single()

    if (itemError || !item) {
      return new Response(JSON.stringify({ error: "Inventory item not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    if (item.seats_available < qty) {
      return new Response(JSON.stringify({ error: "Not enough seats available" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const club = item.profiles as any
    if (!club?.stripe_account_id || !club.stripe_onboarding_complete) {
      return new Response(
        JSON.stringify({ error: "This club has not completed Stripe Connect onboarding yet." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const unitPrice = Number(item.standby_price)
    const total = unitPrice * qty
    const amountInPence = Math.round(total * 100)
    const platformFeeInPence = Math.round(amountInPence * 0.15) // 15%

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInPence,
      currency: "gbp",
      automatic_payment_methods: { enabled: true },
      application_fee_amount: platformFeeInPence,
      transfer_data: {
        destination: club.stripe_account_id,
      },
      metadata: {
        inventory_id: item.id,
        club_id: item.club_id,
        qty: String(qty),
        fixture_name: item.fixture_name,
        club_name: club.club_name || "",
        unit_price: String(unitPrice),
        total: String(total),
        platform_fee: String(platformFeeInPence / 100),
        club_amount: String((amountInPence - platformFeeInPence) / 100),
        package_details: item.package_details?.substring(0, 400) || "",
      },
    })

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        amount: total,
        platformFee: platformFeeInPence / 100,
        clubAmount: (amountInPence - platformFeeInPence) / 100,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
