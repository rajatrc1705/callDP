# Features

This file lists only features that are currently integrated and usable in the application.

Rules:
- Include a feature here only when it works end-to-end in the app.
- Do not list stubs, placeholders, or planned roadmap items.
- If a feature is experimental but usable, mark it as `Prototype`.

## Current Integrated Features

### Native macOS app shell
- The project runs as a real macOS app from Xcode through the `CallDPMacApp` target.
- The app requests normal macOS camera access and opens as a foreground window instead of a raw package executable.
- The app now launches role-specific windows for `Director` and `Camera Agent`.

### Dual-role local demo
- The same app can run as a `Director` or `Camera Agent`.
- A launcher window can open each role as a separate macOS window.
- The `Director` window can drive the `Camera Agent` window through a built-in loopback transport on the same Mac.

### Remote-control session flow `Prototype`
- The app tracks a loopback session state between Director and Camera Agent roles.
- The Camera Agent must explicitly accept control before Director commands are applied.
- The Camera Agent can pause, resume, or disconnect remote control without closing the app.

### Network transport `Prototype`
- The Director and Camera Agent windows can switch between `Loopback` and `Network` transport modes.
- The Camera Agent can host a direct TCP control session on a manual port.
- The Director can connect to a Camera Agent using a manual host and port.
- The network transport carries:
  - role registration
  - session state
  - agent snapshots
  - director commands

### Live camera preview
- The app captures frames from the built-in Mac camera.
- The raw input feed is shown in the UI.

### Deterministic reframed preview
- The app computes a crop window from tracker state using deterministic framing logic.
- The reframed output is rendered live in-app as a separate preview.
- Crop movement is controlled by math-driven smoothing rather than per-frame LLM output.

### Apple backend mode `Prototype`
- The Camera Agent can run in an `Apple` backend mode from the UI.
- In that mode, the app uses native Apple speech recognition for live voice command transcription.
- In that mode, the app uses Vision object tracking to follow a locked target across frames.
- The current Apple mode still uses synthetic detections to seed target lock because open-vocabulary grounding is not real yet.
- The Camera Agent UI shows explicit speech status plus start/stop listening controls in Apple mode.
- The transcript display distinguishes partial speech from final recognized utterances.

### Grounded backend mode `Prototype`
- The Camera Agent can run in a `Grounded` backend mode from the UI.
- In that mode, the app uses Apple speech recognition for live command transcription.
- In that mode, the app uses a local Python worker plus a Hugging Face zero-shot object detection model for natural-language object grounding.
- In that mode, the app uses Vision tracking after the initial target box has been found.
- The Camera Agent and Director UIs surface grounding status so model startup and failure states are visible.
- This mode currently requires local Python dependencies from [requirements-grounding.txt](/Users/rajat/hackathons/callDP/requirements-grounding.txt) and still uses a per-request worker process rather than a persistent model service.

### Director state machine
- The app maintains explicit tracking modes for detection, tracking, loss, and reacquisition.
- State transitions are logged and surfaced in the UI.

### Simulation mode
- The app can run in a simulated backend mode for command and vision testing without real AI services.
- Simulation controls are available in the UI.

### Command handling prototype
- The app accepts manually injected commands and simulated transcripts.
- Supported prototype intents include:
  - `focus_object`
  - `move_frame`
  - `zoom`
  - `recenter`
  - `stop_tracking`
  - `select_candidate`

### Candidate selection workflow
- When detections are available, the app shows ranked candidate targets.
- A candidate can be selected from the UI to lock tracking onto it.

### Debug and operator visibility
- The UI shows tracker state, latest transcript, last command, crop summary, source frame size, and recent logs.
- Debug overlays render crop and detection context over the raw feed.
- The Director window shows loopback session state plus live Camera Agent telemetry and candidate detections.

## Explicitly Not Yet Included

The following are intentionally excluded from this file because they are not integrated end-to-end yet:
- Widest-available source capture selection and headroom diagnostics for the built-in camera
- Virtual camera publishing for FaceTime, Zoom, or Meet
- fully validated and production-ready Mac-to-Mac remote direction
- production-hardened grounding runtime
- production-hardened speech and tracking backends
- iPad or iPhone support
