# Coding Assistant instructions

This file provides guidance to coding assistants when working with code in this repository.

## Project

Transmute is a macOS menu bar app (SwiftUI + AppKit). User selects text anywhere, presses ⌥⇧T, picks a transformation (local or LLM-powered), and the selection is replaced in place.

## Principles

- **Simple.** One shortcut, one panel, one purpose. No accounts, no telemetry, no cloud sync.
- **Native.** Pure SwiftUI + AppKit. Feels like a macOS app because it is one.
- **LLM-agnostic.** Anthropic, OpenAI, Gemini or local LLMs — your key, your choice. Swap providers in Settings.
- **Lightweight.** A menu bar app that stays out of the way until you summon it. Minimal code, minimal surface area.

## Build

Xcode project, no SwiftPM target, no tests.

```bash
xcodebuild -project transmute.xcodeproj -scheme transmute -configuration Debug build
```

First run must be from Xcode so Accessibility permission can be granted to the built bundle.

## Architecture

End-to-end flow: `HotkeyService` event tap → `TransmutePanel.show()` → `AccessibilityService.getSelectedText()` → SwiftUI panel near cursor → user picks `TextAction` → `action.apply(to:)` (local closure or `LLMService`) → `AccessibilityService.replaceSelectedText(with:)`.

The three system-integration services in `Services/` are the only places that touch global macOS state:

- **`HotkeyService`** — Global `CGEvent` tap for the trigger chord. Self-recovers from `tapDisabledBy*` and retries `tapCreate` up to 10× since it can only succeed *after* Accessibility is granted.
- **`AccessibilityService.getSelectedText()`** — Tries the AX API first (non-destructive); only falls back to synthesizing ⌘C + polling `pasteboard.changeCount` + restoring the clipboard if AX fails. Preserve this ordering.
- **`LLMService`** — Singleton, reads provider/model selection from `UserDefaults` and the API key from `KeychainService` on every call. Adding a provider requires touching four spots: `LLMProvider` enum, `buildXxxRequest`, `parseResponse` switch, `process()` switch.

`TransmutePanel` is a borderless `NSPanel` (`.screenSaver` level, non-activating) hosting a SwiftUI view, recreated per invocation. `TextAction` dispatches between `localTransform` closure and an LLM `prompt`; the catalog lives in `TextAction.builtIn`.

## Things to know

- **Accessibility permission is load-bearing.** Rebuilding can invalidate it; the hotkey will silently stop working until re-granted. The retry loop in `HotkeyService` exists for this.
- **API keys are stored in the macOS Keychain** via `KeychainService`, never in `UserDefaults` or plain text.
- **Local LLMs work today** via any OpenAI-compatible server (Ollama, LM Studio, Jan, …) — see `LLMService.buildOllamaRequest`.
