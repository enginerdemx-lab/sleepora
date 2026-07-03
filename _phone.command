#!/bin/bash
export PATH="/opt/homebrew/bin:/opt/homebrew/share/flutter/bin:/usr/local/bin:$PATH"
cd /Users/enginerdem/sleepora || exit 1
LOG=/Users/enginerdem/sleepora/_phone_log.txt
{
  echo "==== BUILD BASLADI: $(date) ===="
  flutter build ios --release
  echo "BUILD_EXIT=$?"
  echo "==== INSTALL BASLADI: $(date) ===="
  flutter install --release -d 00008140-000E30E91A38801C
  echo "INSTALL_EXIT=$?"
  echo "==== BITTI: $(date) ===="
} 2>&1 | tee "$LOG"
