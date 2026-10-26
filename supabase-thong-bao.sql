-- ============================================================
--  GOODBIKE — Thông báo đẩy "đơn mới hôm nay" về app nhân viên
--  Chạy MỘT LẦN trong Supabase > SQL Editor, SAU KHI đã tạo Edge Function "thong-bao-don".
--  Chạy lại cũng không sao.
-- ============================================================

-- 1. Các bảng chỉ máy chủ (Edge Function) đọc/ghi — bật RLS và KHÔNG tạo policy nào → app/khách không đọc được
create table if not exists public.goodbike_push_sub (
  endpoint   text primary key,
  sub        jsonb not null,
  who        text,
  created_at timestamptz not null default now(),
  last_ok    timestamptz
);
create table if not exists public.goodbike_push_cfg  (k text primary key, v text not null);
create table if not exists public.goodbike_push_sent (id text primary key, at timestamptz not null default now());
alter table public.goodbike_push_sub  enable row level security;
alter table public.goodbike_push_cfg  enable row level security;
alter table public.goodbike_push_sent enable row level security;

-- 2. Booking mới → gọi Edge Function (chỉ gửi id; hàm tự đọc lại booking và kiểm tra có phải nhận hôm nay không)
create extension if not exists pg_net with schema extensions;
create or replace function public.goodbike_push_new() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.kind = 'bookings' and coalesce(new.deleted, false) = false then
    perform net.http_post(
      url     := 'https://ewkivaybedatwtfpqado.supabase.co/functions/v1/thong-bao-don',
      body    := jsonb_build_object('type', 'INSERT', 'record', jsonb_build_object('id', new.id)),
      headers := '{"Content-Type":"application/json"}'::jsonb
    );
  end if;
  return new;
end $$;

drop trigger if exists goodbike_push_trg on public.goodbike_items;
create trigger goodbike_push_trg
  after insert on public.goodbike_items
  for each row execute function public.goodbike_push_new();
