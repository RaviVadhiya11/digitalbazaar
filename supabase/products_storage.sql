-- DigitalBazaar product uploads (private digital files).
-- Run once in Supabase Dashboard > SQL Editor.
-- Files remain private; do not make this bucket public.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null,
  price numeric(10,2) not null check (price > 0 and price <= 10000),
  file_path text not null unique,
  file_name text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 52428800),
  mime_type text not null,
  status text not null default 'pending'
    check (status in ('pending','active','rejected')),
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;

drop policy if exists "Seller can view own products or active products" on public.products;
create policy "Seller can view own products or active products"
  on public.products for select to authenticated
  using (seller_id = auth.uid() or status = 'active');

drop policy if exists "Approved sellers can create products" on public.products;
create policy "Approved sellers can create products"
  on public.products for insert to authenticated
  with check (
    seller_id = auth.uid()
    and exists (
      select 1 from public.seller_profiles s
      where s.user_id = auth.uid() and s.status = 'approved'
    )
  );

drop policy if exists "Sellers can delete own pending products" on public.products;
create policy "Sellers can delete own pending products"
  on public.products for delete to authenticated
  using (seller_id = auth.uid() and status = 'pending');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'digital-products',
  'digital-products',
  false,
  52428800,
  array['application/pdf','image/png','image/jpeg','application/zip','application/x-zip-compressed','application/octet-stream']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 52428800,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Approved sellers upload own product files" on storage.objects;
create policy "Approved sellers upload own product files"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'digital-products'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.seller_profiles s
      where s.user_id = auth.uid() and s.status = 'approved'
    )
  );

drop policy if exists "Sellers read own product files" on storage.objects;
create policy "Sellers read own product files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'digital-products'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Sellers delete own product files" on storage.objects;
create policy "Sellers delete own product files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'digital-products'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Product listings start as pending. Admin moderation/publication is a later step.
-- Keep this bucket private. Never expose a service_role or secret key in the website.
