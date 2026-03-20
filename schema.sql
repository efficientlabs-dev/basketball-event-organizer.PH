-- Basketball Sessions Schema
-- Run this in Supabase SQL Editor

-- Sessions table
create table if not exists sessions (
  id uuid default gen_random_uuid() primary key,
  date date not null,
  time_slot text not null,
  duration text default '2 hours',
  venue text not null,
  max_players integer default 20,
  status text default 'open' check (status in ('open', 'closed', 'completed')),
  created_at timestamp with time zone default now()
);

-- Signups table
create table if not exists signups (
  id uuid default gen_random_uuid() primary key,
  session_id uuid references sessions(id) on delete cascade,
  name text not null,
  plus_ones integer default 0,
  paid boolean default false,
  pay_later boolean default false,
  proof_url text,
  is_organizer boolean default false,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table sessions enable row level security;
alter table signups enable row level security;

-- Sessions policies: anyone can read, anyone can insert/update (admin managed via app-level PIN)
create policy "Anyone can read sessions" on sessions for select using (true);
create policy "Anyone can insert sessions" on sessions for insert with check (true);
create policy "Anyone can update sessions" on sessions for update using (true);

-- Signups policies: anyone can read, anyone can insert, anyone can update/delete (admin managed via app-level PIN)
create policy "Anyone can read signups" on signups for select using (true);
create policy "Anyone can insert signups" on signups for insert with check (true);
create policy "Anyone can update signups" on signups for update using (true);
create policy "Anyone can delete signups" on signups for delete using (true);

-- Create storage bucket for payment proofs
insert into storage.buckets (id, name, public) values ('proofs', 'proofs', true)
on conflict (id) do nothing;

-- Storage policy: anyone can upload to proofs bucket
create policy "Anyone can upload proofs" on storage.objects for insert with check (bucket_id = 'proofs');
create policy "Anyone can read proofs" on storage.objects for select using (bucket_id = 'proofs');
