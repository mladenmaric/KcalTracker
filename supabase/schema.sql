-- ============================================================
-- KcalTracker — Supabase Schema
-- Run this entire file once on a fresh Supabase project via:
--   Dashboard → SQL Editor → New query → paste → Run
-- ============================================================


-- ── 1. Profiles ──────────────────────────────────────────────
-- Extends auth.users with display name and role.
-- Auto-populated via trigger on sign-up.

create table if not exists public.profiles (
  id            uuid        references auth.users(id) on delete cascade primary key,
  display_name  text        not null,
  role          text        not null default 'user'
                            check (role in ('user', 'trainer', 'admin')),
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any authenticated user can read any profile (needed for trainer/admin views).
create policy "Authenticated users can view profiles"
  on public.profiles for select
  using (auth.role() = 'authenticated');

-- Users can update their own profile.
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);


-- ── 2. Trigger: auto-create profile on sign-up ───────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ── 3. Trainer ↔ User assignments ────────────────────────────
-- Any user can be assigned a trainer regardless of their role.

create table if not exists public.trainer_assignments (
  trainer_id   uuid        references public.profiles(id) on delete cascade,
  user_id      uuid        references public.profiles(id) on delete cascade,
  assigned_at  timestamptz not null default now(),
  primary key (trainer_id, user_id)
);

alter table public.trainer_assignments enable row level security;

-- Trainers see their own assignments; users see who their trainer is.
create policy "Principals can view their assignments"
  on public.trainer_assignments for select
  using (auth.uid() = trainer_id or auth.uid() = user_id);

-- Admins manage assignments via security-definer RPCs (see section 5).
-- This broad policy lets the RPCs write; UI restricts to admins only.
create policy "Authenticated users can manage assignments"
  on public.trainer_assignments for all
  using (auth.role() = 'authenticated');


-- ── 4. Admin helpers ─────────────────────────────────────────

-- is_admin(): security-definer so it bypasses RLS on profiles.
create or replace function public.is_admin()
returns boolean
language sql
security definer stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Admins can update any profile (e.g. change role).
create policy "Admins can update any profile"
  on public.profiles for update
  using (public.is_admin());

-- Admins can view all trainer assignments.
create policy "Admins view all assignments"
  on public.trainer_assignments for select
  using (public.is_admin());

-- Change any user's role.
create or replace function public.admin_set_role(target_user_id uuid, new_role text)
returns void
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then raise exception 'Unauthorized'; end if;
  if new_role not in ('user', 'trainer', 'admin') then
    raise exception 'Invalid role: %', new_role;
  end if;
  update public.profiles set role = new_role where id = target_user_id;
end;
$$;

