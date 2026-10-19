# إعداد Firebase (مرة واحدة)

1. افتح https://console.firebase.google.com وأنشئ مشروعاً جديداً (يمكنك تعطيل Google Analytics).
2. Build ← Authentication ← Get started ← Sign-in method ← فعّل **Anonymous**.
3. Build ← Firestore Database ← Create database (Production mode، أقرب منطقة).
   ثم تبويب **Rules** ← الصق محتوى الملف `firestore.rules` كاملاً ← Publish.
4. Project settings ← Your apps ← أضف تطبيق Android:
   - Package name: `com.shatranj.chess_game`
   - نزّل الملف `google-services.json`.
5. انسخ الملف إلى جذر المشروع في Termux ثم ارفعه:
   ```
   cp ~/storage/downloads/google-services.json ~/chess_game/
   cd ~/chess_game && git add . && git commit -m "firebase config" && git push
   ```
6. (اختياري لآيفون) أضف تطبيق iOS بمعرّف `com.shatranj.chessGame` ونزّل `GoogleService-Info.plist`
   وضعه في جذر المشروع بنفس الطريقة.

## أكواد الهدية (للاشتراكات)
Firestore ← Start collection باسم `giftcodes`، وكل كود مستند:
- Document ID = الكود (مثال: `GOLD-7K2P-QX9M`)
- الحقول: `tier` (number: 1 فضي، 2 ذهبي، 3 ماسي)، `days` (number)، `used` (null)
