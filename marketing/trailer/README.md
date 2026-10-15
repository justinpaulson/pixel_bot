# Pixel trailer

A 34-second, 1920×1080, 30 fps trailer in Pixel's pine/lake/mint/canyon palette.
The MP4 includes an original stereo synthesized soundtrack. No stock recordings
or third-party music were used. On-screen copy carries the story without narration.

## Render

Install `ffmpeg` and `librsvg` (`rsvg-convert`) and the Python packages in
`requirements.txt`. The renderer uses macOS's Arial fonts. From the repository root:

```sh
python3 marketing/trailer/render.py --preview
python3 marketing/trailer/render.py
```

Generated files stay in the ignored `output/` directory:

- `pixel-trailer-1080p.mp4`: H.264 / AAC, 16:9, fast start, audio target −16 LUFS.
- `pixel-trailer-thumbnail.jpg`: 1280×720 YouTube thumbnail.
- `storyboard.jpg`: representative frames for visual review.
- `soundtrack.wav`: original music and effects.

## Edit

| Time | Scene |
| --- | --- |
| 0–6 s | Guess the movie; introduce 15-second rounds |
| 6–8 s | Jurassic Park reveal |
| 8–12 s | Pixel draws. You guess. |
| 12–20 s | TV, songs, pop stars, video games |
| 20–24 s | Solo and friends; everyone guesses |
| 24–28 s | Fresh drawings across categories |
| 28–34 s | Logo and playable URL |

Drawings come from the real SVG evaluation samples in `docs/svg-evaluation/`.
`assets/cher.svg` was generated in the local tested Pop Stars game on October 15,
2026. The pencil mark comes from the current application favicon. These are
animated promotional compositions, not a continuous screen recording; generation
waiting time is omitted. The trailer makes no claim that generation is instant.

`publishing.json` contains the title, description and replacement project copy.
