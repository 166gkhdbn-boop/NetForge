<p dir="rtl" align="right">
<p align="center">
  <img src="https://img.shields.io/badge/نسخه-2.0-00d4ff?style=for-the-badge&logo=github&logoColor=white" alt="Version">
  <img src="https://img.shields.io/badge/مجوز-MIT-00d4ff?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/XRay-Core-1.8+-00d4ff?style=for-the-badge" alt="XRay">
</p>

<h1 align="center">
  <br>
  <a href="https://github.com/166gkhdbn-boop/NetForge"><img src="https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/.github/banner.png" alt="NetForge" width="500"></a>
  <br>
  <br>
</h1>

<p align="center">
  <b>رله مخفی VLESS XHTTP پشت CDN نتلیفای</b><br>
  <i>مدیر CLI تعاملی زیبا — یک فایل منفرد، بدون وابستگی</i>
</p>

<p align="center">
  <a href="/166gkhdbn-boop/NetForge">🇺🇸 English</a>
  •
  <a href="#%D9%88%DB%8C%DA%98%DA%AF%DB%8C%E2%80%8C%E2%80%8C%D9%87%D8%A7">✨ ویژگی‌ها</a>
  •
  <a href="#%D8%B4%D8%B1%D9%88%D8%B9-%D8%B3%D8%B1%DB%8C%D8%B9">🚀 شروع سریع</a>
  •
  <a href="#%D9%86%D8%B5%D8%A8">💾 نصب</a>
</p>

---

## ✨ ویژگی‌ها

| ویژگی | توضیحات |
|--------|----------|
| 🗡️ **رله مخفی** | ترافیک VLESS را از طریق CDN نتلیفای هدایت می‌کند و آی‌پی واقعی سرور شما را پنهان می‌کند |
| 🌐 **پروتکل XHTTP** | از پروتکل XHTTP (اسپلیت-استریم) برای حداکثر مخفی‌کاری استفاده می‌کند |
| 🔲 **نصب خودکار Xray** | آخرین نسخه Xray-core را خودکار دانلود و پیکربندی می‌کند |
| 📦 **یک فایل منفرد** | همه چیز در یک فایل `deploy.sh` — بدون وابستگی، بدون نیاز به کلون |
| 🎨 **CLI زیبا** | متن گرادیانت، اسپینر انیمیشن‌دار، باکس‌های دوبل، رابط ۲۵۶ رنگ |
| 🔄 **دیپلوی آسان** | با یک دستور یک سایت رله روی نتلیفای بسازید |
| 📋 **تولید لینک VLESS** | لینک‌های آماده اتصال با xPadding تولید می‌کند |
| 📝 **مدیر تنظیمات** | پیکربندی تعاملی UUID، SNI، پورت و مسیر مخفی |
| 📱 **وبسایت فیک** | یک سایت واقع‌نما DevPulse به عنوان پوشش دیپلوی می‌کند |
| 🐐 **سرویس Systemd** | Xray را به عنوان سرویس سیستم با start/stop/restart مدیریت می‌کند |
| 🔧 **مدیر دیپلوی‌ها** | مشاهده، پیگیری و حذف دیپلوی‌های نتلیفای |

---

## 🚀 شروع سریع

```bash
# نصب و اجرای یک خطی
bash <(curl -sL https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh)
```

همین! اسکریپت یک منوی تعاملی باز می‌کنه که می‌تونید:

1. **نصب Xray** — آخرین نسخه رو خودکار دانلود کنید
2. **پیکربندی** — UUID، SNI، پورت و مسیر مخفی رو تنظیم کنید
3. **تنظیم توکن** — توکن دسترسی نتلیفای رو وارد کنید
4. **دیپلوی** — یک سایت رله مخفی روی نتلیفای بسازید
5. **تولید لینک** — لینک اتصال VLESS خودتون رو بگیرید

---

## 💾 نصب

### ⚡ یک خطی (توصیه‌شده)

```bash
bash <(curl -sL https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh)
```

### 📝 نصب دستی

```bash
# دانلود اسکریپت
wget https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh -O deploy.sh

# اجرایی کردن
chmod +x deploy.sh

# اجرا
bash deploy.sh
```

### 🤖 با Git

```bash
git clone https://github.com/166gkhdbn-boop/NetForge.git
cd NetForge
bash deploy.sh
```

### پیش‌نیازها

- **Python 3.8+** (معمولاً روی اکثر سرورها نصبه)
- **دسترسی روت** (برای نصب Xray و سرویس systemd)
- **اکانت نتلیفای** با توکن دسترسی شخصی
- **گواهی TLS** برای دامین سرورتون (برای TLS زرای)

---

## 📖 نحوه کارکرد

