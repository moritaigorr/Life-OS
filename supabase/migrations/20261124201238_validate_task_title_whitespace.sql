alter table public.tasks
  drop constraint tasks_title_valid;

alter table public.tasks
  add constraint tasks_title_valid check (
    title = btrim(title, E' \t\n\r\f\v')
    and title ~ '[^[:space:]]'
    and char_length(title) between 1 and 200
  );
