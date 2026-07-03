#!/bin/bash
# Sleepora — TestFlight için release IPA / arşiv üretir.
export PATH="/opt/homebrew/bin:/opt/homebrew/share/flutter/bin:/usr/local/bin:$PATH"
cd /Users/enginerdem/sleepora || exit 1
LOG=/Users/enginerdem/sleepora/_testflight_log.txt
{
  echo "==== TESTFLIGHT BUILD BASLADI: $(date) ===="
  flutter build ipa --release
  echo "IPA_EXIT=$?"
  echo "==== BITTI: $(date) ===="
  echo ""
  echo "--- Arşiv: build/ios/archive/Runner.xcarchive ---"
  echo "--- IPA (varsa): ---"
  ls -la build/ios/ipa/ 2>/dev/null || echo "  (ipa klasörü yok — Xcode Organizer'dan arşivi dağıt)"
} 2>&1 | tee "$LOG"
