-- Migration 014: Normalize all cost_item currencies to USD
--
-- The application displays a single currency (USD).
-- Update all existing rows that were seeded with EUR, GBP, or JPY.

UPDATE public.cost_items
SET currency = 'USD'
WHERE currency != 'USD';
