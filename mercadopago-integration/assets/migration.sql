-- MercadoPago Checkout Pro - Database Schema
-- Run in Supabase SQL Editor
-- Adjust table/column names as needed for your project

-- Purchases table: one row per checkout session
CREATE TABLE IF NOT EXISTS public.purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_email VARCHAR(255) NOT NULL,
  mercadopago_payment_id TEXT,
  mercadopago_preference_id TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  total_amount NUMERIC(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Purchase items: line items for each purchase
-- Adjust the item_id column name and foreign key to match your product table
CREATE TABLE IF NOT EXISTS public.purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  item_id UUID NOT NULL,  -- FK to your products/items table
  price NUMERIC(10,2) NOT NULL
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_purchases_email ON public.purchases(user_email);
CREATE INDEX IF NOT EXISTS idx_purchases_status ON public.purchases(status);
CREATE INDEX IF NOT EXISTS idx_purchases_mp_payment ON public.purchases(mercadopago_payment_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON public.purchase_items(purchase_id);

-- Optional: RLS policies (adjust to your auth setup)
-- ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view own purchases"
--   ON public.purchases FOR SELECT
--   USING (user_email = auth.jwt() ->> 'email');
