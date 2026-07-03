#!/bin/bash
# Sleepora — Disk TESHIS + GUVENLI temizlik.
# Once neyin yer kapladigini gosterir, sonra SADECE yeniden uretilen onbellekleri siler.
# KORUNUR: kaynak kod, TestFlight arsivleri, build 14 IPA, kullanici dosyalarin.
export PATH="/opt/homebrew/bin:/opt/homebrew/share/flutter/bin:/usr/local/bin:$PATH"

echo "================= DISK DURUMU (ONCE) ================="
df -h /
echo ""
echo "En buyuk aday klasorler (boyut hesaplaniyor, biraz surebilir)..."
du -sh ~/Library/Developer/Xcode/DerivedData      2>/dev/null
du -sh ~/Library/Developer/Xcode/Archives         2>/dev/null
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null
du -sh ~/Library/Developer/CoreSimulator          2>/dev/null
du -sh ~/Library/Caches                            2>/dev/null
du -sh ~/.Trash                                    2>/dev/null
du -sh ~/Downloads                                 2>/dev/null
du -sh ~/Desktop                                   2>/dev/null
echo ""
read -p ">> Guvenli temizligi baslatmak icin ENTER (iptal: pencereyi kapat)... " _
echo ""

echo "[1] Xcode DerivedData...";        rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null; echo "   ok"
echo "[2] iOS DeviceSupport...";        rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* 2>/dev/null; echo "   ok (cihaz baglayinca yeniden iner)"
echo "[3] CoreSimulator caches...";     rm -rf ~/Library/Developer/CoreSimulator/Caches/* 2>/dev/null; echo "   ok"
echo "[4] Xcode uygulama onbellegi..."; rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null; echo "   ok"

echo ""
echo "================= DISK DURUMU (SONRA) ================="
df -h /
echo ""
echo ">>> HALA YER AZSA, sunlar genelde en buyuk hacmi tutar:"
echo "    - COP SEPETI: Finder > Cop Sepeti'ne sag tikla > 'Cop Sepetini Bosalt'"
echo "      (Organizer'dan/Finder'dan sildigin her sey ONCE Cop'a gider, bosaltmadan yer acilmaz!)"
echo "    - Downloads / Desktop: yukarida boyutu buyukse gereksizleri sil"
echo "    - Kullanilmayan iOS Simulator'ler (Xcode > Window > Devices and Simulators)"
echo "    - Organizer'da eski arsivler (1-13) — hepsi Apple'da, silinebilir"
echo ""
read -p "Kapatmak icin ENTER... " _
