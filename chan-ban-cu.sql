-- ============================================================
-- GOODBIKE — CHẶN MÁY CHẠY BẢN APP CŨ GHI VÀO CLOUD
-- Chạy trong Supabase → SQL Editor → New query → Run
--
-- Vì sao cần: khoá ở phía trình duyệt chỉ có tác dụng với máy ĐÃ có code mới.
-- Một máy đang chạy bản cũ (tab mở từ hôm trước, PWA trên điện thoại chưa cập
-- nhật) không hề biết luật mới nên vẫn ghi đè theo kiểu cũ. Chốt chặn duy nhất
-- không thể lách được nằm ở database.
-- ============================================================

-- 1) Cột ghi rõ bản app nào đã ghi dòng này
alter table public.goodbike_items
  add column if not exists ban text;

-- 2) Bảng cấu hình: bản tối thiểu được phép ghi
create table if not exists public.goodbike_app (
  id             int primary key default 1,
  ban_toi_thieu  text not null,
  ghi_chu        text,
  constraint goodbike_app_chi_mot_dong check (id = 1)
);

insert into public.goodbike_app (id, ban_toi_thieu, ghi_chu)
values (1, '2026-08-12-a', 'Bản vá lỗi nút Hoàn tác làm booking quay về chưa trả')
on conflict (id) do update
  set ban_toi_thieu = excluded.ban_toi_thieu,
      ghi_chu       = excluded.ghi_chu;

-- 3) Chốt chặn: từ chối mọi lệnh ghi đến từ bản app cũ hơn mức tối thiểu
create or replace function public.gb_chan_ban_cu()
returns trigger
language plpgsql
security definer
as $$
declare
  toi_thieu text;
begin
  select ban_toi_thieu into toi_thieu from public.goodbike_app where id = 1;

  if toi_thieu is null then
    return new;                        -- chưa cấu hình -> không chặn ai
  end if;

  if new.ban is null or new.ban < toi_thieu then
    raise exception
      'GOODBIKE: may nay dang chay ban app % (toi thieu %). Hay tai lai trang de cap nhat.',
      coalesce(new.ban, '(khong ro)'), toi_thieu
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists gb_chan_ban_cu_trg on public.goodbike_items;

create trigger gb_chan_ban_cu_trg
  before insert or update on public.goodbike_items
  for each row execute function public.gb_chan_ban_cu();


-- ============================================================
-- CÁCH DÙNG VỀ SAU
-- ============================================================
-- Phát hành bản mới bình thường: KHÔNG cần đụng vào đây. Các máy cũ vẫn ghi
-- được cho tới khi bạn thực sự muốn ép nâng cấp.
--
-- Khi cần ép TẤT CẢ các máy lên bản mới (ví dụ vừa vá một lỗi làm hỏng dữ liệu):
--   update public.goodbike_app set ban_toi_thieu = '2026-09-01-a' where id = 1;
-- Từ giây đó, mọi máy chạy bản cũ hơn sẽ bị database từ chối ghi. Chúng vẫn
-- hiển thị và làm việc bình thường, dữ liệu giữ trong máy, app báo "chưa gửi
-- được" và bật màn hình bắt cập nhật. Không mất gì cả.
--
-- Xem máy nào đang chạy bản nào:
--   select ban, count(*), max(updated_at)
--   from public.goodbike_items
--   group by ban
--   order by max(updated_at) desc;
--
-- Gỡ chốt chặn nếu cần:
--   drop trigger if exists gb_chan_ban_cu_trg on public.goodbike_items;
-- ============================================================
