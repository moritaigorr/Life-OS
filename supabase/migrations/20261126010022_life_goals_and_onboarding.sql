create table public.life_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null,
  year smallint not null,
  quarter smallint,
  parent_goal_id uuid,
  life_area_id uuid,
  title text not null,
  success_criteria text not null,
  progress smallint not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint life_goals_user_id_id_key unique (user_id, id),
  constraint life_goals_area_fkey foreign key (user_id, life_area_id)
    references public.life_areas (user_id, id) on delete set null (life_area_id),
  constraint life_goals_parent_fkey foreign key (user_id, parent_goal_id)
    references public.life_goals (user_id, id) on delete set null (parent_goal_id),
  constraint life_goals_kind_valid check (kind in ('annual', 'quarterly')),
  constraint life_goals_period_valid check (
    (kind = 'annual' and quarter is null and parent_goal_id is null)
    or (kind = 'quarterly' and quarter between 1 and 4)
  ),
  constraint life_goals_year_valid check (year between 2000 and 2200),
  constraint life_goals_title_valid check (
    title = btrim(title, E' \t\n\r\f\v')
    and title ~ '[^[:space:]]'
    and char_length(title) between 1 and 120
  ),
  constraint life_goals_success_criteria_valid check (
    success_criteria = btrim(success_criteria, E' \t\n\r\f\v')
    and success_criteria ~ '[^[:space:]]'
    and char_length(success_criteria) between 1 and 500
  ),
  constraint life_goals_progress_valid check (progress between 0 and 100)
);

create index life_goals_user_period_idx
  on public.life_goals (user_id, year desc, kind, quarter)
  where archived_at is null;

create function public.validate_life_goal_parent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_kind text;
  v_parent_year smallint;
begin
  if new.parent_goal_id is null then
    return new;
  end if;

  select kind, year into v_parent_kind, v_parent_year
    from public.life_goals
    where user_id = new.user_id and id = new.parent_goal_id;

  if v_parent_kind is distinct from 'annual' or v_parent_year is distinct from new.year then
    raise exception 'Quarterly goals can only be linked to an annual goal in the same year'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function public.validate_life_goal_parent() from public, anon, authenticated;

create trigger life_goals_validate_parent
  before insert or update of parent_goal_id, kind, year on public.life_goals
  for each row execute function public.validate_life_goal_parent();

create function public.set_life_goal_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.set_life_goal_updated_at() from public, anon, authenticated;

create trigger life_goals_set_updated_at
  before update on public.life_goals
  for each row execute function public.set_life_goal_updated_at();

alter table public.life_goals enable row level security;
revoke all on table public.life_goals from anon, authenticated;
grant select on public.life_goals to authenticated;
grant insert (kind, year, quarter, parent_goal_id, life_area_id, title, success_criteria, progress)
  on public.life_goals to authenticated;
grant update (kind, year, quarter, parent_goal_id, life_area_id, title, success_criteria, progress, archived_at)
  on public.life_goals to authenticated;

create policy "Users can read their own life goals"
  on public.life_goals for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own life goals"
  on public.life_goals for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own life goals"
  on public.life_goals for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create table public.life_onboarding (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  status text not null default 'in_progress',
  current_step smallint not null default 0,
  life_vision text,
  updated_at timestamptz not null default now(),
  constraint life_onboarding_status_valid check (
    status in ('in_progress', 'skipped', 'completed')
  ),
  constraint life_onboarding_step_valid check (current_step between 0 and 1),
  constraint life_onboarding_vision_valid check (
    life_vision is null or (
      life_vision = btrim(life_vision, E' \t\n\r\f\v')
      and char_length(life_vision) between 1 and 2000
    )
  )
);

alter table public.life_onboarding enable row level security;
revoke all on table public.life_onboarding from anon, authenticated;
grant select on public.life_onboarding to authenticated;
grant insert (status, current_step, life_vision) on public.life_onboarding to authenticated;
grant update (status, current_step, life_vision) on public.life_onboarding to authenticated;

