create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.is_household_member(p_household_id uuid)
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

create or replace function private.is_household_owner(p_household_id uuid)
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

revoke all on function private.is_household_member(uuid) from public, anon;
revoke all on function private.is_household_owner(uuid) from public, anon;
grant execute on function private.is_household_member(uuid) to authenticated;
grant execute on function private.is_household_owner(uuid) to authenticated;

drop policy if exists households_select_member on public.households;
create policy households_select_member
on public.households for select to authenticated
using (private.is_household_member(id));

drop policy if exists household_members_select_member on public.household_members;
create policy household_members_select_member
on public.household_members for select to authenticated
using (private.is_household_member(household_id));

drop policy if exists ci_records_select_member on public.ci_records;
create policy ci_records_select_member
on public.ci_records for select to authenticated
using (private.is_household_member(household_id));

drop policy if exists ci_records_insert_member on public.ci_records;
create policy ci_records_insert_member
on public.ci_records for insert to authenticated
with check (private.is_household_member(household_id));

drop policy if exists ci_records_update_member on public.ci_records;
create policy ci_records_update_member
on public.ci_records for update to authenticated
using (private.is_household_member(household_id))
with check (private.is_household_member(household_id));

drop policy if exists ci_records_delete_member on public.ci_records;
create policy ci_records_delete_member
on public.ci_records for delete to authenticated
using (private.is_household_member(household_id));

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
  if auth.uid() is null or not private.is_household_owner(p_household_id) then
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

revoke all on function public.is_household_member(uuid) from public, anon, authenticated;
revoke all on function public.is_household_owner(uuid) from public, anon, authenticated;
grant execute on function public.add_household_member(uuid, text, text) to authenticated;

drop function public.is_household_member(uuid);
drop function public.is_household_owner(uuid);

create index if not exists households_created_by_idx
  on public.households(created_by);
create index if not exists ci_records_created_by_idx
  on public.ci_records(created_by) where created_by is not null;
create index if not exists ci_records_updated_by_idx
  on public.ci_records(updated_by) where updated_by is not null;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  new.updated_by = auth.uid();
  if tg_op = 'UPDATE' then
    if new.household_id <> old.household_id then
      raise exception 'Changing household_id is not allowed';
    end if;
    new.created_by = old.created_by;
  else
    new.created_by = auth.uid();
  end if;
  return new;
end;
$$;
