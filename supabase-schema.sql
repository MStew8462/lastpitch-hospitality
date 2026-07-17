-- ============================================================
-- LastPitch Hospitality - Supabase Database Schema (v2 - Stripe Connect)
-- Run this entire script in your Supabase SQL Editor
-- ============================================================

-- 1. Profiles table (extends auth.users for club accounts)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_name TEXT NOT NULL,
  email TEXT,
  stripe_account_id TEXT,                    -- Stripe Connect Express account ID (acct_xxx)
  stripe_onboarding_complete BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Inventory table
CREATE TABLE IF NOT EXISTS public.inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fixture_name TEXT NOT NULL,
  seats_available INTEGER NOT NULL CHECK (seats_available >= 0),
  package_details TEXT NOT NULL,
  standby_price NUMERIC(10,2) NOT NULL CHECK (standby_price > 0),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Claims / Vouchers table (created only after successful Stripe payment via webhook)
CREATE TABLE IF NOT EXISTS public.claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id UUID REFERENCES public.inventory(id) ON DELETE SET NULL,
  club_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  fixture_name TEXT NOT NULL,
  club_name TEXT,
  qty INTEGER NOT NULL,
  unit_price NUMERIC(10,2) NOT NULL,
  total_paid NUMERIC(10,2) NOT NULL,
  platform_fee NUMERIC(10,2) NOT NULL,       -- 15%
  club_amount NUMERIC(10,2) NOT NULL,        -- 85%
  package_details TEXT,
  booking_ref TEXT UNIQUE NOT NULL,
  stripe_payment_intent_id TEXT UNIQUE,
  claimed_at TIMESTAMPTZ DEFAULT NOW(),
  buyer_email TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_inventory_seats ON public.inventory(seats_available) WHERE seats_available > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_created ON public.inventory(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_claims_booking_ref ON public.claims(booking_ref);
CREATE INDEX IF NOT EXISTS idx_claims_pi ON public.claims(stripe_payment_intent_id);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claims ENABLE ROW LEVEL SECURITY;

-- Profiles policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Inventory policies
DROP POLICY IF EXISTS "Anyone can view available inventory" ON public.inventory;
CREATE POLICY "Anyone can view available inventory"
  ON public.inventory FOR SELECT USING (true);

DROP POLICY IF EXISTS "Clubs can insert own inventory" ON public.inventory;
CREATE POLICY "Clubs can insert own inventory"
  ON public.inventory FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = club_id);

DROP POLICY IF EXISTS "Clubs can update own inventory" ON public.inventory;
CREATE POLICY "Clubs can update own inventory"
  ON public.inventory FOR UPDATE TO authenticated
  USING (auth.uid() = club_id);

DROP POLICY IF EXISTS "Clubs can delete own inventory" ON public.inventory;
CREATE POLICY "Clubs can delete own inventory"
  ON public.inventory FOR DELETE TO authenticated
  USING (auth.uid() = club_id);

-- Remove the open public UPDATE policy – seat decrementing is now done only by the webhook
DROP POLICY IF EXISTS "Anyone can update seats for claims" ON public.inventory;

-- Claims policies
DROP POLICY IF EXISTS "Anyone can view claims" ON public.claims;
CREATE POLICY "Anyone can view claims"
  ON public.claims FOR SELECT USING (true);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;
ALTER PUBLICATION supabase_realtime ADD TABLE public.claims;

-- Safe seat claiming function (used by webhook)
CREATE OR REPLACE FUNCTION public.claim_seats(p_inventory_id UUID, p_qty INTEGER)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current INTEGER;
  v_new INTEGER;
BEGIN
  SELECT seats_available INTO v_current
  FROM public.inventory
  WHERE id = p_inventory_id
  FOR UPDATE;

  IF v_current IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Listing not found');
  END IF;

  IF v_current < p_qty THEN
    RETURN json_build_object('success', false, 'error', 'Not enough seats remaining', 'available', v_current);
  END IF;

  v_new := v_current - p_qty;

  UPDATE public.inventory
  SET seats_available = v_new
  WHERE id = p_inventory_id;

  RETURN json_build_object('success', true, 'remaining', v_new);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_seats(UUID, INTEGER) TO service_role;
