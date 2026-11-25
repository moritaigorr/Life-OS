create table public.life_areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  template_key text,
  name text not null,
  sort_order integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint life_areas_user_id_id_key unique (user_id, id),
  constraint life_areas_user_template_key unique (user_id, template_key),
  constraint life_areas_name_valid check (
    name = btrim(name, E' \t\n\r\f\v')
    and name ~ '[^[:space:]]'
    and char_length(name) between 1 and 60
  ),
  constraint life_areas_sort_order_valid check (sort_order >= 0)
);

create index life_areas_user_sort_order_idx
  on public.life_areas (user_id, sort_order, id)
  where archived_at is null;

create function public.set_life_area_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.set_life_area_updated_at() from public, anon, authenticated;

create trigger life_areas_set_updated_at
  before update on public.life_areas
  for each row
  execute function public.set_life_area_updated_at();

create table public.assessments (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  assessed_on date not null,
  comment text,
  created_at timestamptz not null default now(),
  constraint assessments_user_id_id_key unique (user_id, id),
  constraint assessments_comment_valid check (
    comment is null or (
      comment = btrim(comment, E' \t\n\r\f\v')
      and comment ~ '[^[:space:]]'
      and char_length(comment) <= 1000
    )
  )
);

create index assessments_user_date_idx
  on public.assessments (user_id, assessed_on desc, created_at desc);

create table public.assessment_scores (
  user_id uuid not null default auth.uid(),
  assessment_id uuid not null,
  life_area_id uuid not null,
  area_name_snapshot text not null,
  area_sort_order_snapshot integer not null,
  score smallint not null,
  needs_attention boolean not null default false,
  created_at timestamptz not null default now(),
  constraint assessment_scores_pkey primary key (user_id, assessment_id, life_area_id),
  constraint assessment_scores_user_assessment_fkey
    foreign key (user_id, assessment_id)
    references public.assessments (user_id, id) on delete cascade,
  constraint assessment_scores_user_area_fkey
    foreign key (user_id, life_area_id)
    references public.life_areas (user_id, id) on delete cascade,
  constraint assessment_scores_name_valid check (
    area_name_snapshot = btrim(area_name_snapshot, E' \t\n\r\f\v')
    and area_name_snapshot ~ '[^[:space:]]'
    and char_length(area_name_snapshot) between 1 and 60
  ),
  constraint assessment_scores_sort_order_valid check (area_sort_order_snapshot >= 0),
  constraint assessment_scores_score_valid check (score between 0 and 10)
);

create index assessment_scores_assessment_idx
  on public.assessment_scores (user_id, assessment_id, area_sort_order_snapshot);

alter table public.life_areas enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_scores enable row level security;

revoke all on table public.life_areas, public.assessments, public.assessment_scores
  from anon, authenticated;
grant select on table public.life_areas, public.assessments, public.assessment_scores
  to authenticated;
grant insert (template_key, name, sort_order) on table public.life_areas to authenticated;
grant update (name, sort_order) on table public.life_areas to authenticated;

create policy "Users can read their own life areas"
  on public.life_areas for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own life areas"
  on public.life_areas for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own life areas"
  on public.life_areas for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can read their own assessments"
  on public.assessments for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can read their own assessment scores"
  on public.assessment_scores for select to authenticated
  using ((select auth.uid()) = user_id);

create function public.ensure_default_life_areas()
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

  insert into public.life_areas (user_id, template_key, name, sort_order)
  values
    (v_user_id, 'physical_health', 'Saúde física', 0),
    (v_user_id, 'mental_health', 'Saúde mental', 1),
    (v_user_id, 'career', 'Carreira', 2),
    (v_user_id, 'finances', 'Finanças', 3),
    (v_user_id, 'learning', 'Estudos', 4),
    (v_user_id, 'relationships', 'Relacionamentos', 5),
    (v_user_id, 'personal_projects', 'Projetos pessoais', 6),
    (v_user_id, 'leisure', 'Lazer', 7)
  on conflict (user_id, template_key) do nothing;
end;
$$;

