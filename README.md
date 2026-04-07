# Transmute

## Build & install

1. `open transmute.xcodeproj`
2. Product → Scheme → Edit Scheme → Run → **Build Configuration: Release**.
3. Product → Build (⌘B).
4. Project navigator → **Products** → right-click `transmute.app` → **Show in Finder**.
5. Drag `transmute.app` into `/Applications`.
6. Strip Gatekeeper quarantine (unsigned build):
   ```
   xattr -cr /Applications/transmute.app
   ```
7. Launch, then grant Accessibility permission: System Settings → Privacy & Security → Accessibility → enable `transmute`.
