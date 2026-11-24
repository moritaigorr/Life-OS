create table public.tasks (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tasks_title_valid check (
    title = btrim(title)
    and char_length(title) between 1 and 200
  )
);

create index tasks_user_created_at_idx
  on public.tasks (user_id, created_at desc);

create function public.set_task_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.set_task_updated_at() from public, anon, authenticated;

create trigger tasks_set_updated_at
  before update on public.tasks
  for each row
  execute function public.set_task_updated_at();

alter table public.tasks enable row level security;

revoke all on table public.tasks from anon, authenticated;
grant select on table public.tasks to authenticated;
grant insert (id, user_id, title) on table public.tasks to authenticated;
grant update (title) on table public.tasks to authenticated;
grant delete on table public.tasks to authenticated;

create policy "Users can read their own tasks"
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their own tasks"
  on public.tasks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own tasks"
  on public.tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own tasks"
  on public.tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
