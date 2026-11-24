begin;

select plan(12);

-- Minimal deterministic identities for exercising auth.uid() and the FK.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', '', now(), now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'other@example.test', '', now(), now(), now())
on conflict (id) do nothing;

insert into public.tasks (id, user_id, title)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'Task owned by user one');

set local role anon;
select throws_ok(
  $$select * from public.tasks$$,
  '42501', null, 'anonymous users have no privilege to read tasks'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
set local role authenticated;
select is((select count(*) from public.tasks), 1::bigint, 'owner can read their task');
select lives_ok(
  $$insert into public.tasks (id, user_id, title) values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', auth.uid(), 'Created by owner')$$,
  'owner can insert a task for themselves'
);
select lives_ok(
  $$update public.tasks set title = 'Updated by owner' where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
  'owner can update their task'
);
select throws_ok(
  $$insert into public.tasks (id, user_id, title) values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '22222222-2222-4222-8222-222222222222', 'Forged owner')$$,
  '42501', null, 'owner cannot forge another user on insert'
);
select throws_ok(
  $$insert into public.tasks (id, user_id, title) values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', auth.uid(), '   ')$$,
  '23514', null, 'blank titles are rejected by the database'
);
select throws_ok(
  $$insert into public.tasks (id, user_id, title) values ('ffffffff-ffff-4fff-8fff-ffffffffffff', auth.uid(), E' \t\n')$$,
  '23514', null, 'whitespace-only titles are rejected by the database'
);
select throws_ok(
  $$insert into public.tasks (id, user_id, title) values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', auth.uid(), repeat('x', 201))$$,
  '23514', null, 'titles longer than 200 characters are rejected'
);
select lives_ok(
  $$insert into public.tasks (id, user_id, title) values ('abababab-abab-4bab-8bab-abababababab', auth.uid(), repeat('💪', 100))$$,
  'unicode title length follows the database character limit'
);
reset role;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
set local role authenticated;
select is((select count(*) from public.tasks), 0::bigint, 'another user cannot read the owner task');
select lives_ok(
  $$update public.tasks set title = 'Tampered' where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
  'another user update request does not error'
);
reset role;
select is(
  (select title from public.tasks where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'Updated by owner', 'another user update did not change the task'
);

select * from finish();
rollback;
