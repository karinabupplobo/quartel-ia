-- Adds a 'meeting' activity kind (sales meetings in the lead history).
-- Kept in its own migration: a new enum value can't be used in the same
-- transaction that creates it.
alter type public.m_activity_kind add value if not exists 'meeting';
