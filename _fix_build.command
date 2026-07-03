#!/bin/bash
# Sleepora iOS build onarim scripti (codesign 'detritus' hatasi)
export PATH="/opt/homebrew/bin:/opt/homebrew/share/flutter/bin:/usr/local/bin:$PATH"
PROJ="/Users/enginerdem/sleepora"
LOG="$PROJ/_fix_build_log.txt"
cd "$PROJ" || { echo "Proje klasoru bulunamadi"; exit 1; }
{
  echo "==== BASLADI: $(date) ===="
  echo "[1/5] xattr -cr (Finder/resource-fork temizligi)"
  xattr -cr .
  echo "[2/5] .DS_Store temizligi"
  find . -name ".DS_Store" -delete
  echo "[3/5] flutter clean"
  flutter clean
  echo "[4/5] flutter pub get"
  flutter pub get
  echo "[5/5] flutter build ios --release"
  flutter build ios --release
  echo "BUILD_EXIT=$?"
  echo "==== BITTI: $(date) ===="
} 2>&1 | tee "$LOG"
