# Changelog

This file is the running history of product and code changes for CallDP.

Guidelines:
- Add new entries at the top under `Unreleased`.
- Keep entries scoped to behavior, architecture, and user-visible workflow changes.
- Move an item to `FEATURES.md` only when it is actually integrated and usable in the app.

## Unreleased

### Added
- `CHANGELOG.md` as the running iteration log for the project.
- `FEATURES.md` as the source of truth for currently integrated app capabilities.
- `ROADMAP.md` as the forward-looking path from prototype to remote-directed Mac camera product.
- `STATUS.md` as the current-state snapshot of what is implemented, stubbed, and next.
- `CONCEPTS.md` as the running reference for technical concepts, protocols, and platform APIs used in the app.
- A `Grounded` backend mode that pairs Apple speech plus Vision tracking with a local Python grounding worker.
- A local Python grounding worker script in [Scripts/grounding_worker.py](/Users/rajat/hackathons/callDP/Scripts/grounding_worker.py) using Hugging Face zero-shot object detection models.
- A repo-local grounding dependency manifest in [requirements-grounding.txt](/Users/rajat/hackathons/callDP/requirements-grounding.txt).
- Agent and Director UI grounding status visibility through session snapshots and local status rows.
- Shared remote-session models for app roles, loopback session state, and agent snapshots.
- Same-app `Director` and `Camera Agent` windows for local multi-role testing.
- Loopback remote command transport for directing one window from another on the same Mac.
- Agent-side consent and override controls:
  - `Accept`
  - `Pause`
  - `Resume`
  - `Disconnect`
- Product-planning requirement for widest-source capture and sensor-headroom-aware reframing.
- A `Network.framework`-based remote command transport for manual Mac-to-Mac host/connect control.
- Transport-mode switching in both role windows so loopback and network transport can be selected from the UI.
- Manual host/connect controls for the first real remote-control prototype:
  - Camera Agent host/listen
  - Director connect/disconnect
- Direct TCP control-plane messaging for:
  - role registration
  - session state
  - agent snapshots
  - director commands
- An `Apple` backend mode that uses native Apple speech transcription plus Vision-based tracking while keeping simulated grounding in place.
- Native speech and microphone permission strings in the app host `Info.plist`.
- A dedicated speech status panel with explicit start/stop listening controls in the Camera Agent UI.
- A live microphone badge plus partial-versus-final transcript highlighting in the Camera Agent UI.

### Changed
- Converted the runnable app from a Swift package executable into a native Xcode macOS app target.
- Added a committed Xcode project and app host so `Command-R` launches a normal foreground macOS app window.
- Kept the shared app UI and pipeline logic in reusable Swift package library targets.
- Removed the native app target's `arm64` architecture pin so the host app is no longer Apple-Silicon-only by configuration.
- Replaced the single-window prototype entrypoint with a launcher plus dedicated `Director` and `Camera Agent` windows.
- Refactored the former monolithic prototype view model into role-specific `DirectorConsoleViewModel` and `CameraAgentViewModel`.
- Updated the roadmap to treat camera-format selection and source headroom as a prerequisite for high-quality reframing.
- Reprioritized the roadmap so the next build slice is real two-Mac remote direction first, with source-headroom work moved later.
- Reworked the role-window containers so each role can run against either loopback or network transport without losing the existing local demo path.
- Reframed the immediate roadmap around the first real AI backend slice instead of further transport work first.
- Updated the operator panel so simulation controls are clearly labeled as target injection when the Apple backend mode is active.
- Added explicit grounding error/status reporting so real detector failures are no longer silently swallowed.
- Kept the existing `Apple` backend stable while introducing the model-backed `Grounded` backend alongside it.

## 2026-04-06

### Added
- Initial macOS AI camera-reframing prototype scaffold.
- Core domain models for commands, detections, tracker state, crop state, and normalized geometry.
- Deterministic framing controller with smooth crop math and unit tests.
- Tracking state machine with explicit modes:
  - `idle`
  - `detecting`
  - `tracking`
  - `lost_target`
  - `reacquiring`
- Camera capture pipeline for the built-in Mac camera.
- In-app raw camera preview and reframed preview.
- Debug overlays for detections, crop state, and logs.
- Mockable backend interfaces for:
  - audio transcription
  - command parsing
  - grounding
  - tracking
  - virtual camera publishing
- Simulated mode for injecting transcripts, detections, and tracking behavior without real AI backends.

### Changed
- Separated the codebase into a pure shared core module and an app/UI module to keep perception, control, and rendering logic testable in isolation.

### Known Gaps At This Stage
- Virtual camera publishing is still a stub, not a real Core Media I/O camera extension.
- Speech recognition, open-vocabulary grounding, and real tracking backends are still stubbed or simulated.
- Remote director-to-agent control is not implemented yet.
