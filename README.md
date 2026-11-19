# Presenza

**Your Mac locks itself when you get up.**

Presenza is a small menu bar app for macOS. It watches the camera and, once it can't see you, a
warning with a countdown grows out of the notch, then the screen locks. If you had only turned away
for a moment, click **Cancel**.

> The interface is in **English** and **Italian**: it follows the system language, or you pick one
> in Settings. [README in italiano](README.it.md).

## Requirements

- macOS 14 Sonoma or later, on an Apple silicon or Intel Mac.
- A camera: the Mac's own or an external one.

## Install

1. Download `Presenza-1.0.dmg` from the [latest release](https://github.com/fabiosantaniellobruun/presenza/releases/latest).
2. Open it and drag **Presenza** into **Applications**.
3. Launch Presenza and allow camera access when macOS asks. Presenza lives in the menu bar, as an
   eye icon (there is no Dock icon).

### The first launch

Presenza is not signed with a paid Apple Developer ID, so macOS cannot verify it and blocks it the
first time. You only need to allow it once:

1. Open Presenza. macOS says it was not opened because Apple could not verify it: click **Done**.
2. Open **System Settings → Privacy & Security** and scroll down to *Security*: next to
   "Presenza.app was blocked to protect your Mac", click **Open Anyway**, then confirm with your
   password or Touch ID.

Or, in Terminal, remove the quarantine flag that the browser added to the download:

```bash
xattr -dr com.apple.quarantine /Applications/Presenza.app
```

## Using it

- When the camera sees neither your face nor your head and shoulders, **"Heading out?"** appears at
  the top of the screen with the seconds left. At zero the screen locks.
- **Cancel** stops the lock and leaves you alone for 30 seconds.
- When you're back, unlock your Mac as usual: Touch ID, Apple Watch or password. Presenza doesn't
  unlock: macOS doesn't allow it, and it wouldn't be safe, since it recognises *a* person, not *you*.
- From the eye menu: **Pause**, **Lock Now** and **Settings…**, where you choose how many seconds
  to wait before locking (3 to 60, 8 by default), the language, and whether Presenza opens at login.

## Privacy

Camera frames are analysed on your Mac, one per second, with Apple's Vision framework. They are
never saved or sent anywhere: Presenza doesn't use the network. While the screen is locked or
Presenza is paused, the camera is off.

## Uninstall

If you set it to open at login, turn that off in Settings first. Then quit Presenza from the eye
menu and drag it to the Trash. Its preferences can be removed with
`defaults delete it.fabiosbruun.Presenza`.

## Build from source

You need Xcode 26 or later (for `swiftc`, and for `actool`, which compiles the icon).

```bash
./build.sh
```

builds `Presenza.app`, signed ad hoc, and runs its self-check.

```bash
./build.sh dmg
```

also builds `dist/Presenza-<version>.dmg`, to share.

## License

[MIT](LICENSE) © 2026 Fabio Santaniello Bruun
