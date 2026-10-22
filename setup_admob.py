import os

# 1. إضافة حزمة الإعلانات إلى pubspec.yaml
print("Adding google_mobile_ads to pubspec.yaml...")
os.system("flutter pub add google_mobile_ads")

# 2. تعديل ملف AndroidManifest.xml بذكاء
manifest_path = "android/app/src/main/AndroidManifest.xml"

if os.path.exists(manifest_path):
    print("Configuring AndroidManifest.xml with your App ID...")
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    ad_meta_data = '''    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-7019939648590037~6451390449"/>
    </application>'''

    # استبدال وسم الإغلاق بالوسم الجديد مع الكود الخاص بك
    if "</application>" in content and "APPLICATION_ID" not in content:
        content = content.replace("</application>", ad_meta_data)
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("AndroidManifest.xml updated successfully!")
    elif "APPLICATION_ID" in content:
        print("App ID is already configured in AndroidManifest.xml")
else:
    print(f"Error: File not found at {manifest_path}")

# 3. تحديث الحزم
os.system("flutter pub get")
print("Process completed! Ready to push to GitHub.")

