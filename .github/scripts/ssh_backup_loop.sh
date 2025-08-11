#!/bin/bash
set -e

git config --global user.name "Auto Bot"
git config --global user.email "auto@bot.com"
mkdir -p links
git pull --rebase origin main || true

LOOP=0
while true; do
  pkill tmate || true

  tmate -S /tmp/tmate.sock new-session -d
  sleep 5
  TMATE_SSH=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')

  echo "$TMATE_SSH" > links/ssh.txt

  git pull --rebase origin main || true
  git add links/ssh.txt
  git commit -m "Updated SSH link $(date -u)" || true
  git push origin main || true

  echo "[SSH] New SSH link pushed at $(date -u): $TMATE_SSH"

  if (( LOOP % 2 == 0 )); then
    echo "[Backup] Starting backup at $(date -u)"
    tar czf /home/runner/pterodactyl-backup.tar.gz /home/runner/midair-panel /home/runner/db_backup.sql || true

    n=0
    until [ $n -ge 3 ]; do
      aws --endpoint-url=https://s3.filebase.com s3 cp /home/runner/pterodactyl-backup.tar.gz s3://$FILEBASE_BUCKET/pterodactyl-backup.tar.gz && break
      echo "[Backup] Upload failed. Retry in 30s..."
      sleep 30
      n=$((n+1))
    done

    if [ $n -eq 3 ]; then
      echo "[Backup] Failed to upload after 3 attempts!"
    else
      echo "[Backup] Uploaded to Filebase at $(date -u)"
    fi
  fi

  LOOP=$((LOOP + 1))
  echo "[Loop] Sleeping 15 minutes before next refresh..."
  sleep 900
done
