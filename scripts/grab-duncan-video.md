# Grabbing Duncan Rhodes Academy tutorial videos

For personal recipe-extraction use on content you legitimately have member access to.
Paired helper: `scripts/video-to-recipe.sh` (samples frames and hands them to Claude).

## 1. Find the Vimeo embed URL

On the tutorial page, open DevTools → Elements → search for `player.vimeo.com`. You want the iframe `src`:

```
https://player.vimeo.com/video/<VIDEO_ID>?h=<HASH>&...
```

The `h=<HASH>` is the private-video access token. Save both pieces.

## 2. Primary method — yt-dlp with browser cookies

```bash
brew install yt-dlp   # one-time

yt-dlp \
  --cookies-from-browser chrome \
  --referer "https://www.duncanrhodes.com/" \
  -o "%(title)s.%(ext)s" \
  "https://player.vimeo.com/video/<VIDEO_ID>?h=<HASH>"
```

Swap `chrome` for `safari` / `firefox` / `brave` / `edge` — whichever you're logged into Duncan's site with. Run from the folder you want the MP4 in.

## 3. Fallback — DevTools HLS sniffing

If yt-dlp fails (sometimes Vimeo needs a JWT it can't grab):

1. Open the tutorial page, F12 → **Network** tab, filter `m3u8` or `master.json`.
2. Hit play on the video.
3. Right-click the `master.json` (or `master.m3u8`) request → **Copy URL**.
4. Download with ffmpeg:

```bash
ffmpeg -i "<pasted-master-url>" -c copy out.mp4
```

`-c copy` does no re-encoding — the output is byte-for-byte the stream.

## 4. Known-good examples

| Tutorial | Video ID | Hash |
|---|---|---|
| Szarekhan Dynasty Warrior (Updated) | `1159713334` | `c6aed641bd` |
| C'tan Shard of the Void Dragon (Citadel, old) | `486878894` | `de19670d12` |

Add more rows as you grab them.

## 5. Feeding the video back to Claude

Once you have the MP4 locally, tell Claude the path. Claude will:
- Run `ffmpeg -i <mp4> -vf "fps=1/15" frame_%04d.png` to sample every 15s
- Read the frames in batches, transcribe on-screen paint cards
- Emit a `<scheme>-recipe.md` in the repo, same format as `szarekhan-warrior-updated-recipe.md`

## Ethics note

Only use for content you have active member access to, and only for personal note-taking. Don't redistribute the MP4 or the extracted frames.
