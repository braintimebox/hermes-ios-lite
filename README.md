# Hermes Lite iOS

Minimal native iOS client for Hermes Agent.

Goals:
- maximum responsiveness
- minimum feature surface
- plain-text chat rendering (no Markdown renderer on the hot path)
- Telegram-like local message pins
- server-side scheduled messages via `/webhook/scheduled-messages`
- unsigned IPA built by GitHub Actions

## Build

GitHub Actions generates the Xcode project with XcodeGen and uploads `HermesLite-unsigned.ipa`.

**Current build:** https://github.com/braintimebox/hermes-ios-lite/actions/runs/33272278389/artifacts/9720459657
**All builds:** https://github.com/braintimebox/hermes-ios-lite/actions

## Runtime settings

Default server URL: `https://hermes00.duckdns.org:1118`.
If WebUI auth is enabled, set the WebUI password in Settings. The app stores only the session cookie locally.
