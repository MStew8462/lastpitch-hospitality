-- ============================================================
-- LastPitch Hospitality - Supabase Database Schema
-- Run this entire script in your Supabase SQL Editor (Dashboard > SQL Editor > New query)
-- ============================================================

-- 1. Profiles table (extends auth.users for club accounts)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_name TEXT NOT NULL,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Inventory table (last-minute hospitality packages)
CREATE TABLE IF NOT EXISTS public.inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fixture_name TEXT NOT NULL,
  seats_available INTEGER NOT NULL CHECK (seats_available >= 0),
  package_details TEXT NOT NULL,
  standby_price NUMERIC(10,2) NOT NULL CHECK (standby_price > 0),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast fan view queries
CREATE INDEX IF NOT EXISTS idx_inventory_seats ON public.inventory(seats_available) WHERE seats_available > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_created ON public.inventory(created_at DESC);

-- 3. Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

-- 4. Profiles policies
-- Anyone authenticated can read any profile (to show club names on tickets)
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- 5. Inventory policies (core security)
-- Public (including unauthenticated fans) can read available inventory
CREATE POLICY "Anyone can view available inventory"
  ON public.inventory FOR SELECT
  USING (true);  -- We filter seats > 0 in the app query; or change to (seats_available > 0)

-- Authenticated clubs can insert their own inventory
CREATE POLICY "Clubs can insert own inventory"
  ON public.inventory FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = club_id);

-- Clubs can update only their own inventory (e.g. reduce seats after claim, or edit)
CREATE POLICY "Clubs can update own inventory"
  ON public.inventory FOR UPDATE
  TO authenticated
  USING (auth.uid() = club_id);

-- Clubs can delete their own inventory
CREATE POLICY "Clubs can delete own inventory"
  ON public.inventory FOR DELETE
  TO authenticated
  USING (auth.uid() = club_id);

-- 6. Optional: Allow public (fans) to decrement seats on claim
-- (This is convenient for demo. For production, use a SECURITY DEFINER function + Stripe webhook)
CREATE POLICY "Anyone can update seats for claims"
  ON public.inventory FOR UPDATE
  USING (true)
  WITH CHECK (true);  -- Note: In production tighten this or use RPC

-- 7. Enable Realtime for live updates on Fan View
ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;

-- 8. Optional helper function for safe seat claiming (recommended for production)
CREATE OR REPLACE FUNCTION public.claim_seats(p_inventory_id UUID, p_qty INTEGER)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current INTEGER;
  v_new INTEGER;
BEGIN
  -- Lock the row
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

-- Grant execute to anon + authenticated so fans can claim
GRANT EXECUTE ON FUNCTION public.claim_seats(UUID, INTEGER) TO anon, authenticated;

-- ============================================================
-- After running this:
-- 1. Go to Authentication > Providers and enable Email (confirm email optional for demo)
-- 2. Go to Settings > API and copy Project URL + anon public key
-- 3. Paste them into the index.html config section
-- ============================================================
