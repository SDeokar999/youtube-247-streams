#!/usr/bin/env bash
# Loops every *.mp4 in $VIDEO_DIR, in rotation, forever into YouTube's RTMP
# ingest — NOT the same single file over and over. A single short clip
# repeating hundreds of times a day is explicitly what YouTube's 2026
# inauthentic/unmonetizable-content policy language targets; rotating
# through several clips avoids that pattern while still running 24/7.
#
# Restarts ffmpeg immediately if it ever exits (crash, dropped connection,
# transient network blip) — ffmpeg itself has no built-in auto-restart.
set -uo pipefail

STREAM_URL="rtmp://a.rtmp.youtube.com/live2/${YT_STREAM_KEY}"
VIDEO_DIR="${VIDEO_DIR:?VIDEO_DIR must be set}"
BUDGET="${JOB_BUDGET_SECONDS:-21000}"

PLAYLIST="$(mktemp)"
for f in "$VIDEO_DIR"/*.mp4; do
  echo "file '$(readlink -f "$f")'" >> "$PLAYLIST"
done
CLIP_COUNT="$(wc -l < "$PLAYLIST")"

deadline=$((SECONDS + BUDGET))

while [ "$SECONDS" -lt "$deadline" ]; do
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] starting ffmpeg, rotating $CLIP_COUNT clip(s) from $VIDEO_DIR"

  ffmpeg -re -f concat -safe 0 -stream_loop -1 -i "$PLAYLIST" \
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
