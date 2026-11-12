#!/bin/sh
# Tạo 2 app nhân viên từ index.html. CHẠY LẠI MỖI LẦN SỬA index.html rồi upload cả 3 file html.
#  · nhanvien.html  = Kim Mã     (mũ ĐỎ,  manifest-nv.json)
#  · nhanvien2.html = Chi nhánh 2 (mũ XANH, manifest-nv2.json)
# Chỉ đổi phần đầu: manifest riêng, icon, tên app. Phần còn lại giống hệt index.html (chi nhánh nhận theo tên file).
sed -e 's#<link rel="manifest" href="manifest.json">#<link rel="manifest" href="manifest-nv.json">#' \
    -e 's#<title>GOODBIKE — Quản lý xe \& doanh thu</title>#<title>GOODBIKE — Lịch trình nhân viên</title>#' \
    -e 's#<meta name="apple-mobile-web-app-title" content="GOODBIKE">#<meta name="apple-mobile-web-app-title" content="GB Lịch trình">#' \
    -e 's#<meta name="theme-color" content="\#F58B41">#<meta name="theme-color" content="\#D92D20">#' \
    -e 's#<link rel="apple-touch-icon" href="apple-touch-icon-v3.png">#<link rel="apple-touch-icon" href="apple-touch-icon-nv.png">#' \
    -e 's#<link rel="icon" type="image/png" href="favicon-v3.png">#<link rel="icon" type="image/png" href="favicon-nv.png">#' \
    index.html > nhanvien.html
sed -e 's#<link rel="manifest" href="manifest.json">#<link rel="manifest" href="manifest-nv2.json">#' \
    -e 's#<title>GOODBIKE — Quản lý xe \& doanh thu</title>#<title>GOODBIKE CN2 — Lịch trình nhân viên</title>#' \
    -e 's#<meta name="apple-mobile-web-app-title" content="GOODBIKE">#<meta name="apple-mobile-web-app-title" content="GB CN2 Lịch trình">#' \
    -e 's#<meta name="theme-color" content="\#F58B41">#<meta name="theme-color" content="\#00D0D4">#' \
    -e 's#<link rel="apple-touch-icon" href="apple-touch-icon-v3.png">#<link rel="apple-touch-icon" href="apple-touch-icon-nv2.png">#' \
    -e 's#<link rel="icon" type="image/png" href="favicon-v3.png">#<link rel="icon" type="image/png" href="favicon-nv2.png">#' \
    index.html > nhanvien2.html
