#!/bin/bash
git add .
read -p "أدخل رسالة التعديل (Commit Message): " msg
git commit -m "$msg"
git branch -M main
git push -u origin main
echo "🚀 تم الرفع إلى GitHub بنجاح!"
