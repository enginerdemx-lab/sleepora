#!/bin/bash
# Sleepora — pod senkron onarimi (flutter pub get + pod install)
export PATH="/opt/homebrew/bin:/opt/homebrew/share/flutter/bin:/usr/local/bin:$PATH"
cd "/Users/enginerdem/sleepora" || { echo "Proje yok"; exit 1; }
{
  echo "==== PODFIX BASLADI: $(date) ===="
  echo "[1/2] flutter pub get"
  flutter pub get
  echo "[2/2] pod install (ios)"
  cd ios && pod install
  echo "PODFIX_DONE exit=$?"
  echo "==== PODFIX BITTI: $(date) ===="
} 2>&1 | tee "/Users/enginerdem/sleepora/_podfix_log.txt"
