#!/bin/bash
cd /Users/enginerdem/sleepora
echo "Flutter iOS Release Build başlatılıyor..."
flutter build ios --release
echo ""
echo "Build tamamlandı! Xcode'dan Archive yapabilirsiniz."
read -p "Devam etmek için Enter'a basın..."
