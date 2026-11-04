-- ============================================================
--  GOODBIKE — BẬT LỊCH SỬ THAO TÁC (chạy 1 lần)
--  Supabase → SQL Editor → New query → dán TOÀN BỘ file này → RUN.
--  Chạy lại lần nữa cũng không sao.
--
--  Sau khi chạy: MỌI lần thêm / sửa / xoá trên bảng goodbike_items
--  (từ bất kỳ máy nào, kể cả app nhân viên) đều được máy chủ tự ghi lại
--  bản TRƯỚC và SAU vào bảng goodbike_history. Nút "🕘 Lịch sử" trên web
--  đọc bảng này để xem lại và khôi phục phiên bản cũ.
--  Lịch sử tự dọn sau 180 ngày.
-- ============================================================

create table if not exists public.goodbike_history (
  hid       bigserial primary key,
  at        timestamptz not null default now(),
  item_id   text not null,
  kind      text,
  hanh_dong text not null,          -- them | sua | xoa | khoiphuc
  data_cu   jsonb,                  -- bản TRƯỚC thao tác
  data_moi  jsonb,                  -- bản SAU thao tác
  ban       text                    -- bản app đã ghi
);
create index if not exists goodbike_history_at_idx   on public.goodbike_history (at desc);
create index if not exists goodbike_history_item_idx on public.goodbike_history (item_id, at desc);
create index if not exists goodbike_history_kind_idx on public.goodbike_history (kind, at desc);

create or replace function public.gb_ghi_lich_su()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare hd text;
begin
  if tg_op = 'INSERT' then
    hd := case when new.deleted then 'xoa' else 'them' end;
    insert into public.goodbike_history(item_id, kind, hanh_dong, data_cu, data_moi, ban)
    values (new.id, new.kind, hd, null, new.data, new.ban);
  else
    if old.data is not distinct from new.data and old.deleted = new.deleted then
      return null;                                   -- không đổi gì thì không ghi
    end if;
    hd := case
            when new.deleted and not old.deleted then 'xoa'
            when old.deleted and not new.deleted then 'khoiphuc'
            when new.deleted then 'xoa'
            else 'sua'
          end;
    insert into public.goodbike_history(item_id, kind, hanh_dong, data_cu, data_moi, ban)
    values (new.id, new.kind, hd, old.data, new.data, new.ban);
  end if;

  if random() < 0.002 then
    delete from public.goodbike_history where at < now() - interval '180 days';
  end if;
  return null;
end $$;

drop trigger if exists goodbike_items_lich_su on public.goodbike_items;
create trigger goodbike_items_lich_su
  after insert or update on public.goodbike_items
  for each row execute function public.gb_ghi_lich_su();

-- App chỉ được ĐỌC lịch sử. Không ai sửa/xoá được lịch sử từ trình duyệt;
-- chỉ trigger phía máy chủ mới ghi vào.
alter table public.goodbike_history enable row level security;
drop policy if exists goodbike_history_doc on public.goodbike_history;
create policy goodbike_history_doc on public.goodbike_history
  for select using (true);
grant select on public.goodbike_history to anon, authenticated;