```
کاربر (کلاینت V2Ray)
       \
        v  VLESS روی XHTTP (TLS)
  +-----------+     +-----------------+     +----------+
  |  نتلیفای  | --> |  Edge Function  | --> |  زرای    |
  |  CDN      |     |  (relay.js)    |     |  سرور   |
  +-----------+     +-----------------+     +----------+
  
  آی‌پی عمومی         رله مخفی             وی‌پی‌اس شما
  (نتلیفای)           (نامرئی)              (مخفی)
```

1. **نتلیفای CDN** — دامین شما به نتلیفای اشاره می‌کنه
2. **Edge Function** — یک تابع رله در مسیر مخفی ترافیک رو به زرای فوروارد می‌کنه
3. **سرور زرای** — روی وی‌پی‌اس شما اجرا میشه و پروتکل VLESS رو هندل می‌کنه
4. **xPadding** — لایه اضافه مخفی‌کاری که الگوهای ترافیک HTTP عادی رو شبیه‌سازی می‌کنه

نتیجه: آی‌پی واقعی سرورتون کاملاً پشت CDN نتلیفای پنهان میشه.

---

## ⚙️ تنظیمات

همه تنظیمات در `~/.vless-netlify/config.json` ذخیره میشن و بین اجراها باقی می‌مونن.

| تنظیم | پیش‌فرض | توضیحات |
|-------|---------|----------|
| `uuid` | خودکار | UUID کاربر VLESS |
| `sni` | `kind.sigs.k8s.io` | SNI اولیه TLS |
| `alt_sni` | `dl.google.com` | SNI جایگزین |
| `xray_port` | `444` | پورت گوش دادن زرای |
| `secp` | تصادفی | مسیر مخفی رله |
| `netlify_token` | — | توکن دسترسی نتلیفای |

---

## 💡 دریافت توکن نتلیفای

1. به [Netlify User Applications](https://app.netlify.com/user/applications#personal-access-tokens) برید
2. روی **Create a personal access token** کلیک کنید
3. یک اسم بدید (مثلاً "NetForge")
4. دسترسی‌ها رو انتخاب کنید: **Sites: Read & Write**
5. توکن رو کپی کنید و در گزینه ۳ منوی اسکریپت پیست کنید

---

## 📞 گزینه‌های منو

| # | گزینه | توضیحات |
|---|-------|----------|
| ۱ | نصب / بروزرسانی زرای | آخرین نسخه زرای-کور رو از گیت‌هاب دانلود می‌کنه |
| ۲ | پیکربندی تنظیمات | UUID، SNI، آی‌پی سرور، پورت، مسیر مخفی |
| ۳ | تنظیم توکن نتلیفای | توکن دسترسی شخصی نتلیفای |
| ۴ | دیپلوی روی نتلیفای | یک سایت رله جدید با تابع Edge می‌سازه |
| ۵ | تولید لینک VLESS | لینک اتصال (کامل + مناسب QR) |
| ۶ | مدیریت دیپلوی‌ها | مشاهده، حذف یا پاک کردن دیپلوی‌ها |
| ۷ | کنترل سرویس زرای | استارت، استاپ، ریستارت، لاگ‌ها |
| ۸ | نمایش تنظیمات کامل | تمام تنظیمات فعلی |

---

## ⚠️ نکات مهم

- **گواهی TLS لازمه**: قبل از استارت زرای به یک گواهی TLS معتبر برای دامین سرورتون نیاز دارید
- **زرای روی HTTP/2 گوش میده**: پروتکل XHTTP به H2 نیاز داره
- **پلن رایگان نتلیفای**: روی پلن رایگان نتلیفای کار می‌کنه (۱۰۰ گیگاباندویید در ماه)
- **یک دیپلوی در هر اجرا**: هر بار دیپلوی یک سایت جدید نتلیفای می‌سازه

---

## 🌟 سپاسگزاری

- [Xray-core](https://github.com/XTLS/Xray-core) — موتور اصلی پروکسی
- [نتلیفای Edge Functions](https://docs.netlify.com/edge-functions/overview/) — لایه رله CDN
- [پروتکل VLESS](https://xtls.github.io/en/development/protocols/vless.html) — پروتکل پروکسی سبک

---

<p align="center">
  <b>NetForge</b> — ساخت پل‌های نامرئی در مرزها
  <br><br>
  <img src="https://img.shields.io/badge/ساخته%20شده%20با-%E2%9D%A4%EF%B8%8F-red?style=for-the-badge" alt="Love">
  <img src="https://img.shields.io/badge/برای-%D8%A2%D8%B2%D8%A7%D8%AF%DB%8C-00d4ff?style=for-the-badge" alt="Freedom">
</p>