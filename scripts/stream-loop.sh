#!/usr/bin/env bash
# Loops every *.mp4 in $VIDEO_DIR into YouTube's RTMP ingest. Each clip
# repeats back-to-back until roughly $BLOCK_SECONDS of runtime is reached,
# then moves to the next clip in the directory, cycling forever. With a
# single clip in the directory this is equivalent to a plain infinite loop;
# with several clips it rotates through them in hour-ish (or whatever
# BLOCK_SECONDS is set to) blocks instead of switching every few minutes.
#
# Restarts ffmpeg immediately if it ever exits (crash, dropped connection,
# transient network blip) — ffmpeg itself has no built-in auto-restart.
set -uo pipefail

STREAM_URL="rtmp://a.rtmp.youtube.com/live2/${YT_STREAM_KEY}"
VIDEO_DIR="${VIDEO_DIR:?VIDEO_DIR must be set}"
BUDGET="${JOB_BUDGET_SECONDS:-21000}"
BLOCK_SECONDS="${BLOCK_SECONDS:-3600}"

get_duration_seconds() {
  ffmpeg -i "$1" 2>&1 | grep -m1 "Duration:" \
    | sed -n 's/.*Duration: \([0-9]*\):\([0-9]*\):\([0-9.]*\),.*/\1 \2 \3/p' \
    | awk '{printf "%d\n", $1*3600+$2*60+$3}'
}

PLAYLIST="$(mktemp)"
for f in "$VIDEO_DIR"/*.mp4; do
  abspath="$(readlink -f "$f")"
  dur="$(get_duration_seconds "$f")"
  case "$dur" in
    ''|*[!0-9]*) dur=180 ;;   # couldn't parse duration — assume 3 min
  esac
  [ "$dur" -lt 1 ] && dur=180

  repeats=$(( (BLOCK_SECONDS + dur - 1) / dur ))   # ceiling division
  [ "$repeats" -lt 1 ] && repeats=1

  for _ in $(seq 1 "$repeats"); do
    echo "file '$abspath'" >> "$PLAYLIST"
  done
done
CLIP_COUNT="$(find "$VIDEO_DIR" -maxdepth 1 -name '*.mp4' | wc -l)"

deadline=$((SECONDS + BUDGET))

while [ "$SECONDS" -lt "$deadline" ]; do
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] starting ffmpeg, $CLIP_COUNT clip(s) from $VIDEO_DIR, ~${BLOCK_SECONDS}s per clip before switching"

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
