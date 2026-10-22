# Refeed

A Mac video player made for one job: playing a signed video full screen so a phone's front camera can read it. Sign-language-to-text features like the Pixel's SL2T only watch the front camera, so to transcribe a recorded video you prop the phone in front of the screen and play it back.

Refeed has no chrome. You get the video, a speed dial and a mirror switch.

## Use

Drop a video on the window, press ⌘O, or right-click a video in Finder and choose Open With → Refeed.

| | |
|---|---|
| Play / pause | Click the video, or Space |
| Full screen | Double-click, or F |
| Speed, 0.25× to 3× in steps of 0.25 | Drag the dial, scroll, or ↑ / ↓ |
| Mirror | The button under the dial, or M |
| Move the video to the left edge, centre or right edge | Drag it sideways, or [ / ] |
| Skip back / forward 2 s | ← / → |
| Back to the start | 0 |

The dial and the mirror button sit on whichever edge the video isn't on. They dim while the video plays, and the pointer hides. Refeed remembers the speed, mirror, video position and window size.

Tips for the camera: keep the screen bright, keep lamps and windows out of its reflection, and fill the phone's view with the signer. Slowing to 0.75× gives the camera more frames for each sign. If the reading looks wrong, try the mirror: front-camera recordings are sometimes saved flipped, which swaps the signer's dominant hand.

## Build

Needs macOS 14 or later and the Xcode command line tools. No Xcode project.

```sh
./build.sh
```

It compiles `main.swift`, adds the icon, signs the app for this Mac, and installs it as `~/Applications/Refeed.app`.

The icon is drawn by `icon/make-icon.swift` in VasavanOS colours. To redraw it, delete `icon/AppIcon.iconset` and build again.

The mirror icon is Lucide's `square-centerline-dashed-horizontal` (ISC licence).
