# قائمة إعلانات حقيقية (AdMob)

الإعلان "Nice job! This is a test ad" إعلان تجريبي من Google.

1. AdMob ← Settings ← Test devices: احذف جوالك من القائمة إن كان مسجلاً.
2. انشر التطبيق على Google Play (اسم الحزمة `com.shatranj.chess_game`)،
   ثم في AdMob ← Apps ← تطبيقك ← App settings ← اربطه بصفحة المتجر.
3. أكمل حساب AdMob: بيانات الدفع + تحقق العنوان (PIN) + المعلومات الضريبية.
4. سياسة خصوصية (رابط) في صفحة Play، وملف app-ads.txt على موقعك.
5. لا تضغط على إعلاناتك بنفسك أبداً.

## وحدات جديدة (الإعلان البيني + المكافأة)
أنشئ وحدتين في AdMob (Interstitial و Rewarded) ثم استبدل المعرّفين:

```
cd ~/chess_game
sed -i "s#ca-app-pub-3940256099942544/1033173712#معرّف-الوحدة-البينية#" lib/main.dart
sed -i "s#ca-app-pub-3940256099942544/5224354917#معرّف-وحدة-المكافأة#" lib/main.dart
git add . && git commit -m "real ad units" && git push
```
