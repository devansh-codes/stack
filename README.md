<!-- To add a screenshot: save it as docs/screenshot.png and uncomment the line below.
<img width="1512" height="982" alt="Stack screenshot" src="docs/screenshot.png" />
-->

# Stack

A pad of sticky notes for your Mac.

Stack keeps a fresh pad waiting in your menu bar. Peel one off whenever a thought needs somewhere to go, whether that is a phone number, a link, or a reminder you want to keep in your line of sight, and it stays on the desktop until you are done with it. The dashboard holds the whole pad, so nothing gets lost behind a window.

Everything is stored locally as plain JSON. It is written in SwiftUI with no Electron shell, no account, and no subscription.

Stack uses Apple's Liquid Glass design, so it requires macOS 26 or newer.

## Requirements

- macOS 26 (Tahoe) or later. The app will not run on earlier versions.
- Xcode Command Line Tools, if you are building from source. Install them with `xcode-select --install`.

## Install

The one-line install clones the repo, builds Stack on your machine, and puts it in `~/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/devansh-codes/stack/main/install.sh | bash
```

Building locally is the smoothest path because macOS does not quarantine an app you compiled yourself, so there is nothing to bypass on first launch.

### Building it yourself

If you would rather see each step, clone and run the build script directly:

```bash
git clone https://github.com/devansh-codes/stack.git
cd stack
./scripts/build-app.sh
```

The build takes a few seconds and writes three artifacts:

```text
dist/Stack.app
dist/Stack.zip
dist/Stack.dmg
```

Drag `dist/Stack.app` into `/Applications`, or just double-click it to run in place.

### Downloading a prebuilt copy

Prebuilt `Stack.dmg` and `Stack.zip` files are attached to the [latest release](https://github.com/devansh-codes/stack/releases/latest). These are unsigned, and macOS marks anything unsigned that arrives through a browser as "damaged" on first open. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Stack.app
```

It opens normally after that. The old right-click-and-choose-Open workaround no longer works for unsigned apps on macOS Sequoia and later, so use the command above.

## Running and testing it

Stack has no Dock icon by design. It runs as a menu bar app, so after launching look for the paperclip icon in the top-right of your screen. If you are checking that everything works, this path covers the main features in about a minute:

1. Launch the app. The dashboard opens on first run and a paperclip icon appears in the menu bar.
2. Click "+ New" in the dashboard, or pick "New Note" from the menu bar icon. A note window appears on your desktop.
3. Type something into the note. Drag it around by its body to reposition it.
4. Hover over the note and use the pin control to keep it above other windows. Switch to another app to confirm it stays visible.
5. Open the dashboard again with "Show / Hide Dashboard" from the menu bar. Every note you have created is listed there.
6. Expand the Appearance section to change text size, text color, and the background style between Regular and Clear. Changes apply live.
7. Quit with "Quit Stack", then reopen the app. Your notes and their positions come back, which confirms they were saved to disk.

The menu bar icon also carries keyboard shortcuts while its menu is open: `n` for a new note, `d` to toggle the dashboard, and `q` to quit.

## Where notes are stored

Notes are saved as a single JSON file at:

```text
~/Library/Application Support/Stack/notes.json
```

Nothing leaves your machine. The dashboard shows this path and can reveal it in Finder.

## Uninstalling

Delete the app and, if you want the notes gone too, remove the storage folder:

```bash
rm -rf ~/Applications/Stack.app
rm -rf ~/Library/Application\ Support/Stack
```

## License

Stack is released under the [MIT License](LICENSE).
