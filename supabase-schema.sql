-- ============================================================
-- SheVada Solutions Client Portal — Supabase Schema
-- Run this in your Supabase SQL Editor
-- ============================================================

-- PROFILES TABLE
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text,
  organization text,
  title text,
  phone text,
  email text,
  role text default 'client',
  package text default 'Operational Assessment',
  welcome_note text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- DOCUMENTS TABLE
create table if not exists public.documents (
  id uuid default gen_random_uuid() primary key,
  client_id uuid references public.profiles on delete cascade,
  name text not null,
  storage_path text not null,
  size bigint,
  type text,
  uploaded_by uuid references public.profiles,
  created_at timestamp with time zone default now()
);

-- MESSAGES TABLE
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  client_id uuid references public.profiles on delete cascade,
  sender_id uuid references public.profiles,
  body text not null,
  read boolean default false,
  created_at timestamp with time zone default now()
);

-- INVOICES TABLE
create table if not exists public.invoices (
  id uuid default gen_random_uuid() primary key,
  client_id uuid references public.profiles on delete cascade,
  invoice_number text,
  description text,
  amount numeric(10,2),
  status text default 'unpaid',
  due_date date,
  payment_link text,
  paid_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.documents enable row level security;
alter table public.messages enable row level security;
alter table public.invoices enable row level security;

-- PROFILES: users can read/update their own profile; admins can read all
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "Admins can view all profiles" on public.profiles
  for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can update all profiles" on public.profiles
  for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can insert profiles" on public.profiles
  for insert with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- DOCUMENTS: clients see their own; admins see all
create policy "Clients view own documents" on public.documents
  for select using (client_id = auth.uid());

create policy "Clients insert own documents" on public.documents
  for insert with check (client_id = auth.uid());

create policy "Clients delete own documents" on public.documents
  for delete using (client_id = auth.uid());

create policy "Admins full access to documents" on public.documents
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- MESSAGES: clients see their thread; admins see all
create policy "Clients view own messages" on public.messages
  for select using (client_id = auth.uid());

create policy "Clients insert messages" on public.messages
  for insert with check (client_id = auth.uid() and sender_id = auth.uid());

create policy "Admins full access to messages" on public.messages
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- INVOICES: clients see their own; admins full access
create policy "Clients view own invoices" on public.invoices
  for select using (client_id = auth.uid());

create policy "Admins full access to invoices" on public.invoices
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- STORAGE BUCKET
-- ============================================================
-- Run this separately in Storage settings or via the dashboard:
-- Create a bucket called: client-documents
-- Set to private (not public)
-- Enable RLS on the bucket

-- ============================================================
-- CREATE YOUR ADMIN ACCOUNT
-- ============================================================
-- After running this schema:
-- 1. Sign up at your portal with info@shevada-solutions.com
-- 2. Run this SQL to make yourself admin:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'info@shevada-solutions.com';
-- ============================================================
