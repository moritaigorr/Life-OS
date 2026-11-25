alter table public.assessment_scores
  alter column score drop not null;

alter table public.assessment_scores
  drop constraint assessment_scores_score_valid,
  add constraint assessment_scores_score_valid
    check (score is null or score between 0 and 10),
  add constraint assessment_scores_attention_requires_score
    check (score is not null or not needs_attention);

create or replace function public.create_life_assessment(
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
            and score is not null
      ) or exists (
        select life_area_id, score::integer, needs_attention
          from public.assessment_scores
          where assessment_id = p_assessment_id and user_id = v_user_id
            and score is not null
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
         area.sort_order, input.score::smallint, coalesce(input.needs_attention, false)
    from public.life_areas as area
    left join jsonb_to_recordset(p_scores)
      as input(area_id uuid, score integer, needs_attention boolean)
      on input.area_id = area.id
    where area.user_id = v_user_id and area.archived_at is null;

  return p_assessment_id;
end;
$$;
