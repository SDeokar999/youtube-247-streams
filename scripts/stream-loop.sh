#!/usr/bin/env bash
# Loops $VIDEO_PATH forever into YouTube's RTMP ingest, restarting ffmpeg
# immediately if it ever exits (crash, dropped connection, transient network
# blip) — ffmpeg itself has no built-in auto-restart, so this wrapper is what
# makes a single job resilient for its ~6 hour lifetime. Shared by all
# workflows in this repo; each one sets VIDEO_PATH and YT_STREAM_KEY to its
# own values before calling this script.
set -uo pipefail

STREAM_URL="rtmp://a.rtmp.youtube.com/live2/${YT_STREAM_KEY}"
VIDEO_PATH="${VIDEO_PATH:?VIDEO_PATH must be set}"
BUDGET="${JOB_BUDGET_SECONDS:-21000}"

deadline=$((SECONDS + BUDGET))

while [ "$SECONDS" -lt "$deadline" ]; do
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] starting ffmpeg for $VIDEO_PATH"

  ffmpeg -re -stream_loop -1 -i "$VIDEO_PATH" \
    -vf scale=1280:-2 \
    -c:v libx264 -preset veryfast -profile:v high \
    -b:v 3000k -maxrate 3000k -bufsize 6000k \
    -g 60 -keyint_min 60 -r 30 -pix_fmt yuv420p \
    -c:a aac -b:a 128k -ar 44100 \
    -f flv "$STREAM_URL"

  code=$?
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ffmpeg exited (code $code), restarting in 5s"
  sleep 5
done

echo "Budget of ${BUDGET}s reached, exiting cleanly so the job finishes before the 6h hard timeout."
