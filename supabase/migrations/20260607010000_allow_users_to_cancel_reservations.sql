grant update (status) on table public.reservations to authenticated;

drop policy if exists "users can cancel own reservations" on public.reservations;

create policy "users can cancel own reservations"
on public.reservations
for update
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and status = 'confirmed'
)
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and status = 'cancelled'
);
