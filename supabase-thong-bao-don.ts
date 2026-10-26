// Edge Function "thong-bao-don" — GOODBIKE: thông báo đẩy về điện thoại nhân viên khi có booking mới nhận xe HÔM NAY.
// Không cần nhập khoá nào: lần chạy đầu tự tạo khoá VAPID và cất trong bảng goodbike_push_cfg (chỉ máy chủ đọc được).
// Gọi bởi: app nhân viên (lấy khoá công khai, đăng ký máy) và trigger goodbike_push_trg (booking mới).
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

// khoá máy chủ do Supabase tự cấp cho Edge Function (kiểu cũ SERVICE_ROLE hoặc kiểu mới SECRET_KEYS)
const SRV = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
  (() => { try { return String(Object.values(JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}"))[0] || ""); } catch (_) { return ""; } })();
const sb = createClient(Deno.env.get("SUPABASE_URL")!, SRV);
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const APP_URL = "https://longnhatharry07-lang.github.io/goodbike-web/";

// ngày hôm nay theo giờ Việt Nam (UTC+7)
const todayVN = () => new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10);

async function vapid(): Promise<{ publicKey: string; privateKey: string }> {
  const read = async () => (await sb.from("goodbike_push_cfg").select("v").eq("k", "vapid").maybeSingle()).data;
  let row = await read();
  if (!row) {
    const k = webpush.generateVAPIDKeys();
    await sb.from("goodbike_push_cfg").upsert({ k: "vapid", v: JSON.stringify(k) }, { onConflict: "k", ignoreDuplicates: true });
    row = await read();   // nếu 2 lượt chạy cùng lúc thì lấy khoá của lượt ghi trước
  }
  return JSON.parse(row!.v);
}

async function guiTatCa(payload: Record<string, unknown>) {
  const k = await vapid();
  const { data: subs } = await sb.from("goodbike_push_sub").select("endpoint, sub");
  let ok = 0, bo = 0;
  await Promise.all((subs || []).map(async (r) => {
    try {
      await webpush.sendNotification(r.sub, JSON.stringify(payload), {
        vapidDetails: { subject: APP_URL, publicKey: k.publicKey, privateKey: k.privateKey },
        TTL: 6 * 3600, urgency: "high",
      });
      ok++;
      await sb.from("goodbike_push_sub").update({ last_ok: new Date().toISOString() }).eq("endpoint", r.endpoint);
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) { bo++; await sb.from("goodbike_push_sub").delete().eq("endpoint", r.endpoint); }   // máy đã tắt thông báo / gỡ app
      else console.error("push loi", code, String(e));
    }
  }));
  return { ok, bo, tong: (subs || []).length };
}

// booking mới: chỉ báo khi tạo HÔM NAY, nhận xe HÔM NAY, chưa huỷ, và chưa báo lần nào
async function bookingMoi(id: string) {
  const { data: row } = await sb.from("goodbike_items").select("id, kind, data, deleted").eq("id", id).maybeSingle();
  if (!row || row.kind !== "bookings" || row.deleted) return { bo_qua: "khong phai booking" };
  const d = (row.data || {}) as Record<string, string>;
  const today = todayVN();
  if (d.arrive !== today) return { bo_qua: "khong nhan hom nay" };
  if (d.created && d.created !== today) return { bo_qua: "tao tu truoc" };
  if (d.status === "huy" || d.status === "datra") return { bo_qua: "huy/da tra" };
  if (/^DUMP/i.test(d.xe || "")) return { bo_qua: "dump" };
  const { error } = await sb.from("goodbike_push_sent").insert({ id });
  if (error) return { bo_qua: "da bao roi" };   // trùng khoá → đã gửi
  const gio = d.dplan || d.dtime || "";
  const ten = String(d.guest || "").split(" - ")[0].trim();
  const noi = /tự lấy|tai cua hang|tại cửa hàng/i.test(d.daddr || "") || !d.daddr ? "Khách lấy tại cửa hàng" : d.daddr;
  return await guiTatCa({
    title: "Đơn mới hôm nay · " + (d.xe || "") + (gio ? " · giao " + gio : ""),
    body: [ten, noi].filter(Boolean).join(" — "),
    tag: "gb-" + id,
    url: APP_URL + "nhanvien.html",
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  let b: Record<string, any> = {};
  try { b = await req.json(); } catch (_) { /* rỗng */ }
  try {
    if (b.action === "pub") return json({ key: (await vapid()).publicKey });
    if (b.action === "sub" && b.sub && b.sub.endpoint) {
      await sb.from("goodbike_push_sub").upsert({ endpoint: b.sub.endpoint, sub: b.sub, who: String(b.who || "").slice(0, 80) }, { onConflict: "endpoint" });
      return json({ ok: true });
    }
    if (b.action === "unsub" && b.endpoint) { await sb.from("goodbike_push_sub").delete().eq("endpoint", b.endpoint); return json({ ok: true }); }
    if (b.action === "test" && b.endpoint) {   // máy tự gửi thử cho chính nó
      const k = await vapid();
      const { data: r } = await sb.from("goodbike_push_sub").select("sub").eq("endpoint", b.endpoint).maybeSingle();
      if (!r) return json({ ok: false, loi: "chua dang ky" }, 404);
      await webpush.sendNotification(r.sub, JSON.stringify({ title: "GOODBIKE · Thử thông báo", body: "Điện thoại này đã nhận được thông báo đơn mới.", tag: "gb-test", url: APP_URL + "nhanvien.html" }),
        { vapidDetails: { subject: APP_URL, publicKey: k.publicKey, privateKey: k.privateKey }, TTL: 600, urgency: "high" });
      return json({ ok: true });
    }
    if (b.type === "INSERT" && b.record && b.record.id) return json(await bookingMoi(String(b.record.id)));
    return json({ ok: false, loi: "khong ro yeu cau" }, 400);
  } catch (e) {
    console.error(e);
    return json({ ok: false, loi: String(e) }, 500);
  }
});
