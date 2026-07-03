#!/bin/bash
# Sleepora — Admin paneli / web sitesini Firebase Hosting'e yayınlar.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:/opt/homebrew/share/flutter/bin:$PATH"
cd /Users/enginerdem/sleepora || exit 1
LOG=/Users/enginerdem/sleepora/_deploy_log.txt
{
  echo "==== DEPLOY BASLADI: $(date) ===="
  if command -v firebase >/dev/null 2>&1; then
    firebase deploy --only hosting
  else
    echo "firebase bulunamadi, npx ile deneniyor..."
    npx --yes firebase-tools deploy --only hosting
  fi
  echo "DEPLOY_EXIT=$?"
  echo "==== BITTI: $(date) ===="
} 2>&1 | tee "$LOG"
