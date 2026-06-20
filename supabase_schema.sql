-- ===== VIVÊNCIA — schéma de base =====

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  role text not null default 'traveler' check (role in ('traveler','host','admin')),
  host_status text check (host_status in ('pending','verified','rejected')),
  business text, base text, about text, languages text, category text, years text,
  created_at timestamptz not null default now()
);

create table if not exists public.host_verification (
  id uuid primary key references public.profiles(id) on delete cascade,
  nif text, phone text, docs jsonb, submitted_at timestamptz default now()
);

create table if not exists public.experiences (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  host_name text not null default '',
  title text not null, category text not null, region text not null, location text,
  price numeric not null default 0, duration_hrs numeric not null default 0, group_max int not null default 1,
  summary text, descr text[] not null default '{}', inc text[] not null default '{}',
  img text, gallery text[] not null default '{}',
  rating numeric not null default 0, reviews int not null default 0,
  status text not null default 'pending' check (status in ('pending','live','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  exp_id uuid references public.experiences(id) on delete set null,
  exp_title text,
  host_id uuid references public.profiles(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  customer_name text, customer_email text,
  date date, guests int,
  subtotal numeric, commission numeric, payout numeric,
  status text not null default 'confirmed',
  created_at timestamptz not null default now()
);

-- crée automatiquement le profil à l'inscription
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name',''))
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- empêche quelqu'un de se promouvoir admin ou de s'auto-vérifier
create or replace function public.guard_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if new.role = 'admin' and old.role <> 'admin' then new.role := old.role; end if;
    if new.host_status = 'verified' and old.host_status is distinct from 'verified' then
      new.host_status := old.host_status;
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists guard_profile_trg on public.profiles;
create trigger guard_profile_trg before update on public.profiles
for each row execute function public.guard_profile();

-- sécurité (RLS)
alter table public.profiles enable row level security;
alter table public.host_verification enable row level security;
alter table public.experiences enable row level security;
alter table public.bookings enable row level security;

drop policy if exists p_sel on public.profiles;
create policy p_sel on public.profiles for select using (true);
drop policy if exists p_ins on public.profiles;
create policy p_ins on public.profiles for insert with check (auth.uid() = id);
drop policy if exists p_upd on public.profiles;
create policy p_upd on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists hv_sel on public.host_verification;
create policy hv_sel on public.host_verification for select using (auth.uid() = id or public.is_admin());
drop policy if exists hv_ins on public.host_verification;
create policy hv_ins on public.host_verification for insert with check (auth.uid() = id);
drop policy if exists hv_upd on public.host_verification;
create policy hv_upd on public.host_verification for update using (auth.uid() = id);

drop policy if exists e_sel on public.experiences;
create policy e_sel on public.experiences for select using (status = 'live' or host_id = auth.uid() or public.is_admin());
drop policy if exists e_ins on public.experiences;
create policy e_ins on public.experiences for insert with check (host_id = auth.uid());
drop policy if exists e_upd on public.experiences;
create policy e_upd on public.experiences for update using (host_id = auth.uid() or public.is_admin());

drop policy if exists b_ins on public.bookings;
create policy b_ins on public.bookings for insert with check (true);
drop policy if exists b_sel on public.bookings;
create policy b_sel on public.bookings for select using (user_id = auth.uid() or host_id = auth.uid() or public.is_admin());
