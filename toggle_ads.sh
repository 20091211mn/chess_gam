#!/bin/bash

# حدد مسار ملف الكود الخاص بك هنا
FILE_PATH="path/to/your/file.kt"
REAL_ID="ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
TEST_ID="ca-app-pub-3940256099942544/5224354917"

echo "اختر العملية المطلوبة:"
echo "1) تفعيل الإعلان التجريبي"
echo "2) إعادة المعرّف الأصلي"
read -p "أدخل رقم الاختيار (1 أو 2): " choice

# تجهيز المعرفات للـ sed بحماية الشرطة المائلة
REAL_ID_ESC=$(echo "$REAL_ID" | sed 's/\//\\\//g')
TEST_ID_ESC=$(echo "$TEST_ID" | sed 's/\//\\\//g')

if [ "$choice" == "1" ]; then
    sed -i "s/$REAL_ID_ESC/$TEST_ID_ESC/g" "$FILE_PATH"
    echo "✅ تم التحويل إلى الوضع التجريبي بنجاح!"
elif [ "$choice" == "2" ]; then
    sed -i "s/$TEST_ID_ESC/$REAL_ID_ESC/g" "$FILE_PATH"
    echo "🔒 تم إرجاع المعرّف الأصلي بنجاح!"
else
    echo "❌ اختيار غير صحيح."
fi
