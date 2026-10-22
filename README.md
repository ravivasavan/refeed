# Refeed

A Mac video player made for one job: playing a signed video full screen so a phone's front camera can read it. Sign-language-to-text features like the Pixel's SL2T only watch the front camera, so to transcribe a recorded video you prop the phone in front of the screen and play it back.

Refeed has no chrome. You get the video and one column of controls beside it: a time dial, a speed dial and a mirror switch. Nothing sits on top of the video.

It comes as a native Mac app and as a single web page (`web/index.html`) that does the same thing in Safari or Chrome.

## Use

Drop a video anywhere on the window, or use Select Video. In the Mac app you can also press ⌘O, or right-click a video in Finder and choose Open With → Refeed. The window edges glow while a file is over them and pulse once when the video loads.

| | |
|---|---|
| Play / pause | Click the video, or Space |
| Full screen | Double-click, or F |
| Scrub | Drag the time dial |
| Speed, 0.25× to 3× in steps of 0.25 | Drag the speed dial, scroll, or ↑ / ↓ |
| Mirror | The button under the dial, or M |
| Move the video to the left edge, centre or right edge | Drag it sideways, or [ / ] |
| Skip back / forward 2 s | ← / → |
| Back to the start | 0 |

The controls sit on whichever edge the video isn't on. They dim while the video plays, and the pointer hides. Refeed remembers the speed, mirror and video position (and, in the Mac app, the window size).

Tips for the camera: keep the screen bright, keep lamps and windows out of its reflection, and fill the phone's view with the signer. Slowing to 0.75× gives the camera more frames for each sign. If the reading looks wrong, try the mirror: front-camera recordings are sometimes saved flipped, which swaps the signer's dominant hand.

## Web

Open `web/index.html` in Safari or Chrome. It's one file with no dependencies, so it also works straight from disk. Settings are kept in the browser's local storage.

## Build the Mac app

Needs macOS 14 or later and the Xcode command line tools. No Xcode project.

```sh
./build.sh
```

It compiles `main.swift`, adds the icon, signs the app for this Mac, and installs it as `~/Applications/Refeed.app`.

The icon is drawn by `icon/make-icon.swift` in VasavanOS colours. To redraw it, delete `icon/AppIcon.iconset` and build again.

The mirror icon is Lucide's `square-centerline-dashed-horizontal` (ISC licence).
