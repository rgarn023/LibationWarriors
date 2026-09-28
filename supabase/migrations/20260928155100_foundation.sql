-- Libation Warriors foundation schema
-- Auth users own profiles/progression. Barcode blueprints are global and immutable.
-- Client code must use a publishable/anon key + authenticated JWT, never service_role.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
	user_id uuid primary key references auth.users(id) on delete cascade,
	player_level integer not null default 1 check (player_level >= 1),
	player_xp bigint not null default 0 check (player_xp >= 0),
	party_barcode_hashes jsonb not null default '[]'::jsonb,
	settings jsonb not null default '{}'::jsonb,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create table if not exists public.warrior_blueprints (
	id uuid primary key default gen_random_uuid(),
	barcode_hash text not null unique check (barcode_hash ~ '^[0-9a-f]{64}$'),
	normalized_barcode text not null unique,
	faction text not null,
	category integer not null,
	seed_value bigint not null check (seed_value > 0),
	base_data jsonb not null,
	created_at timestamptz not null default now()
);

create table if not exists public.user_warriors (
	user_id uuid not null references auth.users(id) on delete cascade,
	blueprint_id uuid not null references public.warrior_blueprints(id) on delete restrict,
	barcode_value text not null,
	level integer not null default 1 check (level >= 1),
	xp bigint not null default 0 check (xp >= 0),
	equipment jsonb not null default '{}'::jsonb,
	regular_attack_override jsonb not null default '{}'::jsonb,
	special_attack_override jsonb not null default '{}'::jsonb,
	progression jsonb not null default '{}'::jsonb,
	acquired_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	primary key (user_id, blueprint_id),
	unique (user_id, barcode_value)
);

create index if not exists user_warriors_user_id_idx on public.user_warriors(user_id);
create index if not exists user_warriors_blueprint_id_idx on public.user_warriors(blueprint_id);

alter table public.profiles enable row level security;
alter table public.warrior_blueprints enable row level security;
alter table public.user_warriors enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.warrior_blueprints from anon, authenticated;
revoke all on table public.user_warriors from anon, authenticated;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select (id, barcode_hash, faction, category, seed_value, base_data, created_at)
	on table public.warrior_blueprints to authenticated;
grant insert (barcode_hash, normalized_barcode, faction, category, seed_value, base_data)
	on table public.warrior_blueprints to authenticated;
grant select, insert, update, delete on table public.user_warriors to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
	on public.profiles for select to authenticated
	using ((select auth.uid()) = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
	on public.profiles for insert to authenticated
	with check ((select auth.uid()) = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
	on public.profiles for update to authenticated
	using ((select auth.uid()) = user_id)
	with check ((select auth.uid()) = user_id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
	on public.profiles for delete to authenticated
	using ((select auth.uid()) = user_id);

drop policy if exists "blueprints_read_authenticated" on public.warrior_blueprints;
create policy "blueprints_read_authenticated"
	on public.warrior_blueprints for select to authenticated
	using (true);

drop policy if exists "blueprints_insert_hash_matches_barcode" on public.warrior_blueprints;
create policy "blueprints_insert_hash_matches_barcode"
	on public.warrior_blueprints for insert to authenticated
	with check (
		barcode_hash = encode(extensions.digest(normalized_barcode, 'sha256'), 'hex')
	);

drop policy if exists "user_warriors_select_own" on public.user_warriors;
create policy "user_warriors_select_own"
	on public.user_warriors for select to authenticated
	using ((select auth.uid()) = user_id);

drop policy if exists "user_warriors_insert_own" on public.user_warriors;
create policy "user_warriors_insert_own"
	on public.user_warriors for insert to authenticated
	with check ((select auth.uid()) = user_id);

drop policy if exists "user_warriors_update_own" on public.user_warriors;
create policy "user_warriors_update_own"
	on public.user_warriors for update to authenticated
	using ((select auth.uid()) = user_id)
	with check ((select auth.uid()) = user_id);

drop policy if exists "user_warriors_delete_own" on public.user_warriors;
create policy "user_warriors_delete_own"
	on public.user_warriors for delete to authenticated
	using ((select auth.uid()) = user_id);

create or replace function public.validate_user_warrior_barcode()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
	expected_hash text;
begin
	select wb.barcode_hash
	into expected_hash
	from public.warrior_blueprints wb
	where wb.id = new.blueprint_id;

	if expected_hash is null then
		raise exception 'Unknown warrior blueprint';
	end if;

	if encode(extensions.digest(new.barcode_value, 'sha256'), 'hex') <> expected_hash then
		raise exception 'Barcode does not match warrior blueprint';
	end if;
	return new;
end;
$$;

revoke all on function public.validate_user_warrior_barcode() from public, anon, authenticated;

drop trigger if exists validate_user_warrior_barcode_before_write on public.user_warriors;
create trigger validate_user_warrior_barcode_before_write
before insert or update of blueprint_id, barcode_value
on public.user_warriors
for each row execute function public.validate_user_warrior_barcode();