create policy "Users can read their own onboarding"
  on public.life_onboarding for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own onboarding"
  on public.life_onboarding for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own onboarding"
  on public.life_onboarding for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter table public.assessments add column archived_at timestamptz;

create function public.update_life_assessment(
  p_assessment_id uuid,
  p_assessed_on date,
  p_comment text,
  p_scores jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_input_count integer;
  v_distinct_count integer;
  v_valid_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_assessment_id is null or p_assessed_on is null then
    raise exception 'Assessment identity and date are required' using errcode = '22023';
  end if;
  if p_comment is not null and (
    p_comment <> btrim(p_comment, E' \t\n\r\f\v')
    or p_comment !~ '[^[:space:]]'
    or char_length(p_comment) > 1000
  ) then
    raise exception 'Invalid assessment comment' using errcode = '22023';
  end if;
  if p_scores is null or jsonb_typeof(p_scores) <> 'array'
    or jsonb_array_length(p_scores) = 0 then
    raise exception 'Assessment scores must be a non-empty array' using errcode = '22023';
  end if;

  perform 1 from public.assessments
    where id = p_assessment_id
      and user_id = v_user_id
      and archived_at is null
    for update;
  if not found then
    raise exception 'Active assessment not found' using errcode = '42501';
  end if;

  select count(*), count(distinct score.area_id)
    into v_input_count, v_distinct_count
    from jsonb_to_recordset(p_scores)
      as score(area_id uuid, score integer, needs_attention boolean);
  if v_input_count <> v_distinct_count or exists (
    select 1 from jsonb_to_recordset(p_scores)
      as score(area_id uuid, score integer, needs_attention boolean)
    where score.area_id is null or score.score is null
      or score.score not between 0 and 10 or score.needs_attention is null
  ) then
    raise exception 'Invalid assessment scores' using errcode = '22023';
  end if;

  select count(*) into v_valid_count
    from jsonb_to_recordset(p_scores)
      as input(area_id uuid, score integer, needs_attention boolean)
    join public.life_areas as area
      on area.id = input.area_id
      and area.user_id = v_user_id
      and area.archived_at is null;
  if v_valid_count <> v_input_count then
    raise exception 'Assessment includes an unavailable area' using errcode = '22023';
  end if;

  update public.assessments
    set assessed_on = p_assessed_on, comment = p_comment
    where id = p_assessment_id and user_id = v_user_id;

  delete from public.assessment_scores as score
    using public.life_areas as area
    where score.user_id = v_user_id
      and score.assessment_id = p_assessment_id
      and area.id = score.life_area_id
      and area.user_id = v_user_id
      and area.archived_at is null;

  insert into public.assessment_scores (
    user_id, assessment_id, life_area_id, area_name_snapshot,
    area_sort_order_snapshot, score, needs_attention
  )
  select v_user_id, p_assessment_id, area.id, area.name,
         area.sort_order, input.score::smallint, input.needs_attention
    from public.life_areas as area
    left join jsonb_to_recordset(p_scores)
      as input(area_id uuid, score integer, needs_attention boolean)
      on input.area_id = area.id
    where area.user_id = v_user_id and area.archived_at is null;

  return p_assessment_id;
end;
$$;

create function public.set_life_assessment_archived(
  p_assessment_id uuid,
  p_archived boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_assessment_id is null or p_archived is null then
    raise exception 'Assessment and archive state are required' using errcode = '22023';
  end if;

  update public.assessments
    set archived_at = case when p_archived then now() else null end
    where id = p_assessment_id and user_id = v_user_id;
end;
$$;

revoke all on function public.update_life_assessment(uuid, date, text, jsonb)
  from public, anon, authenticated;
revoke all on function public.set_life_assessment_archived(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.update_life_assessment(uuid, date, text, jsonb)
  to authenticated;
grant execute on function public.set_life_assessment_archived(uuid, boolean)
  to authenticated;
