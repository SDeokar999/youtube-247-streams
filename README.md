# YouTube 24/7 Streams

Five independent 24/7 YouTube loop streams, consolidated into one repo.
Each is its own GitHub Actions workflow — separate video, separate stream
key, separate cron schedule (staggered 5 minutes apart so they don't hit
GitHub's scheduler at the same instant) — so they run concurrently without
interfering with each other. The first 4 were migrated from 4 separate
repos (`youtube-247-loop-stream`, `ganesh-pancharatnam-loop`,
`grammar-lecture-loop-stream`, `hanuman-chalisa-loop-stream`), which this
replaces.

| Stream | Workflow | Video | Secret |
|---|---|---|---|
| Marathi poem lecture | `marathi-lecture.yml` | `videos/marathi-lecture/loop.mp4` | `YT_STREAM_KEY_MARATHI` |
| Ganesh Pancharatnam | `ganesh-pancharatnam.yml` | `videos/ganesh-pancharatnam/loop.mp4` | `YT_STREAM_KEY_GANESH` |
| Grammar lecture | `grammar-lecture.yml` | `videos/grammar-lecture/loop.mp4` | `YT_STREAM_KEY_GRAMMAR` |
| Hanuman Chalisa (AI song) | `hanuman-chalisa.yml` | `videos/hanuman-chalisa/loop.mp4` | `YT_STREAM_KEY_HANUMAN` |
| Hanuman Chalisa (recording) | `hanuman-chalisa-recording.yml` | `videos/hanuman-chalisa-recording/loop.mp4` | `YT_STREAM_KEY_HANUMAN_RECORDING` |

All four share `scripts/stream-loop.sh` (loops the video into YouTube RTMP,
auto-restarting ffmpeg on any drop) — each workflow just points it at a
different `VIDEO_PATH` and `YT_STREAM_KEY`.

## Migrating from the 4 separate repos (existing live streams)

**The YouTube broadcast is tied to the stream key, not to which repo is
pushing to it** — reusing the same 4 keys here means none of the live
streams actually restart from a viewer's perspective, just a brief handover
gap (no worse than the existing ~6h restart gap).

1. Push this repo (see below), add all 4 secrets using the **same key
   values** already set in the old repos.
2. Manually trigger each workflow once (Actions tab → workflow → Run
   workflow) and confirm it connects (check YouTube Studio → Go Live shows
   the stream active).
3. Once all 4 are confirmed working here, go to each of the 4 old repos →
   Settings → Actions → General → Actions permissions → **Disable Actions**
   (or just delete `.github/workflows/stream.yml` in each). This is the
   important step — if both the old and new repo push to the same stream
   key at once, they'll fight over the connection.

## Setup

### 1. Create the GitHub repo (public, for free unlimited Actions minutes)

```bash
git remote add origin https://github.com/<your-username>/youtube-247-streams.git
git push -u origin main
```

Create the empty **public** repo at [github.com/new](https://github.com/new)
first (no README/gitignore added there).

### 2. Add all 4 secrets

Repo → Settings → Secrets and variables → Actions → New repository secret,
one for each: `YT_STREAM_KEY_MARATHI`, `YT_STREAM_KEY_GANESH`,
`YT_STREAM_KEY_GRAMMAR`, `YT_STREAM_KEY_HANUMAN` — reuse the same values
from the 4 old repos' `YT_STREAM_KEY` secret (you'll need to re-copy them
from YouTube Studio if you don't have them saved, since GitHub secrets
can't be read back once set).

### 3. Start each stream

Actions tab → pick a workflow → **Run workflow**, once per stream. Each
one's cron schedule then keeps it going independently.

## Known limitations

Same as the original repos: a short gap (~1-10 min, occasionally more) at
each ~6-hour restart boundary per stream, due to GitHub's job cap + cron
scheduling jitter.
