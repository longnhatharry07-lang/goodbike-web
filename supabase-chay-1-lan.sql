-- ============================================================
--  GOODBIKE — chạy ĐÚNG MỘT LẦN trong Supabase
--  Vào supabase.com > dự án của bạn > SQL Editor > New query
--  Dán TOÀN BỘ nội dung file này vào rồi bấm RUN.
--  Chạy lại lần nữa cũng không sao, không hỏng gì.
-- ============================================================

-- 1. Bảng mới: mỗi booking / khoản thu chi / tài sản là MỘT DÒNG riêng
create table if not exists public.goodbike_items (
  id         text primary key,
  kind       text not null,
  data       jsonb,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists goodbike_items_updated_at_idx on public.goodbike_items (updated_at);
create index if not exists goodbike_items_kind_idx       on public.goodbike_items (kind);

-- 2. Giờ sửa do MÁY CHỦ ghi, không phụ thuộc đồng hồ từng máy
create or replace function public.goodbike_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists goodbike_items_touch on public.goodbike_items;
create trigger goodbike_items_touch
  before insert or update on public.goodbike_items
  for each row execute function public.goodbike_touch();

-- 3. Cho phép app đọc/ghi (giống hệt quyền của bảng cũ)
alter table public.goodbike_items enable row level security;
drop policy if exists goodbike_items_all on public.goodbike_items;
create policy goodbike_items_all on public.goodbike_items
  for all using (true) with check (true);

-- 4. Bật cập nhật tức thời giữa các máy
do $$
begin
  alter publication supabase_realtime add table public.goodbike_items;
exception when duplicate_object then null;
end $$;

-- Xong. Bảng cũ goodbike_state được giữ nguyên làm bản lưu phòng hờ,
-- app sẽ tự chuyển dữ liệu từ đó sang bảng mới trong lần mở đầu tiên.
