-- SECURITY BOUNDARY: ONLY trusted Supabase Edge Functions (service_role) may
-- access raw scan locations, challenges, or mint warrior ownership.
-- DO NOT expose service_role credentials in Android. Review existing legacy
-- client-generated warriors before deploying this migration.

create table if not exists public.scan_locations_private (
  user_id uuid primary key references auth.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  site_kind text not null default 'private_residence'
    check (site_kind in ('private_residence','private_noncommercial')),
  business_check_reference text not null,
  registered_at timestamptz not null default now(),
  last_changed_at timestamptz not null default now()
);
alter table public.scan_locations_private enable row level security;
revoke all on public.scan_locations_private from public, anon, authenticated;
grant all on public.scan_locations_private to service_role;

create or replace function public.enforce_scan_location_cooldown()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if old.last_changed_at > now() - interval '30 days' then
      raise exception 'Scan location can be changed only once per 30 days';
    end if;
    new.registered_at := old.registered_at;
    new.last_changed_at := now();
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_scan_location_cooldown() from public, anon, authenticated;
drop trigger if exists scan_location_cooldown on public.scan_locations_private;
create trigger scan_location_cooldown before update on public.scan_locations_private
for each row execute function public.enforce_scan_location_cooldown();

create table if not exists public.scan_challenges_private (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  normalized_barcode text not null,
  barcode_hash text not null check (barcode_hash ~ '^[0-9a-f]{64}$'),
  code_hash text not null,
  location_changed_at timestamptz not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  consumed_at timestamptz,
  photo_verdict jsonb
);
create index if not exists scan_challenges_owner_idx on public.scan_challenges_private(user_id, created_at desc);
alter table public.scan_challenges_private enable row level security;
revoke all on public.scan_challenges_private from public, anon, authenticated;
grant all on public.scan_challenges_private to service_role;

create table if not exists public.scan_verified_claims_private (
  user_id uuid not null references auth.users(id) on delete cascade,
  barcode_hash text not null check (barcode_hash ~ '^[0-9a-f]{64}$'),
  challenge_id uuid not null unique references public.scan_challenges_private(id),
  proof_digest text not null,
  verified_at timestamptz not null default now(),
  primary key (user_id, barcode_hash)
);
alter table public.scan_verified_claims_private enable row level security;
revoke all on public.scan_verified_claims_private from public, anon, authenticated;
grant all on public.scan_verified_claims_private to service_role;

-- No direct client claim or blueprint creation, even for signed-in users.
revoke insert, delete on public.warrior_blueprints from authenticated;
revoke insert, delete, update on public.user_warriors from authenticated;
-- Player progression updates cannot change barcode, blueprint, or ownership.
-- Server validation of XP/loot is a separate production milestone.
grant update (level, xp, equipment, regular_attack_override,
  special_attack_override, progression, updated_at)
  on public.user_warriors to authenticated;
drop policy if exists "blueprints_insert_hash_matches_barcode" on public.warrior_blueprints;
drop policy if exists "user_warriors_insert_own" on public.user_warriors;
drop policy if exists "user_warriors_delete_own" on public.user_warriors;

-- Atomic one-use redemption; ONLY callable with a server secret role.
create or replace function public.finalize_verified_warrior_scan(
  p_user_id uuid,
  p_challenge_id uuid,
  p_code_hash text,
  p_photo_digest text,
  p_faction text,
  p_category integer,
  p_seed bigint,
  p_blueprint jsonb,
  p_verdict jsonb
)
returns uuid language plpgsql security definer
set search_path = ''
as $$
declare
  c public.scan_challenges_private%rowtype;
  blueprint_id uuid;
begin
  select * into c from public.scan_challenges_private
    where id = p_challenge_id and user_id = p_user_id for update;
  if not found or c.consumed_at is not null or c.expires_at < now()
     or c.code_hash <> p_code_hash then
    raise exception 'Invalid, expired, or already used challenge';
  end if;
  if not exists (select 1 from public.scan_locations_private l
                 where l.user_id = p_user_id and l.last_changed_at = c.location_changed_at) then
    raise exception 'Scanning location has changed since issuance';
  end if;
  if p_blueprint->>'gender' not in ('male','female')
    or p_blueprint->>'faction' <> p_faction
    or (p_blueprint->>'category')::integer <> p_category then
    raise exception 'Invalid base warrior blueprint';
  end if;
  if exists (select 1 from public.user_warriors uw
    join public.warrior_blueprints wb on wb.id=uw.blueprint_id
    where uw.user_id=p_user_id and wb.barcode_hash=c.barcode_hash) then
    raise exception 'UPC already acquired';
  end if;
  insert into public.warrior_blueprints
    (barcode_hash, normalized_barcode, faction, category, seed_value, base_data)
    values (c.barcode_hash, c.normalized_barcode, p_faction, p_category, p_seed, p_blueprint)
    on conflict (barcode_hash) do nothing;
  select id into blueprint_id from public.warrior_blueprints
    where barcode_hash=c.barcode_hash;
  if blueprint_id is null then raise exception 'Blueprint missing'; end if;
  insert into public.user_warriors(user_id, blueprint_id, barcode_value)
    values(p_user_id, blueprint_id, c.normalized_barcode);
  insert into public.scan_verified_claims_private
    (user_id,barcode_hash,challenge_id,proof_digest)
    values(p_user_id,c.barcode_hash,c.id,p_photo_digest);
  update public.scan_challenges_private set consumed_at=now(), photo_verdict=p_verdict
    where id=c.id;
  return blueprint_id;
end;
$$;
revoke all on function public.finalize_verified_warrior_scan(
  uuid,uuid,text,text,text,integer,bigint,jsonb,jsonb
) from public, anon, authenticated;
grant execute on function public.finalize_verified_warrior_scan(
  uuid,uuid,text,text,text,integer,bigint,jsonb,jsonb
) to service_role;
