# Status

This file is the current snapshot of the project state.

Use it for:
- what is implemented now
- what is still stubbed
- what the next build slice is

For finalized integrated capabilities, see [FEATURES.md](/Users/rajat/hackathons/callDP/FEATURES.md). For the forward plan, see [ROADMAP.md](/Users/rajat/hackathons/callDP/ROADMAP.md).

## Current Product Position

CallDP is currently a `local two-role prototype`, not yet the full remote-directed Mac-to-Mac product.

Today it proves:
- the local camera-processing architecture
- the same-app Director and Camera Agent role split
- the local remote-control UX and consent flow through a loopback transport
- the first direct-network remote-control path using manual host/connect setup
- deterministic reframing behavior
- a first real native AI path for live voice commands and visual tracking
- a first real local model path for open-vocabulary object grounding
- the model/state structure needed for object-directed control

It does not yet prove:
- stable and production-ready remote direction from one Mac to another
- virtual camera publishing into call apps
- widest-source capture and explicit sensor-headroom management
- production-grade open-vocabulary object grounding runtime

## What Is Implemented

### App shell
- Native Xcode macOS app target
- Swift package structure for shared code and tests
- Host app configuration for a normal foreground app launch
- App target configuration no longer pinned to `arm64`
- Launcher window plus dedicated `Director` and `Camera Agent` windows

### Core architecture
- Command model
- Detection model
- Tracker state model
- Crop state model
- Tracking state machine
- Deterministic framing controller
- Remote session model
- Unit tests for state machine and framing logic

### Local media pipeline
- Built-in camera capture
- Raw preview in-app
- Reframed preview in-app
- Debug overlays and operator logs

### AI integration scaffolding
- Command parser interface
- Grounding engine interface
- Tracking engine interface
- Audio transcriber interface
- Virtual camera publishing interface
- Apple speech transcriber backend
- Vision tracking backend
- Python grounding worker backend

### Prototype controls
- Simulated transcript injection
- Manual command submission
- Candidate selection flow
- Simulated grounding/tracking backend mode
- Apple backend mode:
  - live speech transcription
  - Vision-based target tracking
  - simulated detections retained for target seeding
- Grounded backend mode:
  - live speech transcription
  - local Python grounding worker
  - Hugging Face zero-shot object detection model integration
  - Vision-based target tracking after target acquisition
- Loopback Director-to-Agent command transport
- Network.framework-based Director-to-Agent command transport
- Manual network host/connect controls in the role windows
- Agent-side accept, pause, resume, and disconnect controls

## What Is Still Stubbed Or Missing

### Stubbed
- Virtual camera publishing

### Missing
- Camera format discovery and widest-source selection
- Source-headroom diagnostics in the UI
- Simpler connection setup than raw host/port
- Network transport hardening and cross-machine validation
- Real CMIO camera extension
- Persistent grounding worker lifecycle and runtime performance hardening
- Model setup/install UX inside the app

## Current Technical Constraint

The current app behaves like a local operator prototype. The missing piece is not the framing math. The missing piece is the product wiring around it:
- capture-format selection to maximize crop headroom
- remote command delivery across two machines
- publish path into existing call apps

Current capture limitation:
- The app currently uses a generic `AVCaptureSession` preset rather than explicitly choosing the widest usable built-in camera format.
- That means the current pan range may be narrower than what the hardware could support if we selected a better source format.

## Next Build Slice

The next implementation slice should be:

1. Validate and harden the new model-backed grounding runtime
2. Preserve the current simulated target path for debugging and fallback
3. Improve reacquisition behavior after tracking confidence drops
4. After grounding is stable enough, return to transport hardening and the CMIO camera extension

## Definition Of Progress

The project reaches the next real milestone when:
- the Camera Agent can accept a natural-language object request
- the app can ground that request to a real target in the live camera feed
- Vision tracking can keep the target locked across frames
- deterministic reframing can follow the target without simulated detections
- the local grounding runtime behaves predictably enough that object focus is actually testable in the app
