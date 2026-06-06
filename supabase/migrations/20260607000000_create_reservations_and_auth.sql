-- Supabase SQL Editor에서 이 파일 전체를 실행하세요.

create extension if not exists btree_gist;

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid default auth.uid() references auth.users(id) on delete cascade,
  room_code text not null,
  room_name text not null,
  reservation_date date not null,
  start_time time not null,
  end_time time not null,
  purpose text not null,
  expected_people integer not null,
  status text not null default 'confirmed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reservations_room_code_length check (char_length(trim(room_code)) between 1 and 30),
  constraint reservations_room_name_length check (char_length(trim(room_name)) between 1 and 100),
  constraint reservations_time_order check (start_time < end_time),
  constraint reservations_purpose_length check (char_length(trim(purpose)) between 1 and 200),
  constraint reservations_expected_people_range check (expected_people between 1 and 999),
  constraint reservations_status_values check (status in ('confirmed', 'cancelled'))
);

-- 기존 테이블에 로그인 소유자 열을 추가하는 마이그레이션입니다.
alter table public.reservations
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.reservations
  alter column user_id set default auth.uid();

create index if not exists reservations_room_date_idx
  on public.reservations (room_code, reservation_date);

create index if not exists reservations_created_at_idx
  on public.reservations (created_at desc);

create index if not exists reservations_user_id_idx
  on public.reservations (user_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reservations_no_time_overlap'
      and conrelid = 'public.reservations'::regclass
  ) then
    alter table public.reservations
      add constraint reservations_no_time_overlap
      exclude using gist (
        room_code with =,
        reservation_date with =,
        (tsrange(
          reservation_date + start_time,
          reservation_date + end_time,
          '[)'
        )) with &&
      )
      where (status = 'confirmed');
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists reservations_set_updated_at on public.reservations;
create trigger reservations_set_updated_at
before update on public.reservations
for each row
execute function public.set_updated_at();

-- 공개 화면에는 예약 충돌 확인에 필요한 시간만 반환합니다.
create or replace function public.get_reserved_slots(
  target_room_code text,
  target_date date
)
returns table (
  start_time time,
  end_time time
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select reservation.start_time, reservation.end_time
  from public.reservations as reservation
  where reservation.room_code = target_room_code
    and reservation.reservation_date = target_date
    and reservation.status = 'confirmed'
  order by reservation.start_time;
$$;

alter table public.reservations enable row level security;

revoke all on table public.reservations from anon, authenticated;
grant select on table public.reservations to authenticated;
grant insert (
  room_code,
  room_name,
  reservation_date,
  start_time,
  end_time,
  purpose,
  expected_people
) on public.reservations to authenticated;

revoke all on function public.get_reserved_slots(text, date) from public;
grant execute on function public.get_reserved_slots(text, date) to anon, authenticated;

drop policy if exists "public can read confirmed reservations" on public.reservations;
drop policy if exists "public can create future reservations" on public.reservations;
drop policy if exists "users can read own reservations" on public.reservations;
drop policy if exists "users can create own reservations" on public.reservations;

create policy "users can read own reservations"
on public.reservations
for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
);

create policy "users can create own reservations"
on public.reservations
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and status = 'confirmed'
  and reservation_date >= current_date
  and start_time < end_time
  and char_length(trim(purpose)) between 1 and 200
  and expected_people between 1 and 999
);

-- 기존 비로그인 예약은 user_id가 null이라 내 예약에는 표시되지 않지만,
-- get_reserved_slots 함수에는 포함되어 기존 예약 시간 충돌은 유지됩니다.
