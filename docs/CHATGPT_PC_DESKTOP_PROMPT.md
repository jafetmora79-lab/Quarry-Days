# Prompt for ChatGPT: Quarry OS desktop layout and icons

Paste this into ChatGPT (with image generation) together with your reference image (the dark green brick desktop with the mountains, pines and excavator, the beige metal window frame and the taskbar).
Ask for the images one by one, and keep each reply as a separate PNG with a transparent or flat-colour background as stated.

---

I am making a cozy low-poly / pixel-art quarry management game called **Quarry Days**. The in-game office computer runs a fake retro desktop called **QUARRY OS**. I attached a reference image of the look I want:
a dark forest-green brick-textured desktop with a faded mountain range, pine silhouettes and a small excavator in the bottom right corner, a beige / sandstone metal window frame with riveted edges, hazard-stripe corners, a mountain logo top-left and minimise / maximise / close buttons top-right (close is orange-red), and a metal taskbar at the bottom with a square start button on the left.

Please create these assets as **separate PNG files**, in a consistent **pixel-art style** (crisp hard pixels, no anti-aliasing, no blur, limited warm palette: forest greens, sandstone beige, bronze/amber highlights, dark brown, a little hazard yellow). **Do not put any text, numbers, names or clock digits in any image**: the game draws all text itself with its own pixel font.

1. **Desktop wallpaper**, 1920x1080: the dark green brick pattern with soft vignette, the faded mountains + pine silhouettes + excavator at the bottom right, hazard-stripe corner marks top-left and bottom-right. Leave the middle and left calm and empty, because desktop icons sit there.
2. **Window frame**, 9-slice friendly, 1200x800: beige metal frame with a title bar (empty, no text), small mountain logo on the left of the title bar, three buttons on the right (minimise, maximise, close with orange-red background), inner area transparent or flat dark green so I can place content. Also give me the three buttons separately at 32x32 each, in normal / hover / pressed versions.
3. **Taskbar**, 1920x48: same beige metal as the frame, a square start button at the far left with a 2x2 window-pattern symbol, a long empty recessed strip for open-window buttons, and three empty recessed slots on the right (for day, time and money; empty, no text). Also a separate "active window button" and "inactive window button" blank, 220x40 each.
4. **Desktop icons**, 64x64 each (transparent background, plus a 128x128 version of each), one consistent style, same outline weight and the same light direction. Nine icons:
   - **Employees**: two workers with hard hats, shoulder to shoulder.
   - **Machinery**: a yellow excavator seen from the side.
   - **Equipment Catalog**: an open catalog / ring binder with a small machine picture on the cover.
   - **Production**: a crusher with a conveyor belt and a small pile of stone.
   - **Upgrades**: a large upward arrow on a small anvil or gear.
   - **Sales**: a stack of gold coins next to a small receipt.
   - **Quarry Plan**: a rolled blueprint and a folded map with a red pin.
   - **Milestones**: a golden trophy cup on a small base.
   - **Stats**: a bar chart with a magnifying glass.
   For each icon also give a **selected** version (same icon on a translucent amber rounded plate, 80x80).
5. **Small UI glyphs** at 16x16 and 24x24, transparent: close X, minimise dash, maximise square, back arrow, forward arrow, refresh, a coin, a clock, a calendar day marker, a notification bell, a lock (for locked apps), and a checkmark.
6. **Compact status widgets** (empty, no text), 200x56 each: a dark brown rounded panel with a thin bronze border and tiny corner rivets, in three variants (day, time, money), plus one wider 320x96 "next goal" panel with an empty progress bar track.

Style rules: pixel-art, hard edges, no gradients except a very soft vignette on the wallpaper, no text anywhere, consistent palette across all files, original artwork (do not copy any real operating system's icons).

Give each file a clear name, for example `wallpaper.png`, `window_frame.png`, `btn_close_normal.png`, `taskbar.png`, `icon_employees_64.png`, `icon_employees_selected_80.png`, and so on.

---

When you have the images, drop them into `assets/ui/os/` (keep the names above) and tell Claude: the game will place the real day, time and money in the empty slots using the game's own font, and put the app names under the icons.
