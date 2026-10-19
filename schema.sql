-- ShopBill schema for Supabase
-- Run this entire script in Supabase Dashboard -> SQL Editor.
-- This uses Row Level Security so signed-in users can access only their own invoices.

create extension if not exists pgcrypto;

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  invoice_no text not null,
  customer_name text not null,
  customer_phone text not null default '',
  customer_address text not null default '',
  invoice_date date not null default current_date,
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  paid numeric(12,2) not null default 0 check (paid >= 0),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, invoice_no),
  check (paid <= total + 0.01)
);

create index if not exists invoices_user_date_idx
  on public.invoices (user_id, invoice_date desc, created_at desc);

alter table public.invoices enable row level security;

drop policy if exists "Users can view their own invoices" on public.invoices;
create policy "Users can view their own invoices"
  on public.invoices for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own invoices" on public.invoices;
create policy "Users can insert their own invoices"
  on public.invoices for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own invoices" on public.invoices;
create policy "Users can update their own invoices"
  on public.invoices for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own invoices" on public.invoices;
create policy "Users can delete their own invoices"
  on public.invoices for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.invoices to authenticated;

-- Enable Realtime for live updates on other devices.
do $$
begin
  alter publication supabase_realtime add table public.invoices;
exception
  when duplicate_object then null;
  when others then
    if position('already member' in sqlerrm) = 0 then raise; end if;
end $$;
