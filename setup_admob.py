import os

# 1. إضافة الحزمة لـ pubspec.yaml
pubspec_path = "pubspec.yaml"
if os.path.exists(pubspec_path):
    with open(pubspec_path, "r", encoding="utf-8") as f:
        pub_content = f.read()

    if "google_mobile_ads:" not in pub_content:
        if "dependencies:" in pub_content:
            new_pub_content = pub_content.replace(
                "dependencies:",
                "dependencies:\n  google_mobile_ads: ^5.1.0"
            )
            with open(pubspec_path, "w", encoding="utf-8") as f:
                f.write(new_pub_content)
            print("✔ تم إضافة google_mobile_ads إلى pubspec.yaml")
    else:
        print("✔ الحزمة مضافة بالفعل في pubspec.yaml")

# 2. البحث الشامل عن AndroidManifest.xml
manifest_files = []
for root, dirs, files in os.walk("."):
    if "AndroidManifest.xml" in files:
        manifest_files.append(os.path.join(root, "AndroidManifest.xml"))

if manifest_files:
    for m_path in manifest_files:
        print(f"تم العثور على: {m_path}")
        with open(m_path, "r", encoding="utf-8") as f:
            content = f.read()

        ad_meta_data = '''    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-7019939648590037~6451390449"/>
    </application>'''

        if "</application>" in content and "APPLICATION_ID" not in content:
            content = content.replace("</application>", ad_meta_data)
            with open(m_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"✔ تم تعديل {m_path} بنجاح!")
        elif "APPLICATION_ID" in content:
            print(f"✔ معرّف التطبيق مضاف مسبقاً في {m_path}")
else:
    print("⚠ لم يتم العثور على أي ملف AndroidManifest.xml داخل هذا المجلد.")

