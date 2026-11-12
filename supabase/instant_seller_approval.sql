-- DigitalBazaar: enable instant seller approval.
-- Run in Supabase Dashboard > SQL Editor > New query.
-- This approves existing pending seller applications and makes future
-- seller signups approved automatically by the auth trigger.

alter table public.seller_profiles
  alter column status set default 'approved';

update public.seller_profiles
set status = 'approved'
where status = 'pending';

create or replace function public.handle_new_seller_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', '') = 'seller' then
    insert into public.seller_profiles (
      user_id, shop_name, product_category, description, status
    ) values (
      new.id,
      coalesce(nullif(new.raw_user_meta_data ->> 'shop_name', ''), 'My Shop'),
      coalesce(nullif(new.raw_user_meta_data ->> 'product_category', ''), 'Other'),
      coalesce(new.raw_user_meta_data ->> 'description', ''),
      'approved'
    )
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

-- Note: Instant approval grants seller account status only.
-- Product publication should still require file validation/moderation.