create function public.reorder_life_areas(p_area_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_active_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_area_ids is null then
    raise exception 'Area order is required' using errcode = '22023';
  end if;

  select count(*) into v_active_count
    from public.life_areas
    where user_id = v_user_id and archived_at is null;

  if cardinality(p_area_ids) <> v_active_count
    or (select count(distinct area_id) from unnest(p_area_ids) as item(area_id)) <> v_active_count
    or exists (
      select 1
      from unnest(p_area_ids) as item(area_id)
      left join public.life_areas as area
        on area.id = item.area_id
        and area.user_id = v_user_id
        and area.archived_at is null
      where area.id is null
    ) then
    raise exception 'Area order must include every active area once' using errcode = '22023';
  end if;

  update public.life_areas as area
    set sort_order = item.ordinality::integer - 1,
        updated_at = now()
    from unnest(p_area_ids) with ordinality as item(area_id, ordinality)
    where area.id = item.area_id and area.user_id = v_user_id;
end;
$$;

create function public.set_life_area_archived(p_area_id uuid, p_archived boolean)
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
  if p_area_id is null or p_archived is null then
    raise exception 'Area and archive state are required' using errcode = '22023';
  end if;

  update public.life_areas
    set archived_at = case when p_archived then now() else null end,
        updated_at = now()
    where id = p_area_id and user_id = v_user_id;
end;
$$;

create function public.create_life_assessment(
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
  v_existing_date date;
  v_existing_comment text;
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
  if p_scores is null or jsonb_typeof(p_scores) <> 'array' then
    raise exception 'Assessment scores must be an array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_scores) = 0 then
    raise exception 'At least one area must be scored' using errcode = '22023';
  end if;

  select count(*), count(distinct score.area_id)
    into v_input_count, v_distinct_count
    from jsonb_to_recordset(p_scores) as score(area_id uuid, score integer, needs_attention boolean);
  if v_input_count <> v_distinct_count or exists (
    select 1 from jsonb_to_recordset(p_scores)
      as score(area_id uuid, score integer, needs_attention boolean)
    where score.area_id is null or score.score is null or score.score not between 0 and 10
      or score.needs_attention is null
  ) then
    raise exception 'Invalid assessment scores' using errcode = '22023';
  end if;

  select assessed_on, comment into v_existing_date, v_existing_comment
    from public.assessments
    where id = p_assessment_id and user_id = v_user_id;
  if found then
    if v_existing_date <> p_assessed_on or v_existing_comment is distinct from p_comment
      or exists (
        select area_id, score, needs_attention
          from jsonb_to_recordset(p_scores)
            as input(area_id uuid, score integer, needs_attention boolean)
        except
        select life_area_id, score::integer, needs_attention
          from public.assessment_scores
          where assessment_id = p_assessment_id and user_id = v_user_id
      ) or exists (
        select life_area_id, score::integer, needs_attention
          from public.assessment_scores
          where assessment_id = p_assessment_id and user_id = v_user_id
        except
        select area_id, score, needs_attention
          from jsonb_to_recordset(p_scores)
            as input(area_id uuid, score integer, needs_attention boolean)
      ) then
      raise exception 'Assessment operation ID was reused with different data' using errcode = '22023';
    end if;
    return p_assessment_id;
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

  insert into public.assessments (id, user_id, assessed_on, comment)
    values (p_assessment_id, v_user_id, p_assessed_on, p_comment);

  insert into public.assessment_scores (
    user_id, assessment_id, life_area_id, area_name_snapshot,
    area_sort_order_snapshot, score, needs_attention
  )
  select v_user_id, p_assessment_id, area.id, area.name,
         area.sort_order, input.score::smallint, input.needs_attention
    from jsonb_to_recordset(p_scores)
      as input(area_id uuid, score integer, needs_attention boolean)
    join public.life_areas as area
      on area.id = input.area_id
      and area.user_id = v_user_id
      and area.archived_at is null;

  return p_assessment_id;
end;
$$;

revoke all on function public.ensure_default_life_areas() from public, anon, authenticated;
revoke all on function public.reorder_life_areas(uuid[]) from public, anon, authenticated;
revoke all on function public.set_life_area_archived(uuid, boolean) from public, anon, authenticated;
revoke all on function public.create_life_assessment(uuid, date, text, jsonb) from public, anon, authenticated;
grant execute on function public.ensure_default_life_areas() to authenticated;
grant execute on function public.reorder_life_areas(uuid[]) to authenticated;
grant execute on function public.set_life_area_archived(uuid, boolean) to authenticated;
grant execute on function public.create_life_assessment(uuid, date, text, jsonb) to authenticated;
