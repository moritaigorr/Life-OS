begin;
select plan(31);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', '', now(), now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'other@example.test', '', now(), now(), now())
on conflict (id) do nothing;

insert into public.life_areas (id, user_id, name, sort_order)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'Área do usuário A', 0),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'Área do usuário B', 0)
on conflict (id) do nothing;

insert into public.assessments (id, user_id, assessed_on, comment)
values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '11111111-1111-4111-8111-111111111111', current_date, 'Registro privado')
on conflict (id) do nothing;

insert into public.assessment_scores (
  user_id, assessment_id, life_area_id, area_name_snapshot,
  area_sort_order_snapshot, score, needs_attention
)
values (
  '11111111-1111-4111-8111-111111111111',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Área do usuário A', 0, 6, true
)
on conflict do nothing;

insert into public.life_goals (
  id, user_id, kind, year, quarter, title, success_criteria, progress, life_area_id
)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111',
  'annual', 2026, null, 'Objetivo anual', 'Concluir o resultado definido', 20,
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
)
on conflict (id) do nothing;

insert into public.life_onboarding (user_id, status, current_step, life_vision)
values ('11111111-1111-4111-8111-111111111111', 'completed', 1, 'Visão do usuário A')
on conflict (user_id) do nothing;

set local role anon;
select throws_ok($$select * from public.life_areas$$, '42501', null, 'anonymous cannot read life areas');
select throws_ok($$select * from public.assessments$$, '42501', null, 'anonymous cannot read assessments');
select throws_ok($$select * from public.life_goals$$, '42501', null, 'anonymous cannot read life goals');
select throws_ok($$select * from public.life_onboarding$$, '42501', null, 'anonymous cannot read onboarding');
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
set local role authenticated;
select is((select count(*) from public.life_areas), 1::bigint, 'owner reads their life area only');
select is((select count(*) from public.assessments), 1::bigint, 'owner reads their assessment only');
select is((select count(*) from public.assessment_scores), 1::bigint, 'owner reads their score only');
select is((select count(*) from public.life_goals), 1::bigint, 'owner reads their life goal only');
select is((select count(*) from public.life_onboarding), 1::bigint, 'owner reads their onboarding only');
select lives_ok(
  $$update public.life_goals set progress = 35 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  'owner can update their own goal'
);
select throws_ok(
  $$update public.life_goals set user_id = '22222222-2222-4222-8222-222222222222' where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  '42501', null, 'owner cannot transfer a goal to another account'
);
select lives_ok(
  $$insert into public.life_goals (kind, year, title, success_criteria) values ('quarterly', 2026, 'Foco do trimestre', 'Entregar um marco')$$,
  'owner can create a goal for themselves'
);
select throws_ok(
  $$insert into public.life_goals (user_id, kind, year, title, success_criteria) values ('22222222-2222-4222-8222-222222222222', 'annual', 2026, 'Forged', 'Forged')$$,
  '42501', null, 'owner cannot assign a goal to another account'
);
select lives_ok(
  $$update public.life_onboarding set life_vision = 'Visão atualizada' where user_id = auth.uid()$$,
  'owner can update their onboarding'
);
select lives_ok(
  $$insert into public.life_goals (kind, year, quarter, parent_goal_id, title, success_criteria) values ('quarterly', 2026, 2, 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Meta ligada', 'Concluir o marco')$$,
  'quarterly goal can link to its own annual goal'
);
select throws_ok(
  $$insert into public.life_goals (kind, year, quarter, parent_goal_id, title, success_criteria) values ('quarterly', 2027, 1, 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Ano divergente', 'Concluir o marco')$$,
  '23514', null, 'quarterly goal cannot link to an annual goal from another year'
);
select throws_ok(
  $$insert into public.life_goals (kind, year, quarter, title, success_criteria) values ('quarterly', 2026, 5, 'Trimestre inválido', 'Concluir o marco')$$,
  '23514', null, 'quarter must be between one and four'
);
select lives_ok(
  $$select public.update_life_assessment('cccccccc-cccc-4ccc-8ccc-cccccccccccc', current_date, 'Avaliação atualizada', '[{"area_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","score":7,"needs_attention":false}]'::jsonb)$$,
  'owner can edit their active assessment'
);
select lives_ok(
  $$select public.set_life_assessment_archived('cccccccc-cccc-4ccc-8ccc-cccccccccccc', true)$$,
  'owner can archive their assessment'
);
select is(
  (select count(*) from public.assessments where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' and archived_at is not null),
  1::bigint,
  'archiving assessment preserves the history row'
);
select lives_ok(
  $$select public.set_life_assessment_archived('cccccccc-cccc-4ccc-8ccc-cccccccccccc', false)$$,
  'owner can restore their archived assessment'
);
reset role;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
set local role authenticated;
select is((select count(*) from public.life_areas), 1::bigint, 'other account sees only its own area');
select is((select count(*) from public.assessments), 0::bigint, 'other account cannot read the assessment');
select is((select count(*) from public.assessment_scores), 0::bigint, 'other account cannot read assessment scores');
select is((select count(*) from public.life_goals), 0::bigint, 'other account cannot read the goal');
select is((select count(*) from public.life_onboarding), 0::bigint, 'other account cannot read onboarding');
select lives_ok(
  $$update public.life_goals set title = 'Tampered' where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$$,
  'other account update request is safely filtered'
);
select throws_ok(
  $$insert into public.life_goals (kind, year, life_area_id, title, success_criteria) values ('annual', 2026, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Cross account area', 'Must be isolated')$$,
  '23503', null, 'other account cannot attach a goal to another account area'
);
select throws_ok(
  $$select public.update_life_assessment('cccccccc-cccc-4ccc-8ccc-cccccccccccc', current_date, 'Tampered', '[{"area_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","score":9,"needs_attention":false}]'::jsonb)$$,
  '42501', null, 'other account cannot edit the owner assessment'
);
reset role;

select is(
  (select progress from public.life_goals where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  35::smallint,
  'cross-account update did not change the owner goal'
);
select is(
  (select life_vision from public.life_onboarding where user_id = '11111111-1111-4111-8111-111111111111'),
  'Visão atualizada',
  'other account cannot change the owner onboarding'
);

select * from finish();
rollback;