-- Link a trainer to a user.
create or replace function public.admin_assign_trainer(p_trainer_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then raise exception 'Unauthorized'; end if;
  insert into public.trainer_assignments (trainer_id, user_id)
  values (p_trainer_id, p_user_id)
  on conflict do nothing;
end;
$$;

-- Unlink a trainer from a user.
create or replace function public.admin_remove_trainer(p_trainer_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then raise exception 'Unauthorized'; end if;
  delete from public.trainer_assignments
  where trainer_id = p_trainer_id and user_id = p_user_id;
end;
$$;


-- ── 5. Meals ─────────────────────────────────────────────────

create table if not exists public.meals (
  id         bigserial   primary key,
  user_id    uuid        not null references public.profiles(id) on delete cascade,
  name       text        not null,
  date       timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.meals enable row level security;

create policy "Users manage own meals"
  on public.meals for all
  using (auth.uid() = user_id);

create policy "Trainers view assigned users meals"
  on public.meals for select
  using (exists (
    select 1 from public.trainer_assignments ta
    where ta.trainer_id = auth.uid() and ta.user_id = meals.user_id
  ));


-- ── 6. Food items ─────────────────────────────────────────────

create table if not exists public.food_items (
  id                 bigserial primary key,
  meal_id            bigint    not null references public.meals(id) on delete cascade,
  food_definition_id integer,          -- local SQLite reference (nullable)
  name               text      not null,
  grams              float8    not null,
  calories           float8    not null,
  protein            float8    not null,
  carbs              float8    not null,
  fat                float8    not null
);

alter table public.food_items enable row level security;

create policy "Users manage own food items"
  on public.food_items for all
  using (exists (
    select 1 from public.meals m
    where m.id = food_items.meal_id and m.user_id = auth.uid()
  ));

create policy "Trainers view food items of assigned users"
  on public.food_items for select
  using (exists (
    select 1 from public.meals m
    join public.trainer_assignments ta on ta.user_id = m.user_id
    where m.id = food_items.meal_id and ta.trainer_id = auth.uid()
  ));


-- ── 7. Meal comments (trainer → user, per meal) ───────────────

create table if not exists public.meal_comments (
  id          bigserial   primary key,
  meal_id     bigint      not null references public.meals(id) on delete cascade,
  trainer_id  uuid        not null references public.profiles(id) on delete cascade,
  body        text        not null,
  created_at  timestamptz not null default now(),
  unique (meal_id, trainer_id)
);

alter table public.meal_comments enable row level security;

-- Athlete sees comments on their own meals; trainer sees comments they wrote.
create policy "Users and trainers can view meal comments"
  on public.meal_comments for select
  using (
    auth.uid() = trainer_id
    or exists (
      select 1 from public.meals m
      where m.id = meal_comments.meal_id and m.user_id = auth.uid()
    )
  );

create policy "Trainers can insert comments"
  on public.meal_comments for insert
  with check (auth.uid() = trainer_id);

create policy "Trainers can update their own comments"
  on public.meal_comments for update
  using (auth.uid() = trainer_id);

create policy "Trainers can delete their own comments"
  on public.meal_comments for delete
  using (auth.uid() = trainer_id);


-- ── 8. Weight entries ─────────────────────────────────────────

create table if not exists public.weight_entries (
  id         bigserial   primary key,
  user_id    uuid        not null references public.profiles(id) on delete cascade,
  weight_kg  float8      not null,
  date       timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.weight_entries enable row level security;

create policy "Users manage own weight"
  on public.weight_entries for all
  using (auth.uid() = user_id);

create policy "Trainers view assigned users weight"
  on public.weight_entries for select
  using (exists (
    select 1 from public.trainer_assignments ta
    where ta.trainer_id = auth.uid() and ta.user_id = weight_entries.user_id
  ));


-- ── 9. Sleep entries ──────────────────────────────────────────

create table if not exists public.sleep_entries (
  id         bigserial   primary key,
  user_id    uuid        not null references public.profiles(id) on delete cascade,
  date       date        not null,
  sleep_time text,
  wake_time  text,
  created_at timestamptz not null default now(),
  unique (user_id, date)
);

alter table public.sleep_entries enable row level security;

create policy "Users manage own sleep"
  on public.sleep_entries for all
  using (auth.uid() = user_id);

create policy "Trainers view assigned users sleep"
  on public.sleep_entries for select
  using (exists (
    select 1 from public.trainer_assignments ta
    where ta.trainer_id = auth.uid() and ta.user_id = sleep_entries.user_id
  ));


-- ── 10. Training entries ──────────────────────────────────────

create table if not exists public.training_entries (
  id               bigserial   primary key,
  user_id          uuid        not null references public.profiles(id) on delete cascade,
  type             text        not null,
  duration_minutes integer     not null,
  date             timestamptz not null,
  notes            text,
  created_at       timestamptz not null default now()
);

alter table public.training_entries enable row level security;

create policy "Users manage own training"
  on public.training_entries for all
  using (auth.uid() = user_id);

create policy "Trainers view assigned users training"
  on public.training_entries for select
  using (exists (
    select 1 from public.trainer_assignments ta
    where ta.trainer_id = auth.uid() and ta.user_id = training_entries.user_id
  ));


-- ── 11. Goals (one row per user, upserted on save) ────────────

create table if not exists public.goals (
  user_id     uuid   primary key references public.profiles(id) on delete cascade,
  daily_kcal  float8 not null default 2000,
  protein_pct float8 not null default 40,
  carbs_pct   float8 not null default 30,
  fat_pct     float8 not null default 30
);

alter table public.goals enable row level security;

create policy "Users manage own goals"
  on public.goals for all
  using (auth.uid() = user_id);

create policy "Trainers view assigned users goals"
  on public.goals for select
  using (exists (
    select 1 from public.trainer_assignments ta
    where ta.trainer_id = auth.uid() and ta.user_id = goals.user_id
  ));


-- ── 12. Realtime ─────────────────────────────────────────────
-- Enable Realtime on tables that need live sync in the app.
-- meals + food_items: trainer view refreshes when athlete logs data.
-- meal_comments: athlete home screen updates when trainer adds/edits/deletes a comment.

alter publication supabase_realtime add table public.meals;
alter publication supabase_realtime add table public.food_items;
alter publication supabase_realtime add table public.meal_comments;


-- ── Post-setup: manually set the first admin ─────────────────
-- After running this file, set your own account as admin via:
--   Dashboard → Table Editor → profiles → edit your row → set role = 'admin'
