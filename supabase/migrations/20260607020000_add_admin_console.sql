create extension if not exists pgcrypto with schema extensions;

alter table public.reservations
  drop constraint if exists reservations_status_values;

alter table public.reservations
  add constraint reservations_status_values
  check (status in ('confirmed', 'cancelled', 'cancelled_by_admin'));

drop policy if exists "users can cancel own reservations" on public.reservations;

create policy "users can cancel own reservations"
on public.reservations
for update
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and status in ('confirmed', 'cancelled_by_admin')
)
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and status = 'cancelled'
);

create table if not exists public.admin_settings (
  id boolean primary key default true check (id),
  password_hash text not null,
  updated_at timestamptz not null default now()
);

alter table public.admin_settings enable row level security;
revoke all on table public.admin_settings from anon, authenticated;

create table if not exists public.room_controls (
  room_code text primary key,
  status text not null check (status in ('blocked', 'disabled')),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.room_controls enable row level security;
revoke all on table public.room_controls from anon, authenticated;

create or replace function public.admin_password_valid(p_password text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select exists (
    select 1
    from public.admin_settings
    where id = true
      and password_hash = extensions.crypt(p_password, password_hash)
  );
$$;

revoke all on function public.admin_password_valid(text) from public, anon, authenticated;

create or replace function public.admin_verify_access(p_password text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select (select auth.uid()) is not null
    and public.admin_password_valid(p_password);
$$;

revoke all on function public.admin_verify_access(text) from public;
grant execute on function public.admin_verify_access(text) to authenticated;

create or replace function public.admin_list_reservations(p_password text)
returns table (
  id uuid,
  user_email text,
  room_code text,
  room_name text,
  reservation_date date,
  start_time time,
  end_time time,
  purpose text,
  expected_people integer,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
begin
  if (select auth.uid()) is null or not public.admin_password_valid(p_password) then
    raise exception 'invalid admin password' using errcode = '42501';
  end if;

  return query
  select
    reservation.id,
    account.email::text,
    reservation.room_code,
    reservation.room_name,
    reservation.reservation_date,
    reservation.start_time,
    reservation.end_time,
    reservation.purpose,
    reservation.expected_people,
    reservation.status,
    reservation.created_at
  from public.reservations as reservation
  left join auth.users as account on account.id = reservation.user_id
  order by reservation.reservation_date desc, reservation.start_time desc, reservation.created_at desc;
end;
$$;

revoke all on function public.admin_list_reservations(text) from public;
grant execute on function public.admin_list_reservations(text) to authenticated;

create or replace function public.admin_cancel_reservation(
  p_password text,
  p_reservation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  changed_rows integer;
begin
  if (select auth.uid()) is null or not public.admin_password_valid(p_password) then
    raise exception 'invalid admin password' using errcode = '42501';
  end if;

  update public.reservations
  set status = 'cancelled_by_admin',
      updated_at = now()
  where id = p_reservation_id
    and status = 'confirmed';

  get diagnostics changed_rows = row_count;
  return changed_rows = 1;
end;
$$;

revoke all on function public.admin_cancel_reservation(text, uuid) from public;
grant execute on function public.admin_cancel_reservation(text, uuid) to authenticated;

create or replace function public.get_room_controls()
returns table (
  room_code text,
  status text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select control.room_code, control.status
  from public.room_controls as control
  order by control.room_code;
$$;

revoke all on function public.get_room_controls() from public;
grant execute on function public.get_room_controls() to anon, authenticated;

create or replace function public.admin_set_room_status(
  p_password text,
  p_room_code text,
  p_status text
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if (select auth.uid()) is null or not public.admin_password_valid(p_password) then
    raise exception 'invalid admin password' using errcode = '42501';
  end if;

  if p_status not in ('rentable', 'blocked', 'disabled') then
    raise exception 'invalid room status' using errcode = '22023';
  end if;

  if p_status = 'rentable' then
    delete from public.room_controls where room_code = p_room_code;
  else
    insert into public.room_controls (room_code, status, updated_by, updated_at)
    values (p_room_code, p_status, (select auth.uid()), now())
    on conflict (room_code)
    do update set
      status = excluded.status,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at;
  end if;

  return true;
end;
$$;

revoke all on function public.admin_set_room_status(text, text, text) from public;
grant execute on function public.admin_set_room_status(text, text, text) to authenticated;
