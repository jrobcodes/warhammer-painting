#!/usr/bin/env bash
# Sample frames from a tutorial MP4 for Claude to transcribe.
# Usage: scripts/video-to-recipe.sh <video.mp4> [interval_seconds]
# Default interval: 15s (matches the on-screen paint-card dwell time).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <video.mp4> [interval_seconds]" >&2
  exit 1
fi

video="$1"
interval="${2:-15}"

if [[ ! -f "$video" ]]; then
  echo "Video not found: $video" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg not installed. Run: brew install ffmpeg" >&2
  exit 1
fi

base="$(basename "$video" .mp4)"
out_dir="frames-$base"
mkdir -p "$out_dir"

ffmpeg -hide_banner -loglevel warning \
  -i "$video" \
  -vf "fps=1/$interval" \
  "$out_dir/frame_%04d.png"

echo "Sampled frames into: $out_dir"
ls "$out_dir" | head -5
echo "..."
echo "Total frames: $(ls "$out_dir" | wc -l | tr -d ' ')"
