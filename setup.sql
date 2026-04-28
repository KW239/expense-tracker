-- ============================================================
-- Expense Tracker — Supabase schema
-- Run this once in the Supabase SQL Editor for your project.
-- ============================================================

-- ── Profiles ──────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  updated_at  timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can manage own profile"
  on public.profiles for all
  using  (auth.uid() = id)
  with check (auth.uid() = id);

-- ── Expenses ──────────────────────────────────────────────
create table if not exists public.expenses (
  id             text primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  tab            text not null check (tab in ('business', 'personal')),
  date           date not null,
  amount         numeric(12, 2) not null,
  currency       text not null default 'EUR',
  purpose        text not null,
  type           text not null,
  status         text not null check (status in ('reserved', 'open')),
  expensed       boolean not null default false,
  expensed_where text,
  expensed_when  date,
  created_at     timestamptz default now()
);

alter table public.expenses enable row level security;

create policy "Users can manage own expenses"
  on public.expenses for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── Auto-create profile on signup ─────────────────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
