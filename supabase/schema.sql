-- DigitalBazaar: seller application foundation
-- Run this in Supabase Dashboard > SQL Editor > New query.
-- Safe to run once on a fresh project.

create table if not exists public.seller_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  shop_name text not null,
  product_category text not null,
  description text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.seller_profiles enable row level security;

-- Sellers can read only their own application.
drop policy if exists "Sellers can view own profile" on public.seller_profiles;
create policy "Sellers can view own profile"
  on public.seller_profiles
  for select
  to authenticated
  using (auth.uid() = user_id);

-- Profile is created by the trusted auth trigger below, not directly by the browser.
-- No client insert/update/delete policies are intentionally provided.

create or replace function public.handle_new_seller_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', '') = 'seller' then
    insert into public.seller_profiles (
      user_id, shop_name, product_category, description
    ) values (
      new.id,
      coalesce(nullif(new.raw_user_meta_data ->> 'shop_name', ''), 'My Shop'),
      coalesce(nullif(new.raw_user_meta_data ->> 'product_category', ''), 'Other'),
      coalesce(new.raw_user_meta_data ->> 'description', '')
    )
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_digitalbazaar on auth.users;
create trigger on_auth_user_created_digitalbazaar
  after insert on auth.users
  for each row execute procedure public.handle_new_seller_signup();

-- Important:
-- Do not add a public INSERT policy or expose service_role/secret keys in frontend code.
-- Admin approval and product uploads will be added in later, separately secured steps.
