import os

# إنشاء مسار مجلد أندرويد إذا لم يكن موجوداً
manifest_dir = "android/app/src/main"
os.makedirs(manifest_dir, exist_ok=True)

manifest_path = os.path.join(manifest_dir, "AndroidManifest.xml")

# محتوى ملف AndroidManifest مع معرّف AdMob جاهز
manifest_content = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="chess_game"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- معرّف تطبيق AdMob -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-7019939648590037~6451390449"/>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
'''

with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(manifest_content)

print(f"✔ تم بنجاح إنشاء مسار الأندرويد وملف AndroidManifest.xml في: {manifest_path}")
