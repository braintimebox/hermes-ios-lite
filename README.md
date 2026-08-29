# Hermes Lite iOS

Minimal native iOS client for Hermes Agent.

Goals:
- maximum responsiveness
- Hermex-like polished chat shell without the Hermex hot-path weight
- plain-text chat rendering (no Markdown renderer on the hot path)
- chat/session picker
- Telegram-like local message pins
- server-side scheduled messages via `/webhook/scheduled-messages`
- unsigned IPA built by GitHub Actions

## Build

GitHub Actions generates the Xcode project with XcodeGen and uploads `HermesLite-unsigned.ipa`.

**Current build:** pending v0.2.0
**All builds:** https://github.com/braintimebox/hermes-ios-lite/actions

## Runtime settings

Default server URL: `https://hermes00.duckdns.org:1118`.
If WebUI auth is enabled, set the WebUI password in Settings. The app stores only the session cookie locally.
