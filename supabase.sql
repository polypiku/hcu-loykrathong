-- ลอยกระทง HCU: วางทั้งไฟล์นี้ใน Supabase > SQL Editor แล้วกด Run ครั้งเดียว

create table if not exists public.krathongs (
  id uuid primary key default gen_random_uuid(),
  day text not null,
  name text not null check (char_length(name) between 1 and 20),
  krathong_type text not null check (krathong_type ~ '^[a-z]{2,16}$'),
  message text not null check (char_length(message) between 1 and 50),
  likes integer not null default 0,
  created_at bigint not null
);

-- อัปเดตจากเวอร์ชันเก่า: เปิดให้รับกระทงได้ทุกแบบ (20 แบบขึ้นไป)
alter table public.krathongs drop constraint if exists krathongs_krathong_type_check;
alter table public.krathongs add constraint krathongs_krathong_type_check check (krathong_type ~ '^[a-z]{2,16}$');

create index if not exists krathongs_day_created on public.krathongs (day, created_at desc);
create index if not exists krathongs_day_likes on public.krathongs (day, likes desc);

-- ให้หน้าเว็บ (anon) อ่านและเพิ่มกระทงได้ (เผื่อปิด Grant API access อัตโนมัติไว้)
grant select, insert on public.krathongs to anon, authenticated;

-- ทุกคนอ่านได้ เพิ่มกระทงใหม่ได้ (เริ่มที่ 0 กำลังใจ) แต่แก้หรือลบเองไม่ได้
alter table public.krathongs enable row level security;

drop policy if exists "krathongs read" on public.krathongs;
create policy "krathongs read" on public.krathongs for select using (true);

drop policy if exists "krathongs insert" on public.krathongs;
create policy "krathongs insert" on public.krathongs for insert with check (likes = 0);

-- ส่งกำลังใจได้ทีละ +1 ผ่านฟังก์ชันนี้เท่านั้น
create or replace function public.like_krathong(kid uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.krathongs set likes = likes + 1 where id = kid;
$$;

grant execute on function public.like_krathong(uuid) to anon, authenticated;

-- เปิดการแจ้งเตือนแบบเรียลไทม์เมื่อมีกระทงใหม่หรือมีคนส่งกำลังใจ
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'krathongs'
  ) then
    alter publication supabase_realtime add table public.krathongs;
  end if;
end $$;
