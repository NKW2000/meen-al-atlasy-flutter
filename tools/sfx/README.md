# أصوات اللعبة — كيف بتنبنى

كل ملفات `assets/sounds/sfx_*.mp3` مبنية من هون، من تسجيلات حقيقية:

- **`build.js`** — الوصفات: لكل تنبيه طبقات (تسجيل + توقيت + قصّ + حجم + درجة)
  بتتخلط وتتعالج بـffmpeg (مرشّحات، لمسة صدى)، وبتتعاير لنفس الحجم المسموع
  (‎-10 LUFS للأحداث الكبيرة، أهدى للنقرات) بمحدّد ‎-1 dBFS، وبتتصدّر MP3.

## المصادر

- **[Mixkit](https://mixkit.co/free-sound-effects/)** — Sound Effects Free
  License: استعمال تجاري بدون نسب؛ ممنوع إعادة توزيع الملفات الخام (لهيك مش
  بالمستودع). كل ملف برقمه: `https://assets.mixkit.co/active_storage/sfx/<id>/<id>.wav`
  — الأرقام واسمها عند Mixkit مكتوبة أول `build.js`.
- **[Kenney](https://kenney.nl)** — CC0 (ملك عام).

## إعادة البناء

```bash
node tools/sfx/build.js <مجلد-mixkit> <مجلد-kenney> assets/sounds [مسار-ffmpeg]
```

`<مجلد-mixkit>` فيه `<id>.wav` لكل رقم مذكور بـ`build.js`؛ `<مجلد-kenney>` فيه
الحزم مفكوكة. بيطبع جدول بالحجم المسموع قبل وبعد. بدّل وصفة وأعد البناء —
ما في شي يدوي.
