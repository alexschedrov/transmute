# Installation

## Requirements

- macOS 15.6 or later
- To build from source Xcode 16+ (no SwiftPM target - this is a plain Xcode project)

## Option A: download a release

1. Grab `transmute.app.zip` from the [latest release](https://github.com/alexschedrov/transmute/releases/latest) and unzip it into `/Applications`.
2. Strip the Gatekeeper quarantine (the build is unsigned and not notarized):
   ```
   xattr -cr /Applications/transmute.app
   ```
3. Launch `transmute.app`.

## Option B: build from source

1. Open `transmute.xcodeproj` in Xcode.
2. Product → Scheme → Edit Scheme → Run → **Build Configuration: Release**.
3. Product → Build (`⌘B`).
4. Product → Show Build Folder in Finder → **Release** → drag `transmute.app` into `/Applications`.
5. Strip the Gatekeeper quarantine (the build is unsigned):
   ```
   xattr -cr /Applications/transmute.app
   ```
6. Launch `transmute.app`.

## Grant permissions

Transmute needs two permissions to work, both requested on first run:

- **Accessibility** - lets Transmute read the selected text and replace it in place. **System Settings → Privacy & Security → Accessibility → enable transmute.** This permission must be granted from the *built* app bundle in `/Applications`, not from Xcode's debug build - rebuilding from Xcode produces a differently-signed binary and will silently invalidate the grant, so the global hotkey stops responding until you re-enable it.
- **Keychain** - API keys are stored in the macOS Keychain, never in plain text or `UserDefaults`. You'll be prompted the first time you save a key in Settings.

## Troubleshooting

**The `⌥⇧T` hotkey does nothing.**
Almost always an Accessibility permission issue. Open **System Settings → Privacy & Security → Accessibility**, remove `transmute` from the list if present, then re-add it and toggle it on. This is especially common after rebuilding - see the note above.

**CodeSign fails with `resource fork, Finder information, or similar detritus not allowed`.**
Usually caused by `.DS_Store` files or extended attributes left in the source tree - commonly introduced by dragging files (e.g. screenshots into `docs/assets`) into the repo via Finder. Run:
```
find . -name .DS_Store -delete
xattr -cr .
```
then in Xcode: **Product → Clean Build Folder** (`⇧⌘K`) and rebuild. If it still fails, retry the `xattr` step with `sudo` to clear system-protected attributes.

**App won't open - "transmute is damaged and can't be opened."**
Gatekeeper quarantined the unsigned build. Re-run:
```
xattr -cr /Applications/transmute.app
```

**Selected text isn't replaced, or the wrong text gets replaced.**
Transmute first tries the macOS Accessibility API to read/write the selection directly. If that fails for a given app, it falls back to synthesizing `⌘C`, polling the pasteboard, and restoring your clipboard afterward. Some apps (certain Electron or sandboxed apps) don't expose a usable Accessibility API and can't be supported by either path.

**LLM requests fail.**
Check Settings → your provider's API key is saved and valid, and that you've selected a model. For local models, Transmute talks to any OpenAI-compatible local server (Ollama, LM Studio, Jan, …) - confirm the server is running, a model is loaded, and the configured URL is reachable.
