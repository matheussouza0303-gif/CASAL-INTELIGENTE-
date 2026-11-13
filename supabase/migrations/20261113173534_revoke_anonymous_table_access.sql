revoke all on table
  public.households,
  public.household_members,
  public.ci_records
from anon, public;

grant select on public.households to authenticated;
grant select on public.household_members to authenticated;
grant select, insert, update, delete on public.ci_records to authenticated;
