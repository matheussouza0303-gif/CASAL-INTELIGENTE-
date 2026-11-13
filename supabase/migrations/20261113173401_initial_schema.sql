create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 120),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  person_name text not null check (person_name in ('Matheus', 'Letícia')),
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (household_id, user_id),
  unique (user_id)
);

create table if not exists public.ci_records (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  record_path text not null check (char_length(record_path) between 1 and 300),
  data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, record_path)
);

create index if not exists ci_records_household_path_idx
  on public.ci_records (household_id, record_path);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists ci_records_set_updated_at on public.ci_records;
create trigger ci_records_set_updated_at
before update on public.ci_records
for each row execute function public.set_updated_at();

create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.user_id = auth.uid()
  );
$$;

create or replace function public.is_household_owner(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.user_id = auth.uid()
      and hm.role = 'owner'
  );
$$;

create or replace function public.create_household(p_name text, p_person_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_person_name not in ('Matheus', 'Letícia') then
    raise exception 'Invalid person name';
  end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then
    raise exception 'This user already belongs to a household';
  end if;

  insert into public.households (name, created_by)
  values (p_name, auth.uid())
  returning id into v_household_id;

  insert into public.household_members (household_id, user_id, person_name, role)
  values (v_household_id, auth.uid(), p_person_name, 'owner');

  return v_household_id;
end;
$$;

create or replace function public.add_household_member(
  p_household_id uuid,
  p_email text,
  p_person_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  if auth.uid() is null or not public.is_household_owner(p_household_id) then
    raise exception 'Only the household owner can add a member';
  end if;
  if p_person_name not in ('Matheus', 'Letícia') then
    raise exception 'Invalid person name';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No authenticated account found for this email. Create the account first.';
  end if;

  insert into public.household_members (household_id, user_id, person_name, role)
  values (p_household_id, v_user_id, p_person_name, 'member')
  on conflict (household_id, user_id) do update
    set person_name = excluded.person_name;
end;
$$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.ci_records enable row level security;

drop policy if exists households_select_member on public.households;
create policy households_select_member
on public.households for select to authenticated
using (public.is_household_member(id));

drop policy if exists household_members_select_member on public.household_members;
create policy household_members_select_member
on public.household_members for select to authenticated
using (public.is_household_member(household_id));

drop policy if exists ci_records_select_member on public.ci_records;
create policy ci_records_select_member
on public.ci_records for select to authenticated
using (public.is_household_member(household_id));

drop policy if exists ci_records_insert_member on public.ci_records;
create policy ci_records_insert_member
on public.ci_records for insert to authenticated
with check (public.is_household_member(household_id));

drop policy if exists ci_records_update_member on public.ci_records;
create policy ci_records_update_member
on public.ci_records for update to authenticated
using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

drop policy if exists ci_records_delete_member on public.ci_records;
create policy ci_records_delete_member
on public.ci_records for delete to authenticated
using (public.is_household_member(household_id));

revoke all on function public.is_household_member(uuid) from public, anon;
revoke all on function public.is_household_owner(uuid) from public, anon;
revoke all on function public.create_household(text, text) from public, anon;
revoke all on function public.add_household_member(uuid, text, text) from public, anon;

grant usage on schema public to authenticated;
grant select on public.households to authenticated;
grant select on public.household_members to authenticated;
grant select, insert, update, delete on public.ci_records to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_owner(uuid) to authenticated;
grant execute on function public.create_household(text, text) to authenticated;
grant execute on function public.add_household_member(uuid, text, text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ci_records'
  ) then
    execute 'alter publication supabase_realtime add table public.ci_records';
  end if;
end;
$$;
