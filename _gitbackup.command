#!/bin/bash
# Sleepora — git yedekleme (stale lock temizle + add + commit + push)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "/Users/enginerdem/sleepora" || { echo "Proje yok"; exit 1; }
{
  echo "==== GIT YEDEK BASLADI: $(date) ===="
  echo "[1/4] stale lock temizle"
  rm -f .git/index.lock
  echo "[2/4] git add -A"
  git add -A
  echo "[3/4] git commit"
  git commit -m "backup: IAP paywall (2.1b) fix + acilis/mayin/ses duzeltmeleri + 1.3.0(27) App Store submit"
  echo "[4/4] git push origin main"
  git push origin main
  echo "GITBACKUP_DONE exit=$?"
  echo "==== GIT YEDEK BITTI: $(date) ===="
} 2>&1 | tee "/Users/enginerdem/sleepora/_gitbackup_log.txt"
