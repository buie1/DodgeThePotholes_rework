#!/usr/bin/env bash
# Makes a contact sheet of video frames around a moment of play, from a run recorded
# with `scripts/dev-run.sh ... --video`. Debug builds only; see docs/DEV_MODE.md.
#
# Usage: scripts/dev-frames.sh <run-dir> <t> [window] [fps]
#   run-dir  a build/dev-runs/<timestamp>-<name> folder with run.mp4
#   t        seconds of play, as in devlog.jsonl's "t"
#   window   seconds of video to show, centred on t (default 1)
#   fps      frames per second sampled (default 15)
#
# Output: <run-dir>/frames-<t>.png, a grid read left to right, top to bottom.
set -euo pipefail

dir="${1:?usage: scripts/dev-frames.sh <run-dir> <t> [window] [fps]}"
t="${2:?usage: scripts/dev-frames.sh <run-dir> <t> [window] [fps]}"
window="${3:-1}"
fps="${4:-15}"

video_clock="$(sed -n 's/^videoClock: //p' "$dir/run.txt")"
# Wall-clock time of play time 0, from the run's first snapshot (its first engine frame).
run_clock="$(grep '"snapshot"' "$dir/devlog.jsonl" | head -1 | python3 -c 'import json,sys; e = json.load(sys.stdin); print(e["clock"] - e["t"])')"
start="$(python3 -c "print(max(0, $run_clock - $video_clock + $t - $window / 2))")"
frames="$(python3 -c "import math; print(math.ceil($window * $fps))")"
cols=5
rows="$(python3 -c "import math; print(math.ceil($frames / $cols))")"

out="$dir/frames-$t.png"
ffmpeg -loglevel error -y -ss "$start" -t "$window" -i "$dir/run.mp4" \
  -vf "fps=$fps,scale=240:-1,tile=${cols}x${rows}:padding=4" -frames:v 1 "$out"
echo "$out"
