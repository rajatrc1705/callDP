# Roadmap

This file describes the planned path from the current prototype to the intended product:

- Person A on a Mac directs Person B's camera framing
- Person B on a Mac runs the camera agent locally
- Both Intel and Apple Silicon Macs are supported
- B's reframed output is published into existing call apps through a virtual camera

This is a planning document, not a record of shipped work. For shipped/integrated features, see [FEATURES.md](/Users/rajat/hackathons/callDP/FEATURES.md). For the running history of changes, see [CHANGELOG.md](/Users/rajat/hackathons/callDP/CHANGELOG.md).

## Product Target

CallDP becomes a two-role Mac product:
- `Director`: the remote operator who issues voice or text framing commands
- `Camera Agent`: the local app running on the subject's Mac that sees the camera, interprets commands, and applies reframing

Core design principle:
- AI decides `what` to follow
- deterministic control decides `how` to move the frame

Capture strategy:
- Capture the widest usable built-in camera source first, then do all reframing as a digital crop inside that source.
- Do not assume a centered wide view exposes the full pan range available from the sensor.
- Treat source-format selection, crop headroom, and output-format publishing as separate concerns.

## Status Legend

- `Done`: integrated into the current app
- `Next`: highest-priority implementation slice
- `Later`: important, but not on the critical path for the next build

## Phase 0: Local Prototype Foundation

Status: `Done`

Goals:
- Establish the core data model and state machine
- Build camera capture and in-app preview
- Build deterministic reframing
- Keep AI integrations mockable

Delivered:
- Shared core models and deterministic framing controller
- Tracking state machine
- Native macOS app shell
- Live raw preview and reframed preview
- Simulation mode and stubbed AI backends

## Phase 1: Dual-Role App On One Mac

Status: `Done`

Goals:
- Use the same app as either `Director` or `Camera Agent`
- Run two windows on one Mac for a local end-to-end demo
- Validate the remote-control UX before network work

Work:
- Add role selection at launch
- Split the current monolithic app state into role-specific view models
- Add a shared session model for pairing and role state
- Add B-side consent, pause, and disconnect controls

Exit criteria:
- One window can act as Director
- A second window can act as Camera Agent
- Director commands change Agent framing through a local transport

## Phase 2: Local Loopback Command Transport

Status: `Done`

Goals:
- Prove the full command flow without network complexity

Work:
- Add a `RemoteCommandTransport` protocol
- Implement an in-process or loopback transport
- Route structured commands, session state, acknowledgements, and target-selection events
- Log all command delivery and acceptance states

Exit criteria:
- The Director window can connect to the Agent window on the same Mac
- Commands are visible, accepted, and applied in real time

## Phase 3: Two-Mac Remote Control

Status: `Next`

Goals:
- Let A direct B from a separate Mac

Work:
- Harden the newly added direct control-plane transport between two Macs
- Preserve the current consent, pause, resume, and disconnect semantics over the network path
- Improve connection UX:
  - better connection status
  - clearer error states
  - simpler connection setup than raw host/port
- Support reconnects and stale-session handling

Exit criteria:
- Two separate Macs can connect
- A can issue commands to B with low enough latency for live reframing

## Phase 4: Real Virtual Camera Output

Status: `Later`

Goals:
- Make B's reframed output usable in FaceTime, Zoom, Meet, and similar macOS apps

Work:
- Replace the current virtual-camera stub with a Core Media I/O camera extension
- Feed reframed frames into the extension
- Add runtime diagnostics for publish state and dropped frames

Exit criteria:
- `CallDP Camera` appears as a selectable camera on macOS
- B can use the reframed feed in existing call apps

## Phase 5: Source Capture Headroom

Status: `Later`

Goals:
- Maximize reframing freedom by capturing the widest usable built-in camera source on each Mac
- Make source headroom visible so crop behavior is explainable and debuggable

Work:
- Inspect available built-in camera devices and formats instead of relying only on a generic session preset
- Choose the widest practical format for the current hardware
- Surface source-format details in the app:
  - resolution
  - selected format
  - crop size
  - effective zoom
  - remaining pan headroom
- Keep the framing controller independent from the capture-device decision

Exit criteria:
- The app can report which source format it is using
- The agent preview can use the widest practical built-in camera source
- Manual pan range matches the available source headroom instead of whatever the default camera preset happened to provide

## Phase 6: Real AI Backends

Status: `Next`

Goals:
- Replace simulation and stub components with production-capable perception components

Work:
- Replace stub transcription with Apple speech input
- Replace stub grounding with an open-vocabulary detector backend
- Replace stub tracking with a real tracker plus reacquisition logic
- Preserve mockable interfaces and simulation mode for testing

Delivered so far:
- Apple speech transcription backend
- Vision-based tracking backend
- speech/microphone permission wiring in the app host
- local Python grounding worker boundary
- first model-backed grounding backend mode using a Hugging Face zero-shot object detector

Remaining work:
- persistent grounding worker lifecycle instead of one process per request
- dependency/install workflow for the model backend
- stronger handling for ambiguous natural-language commands
- performance hardening and fallback strategy for Intel versus Apple Silicon

Exit criteria:
- Spoken commands reliably become structured actions
- Natural-language target requests can lock onto real objects
- Tracking and reacquisition behave consistently enough for live use

## Phase 7: Product Hardening

Status: `Later`

Goals:
- Make the product usable outside the dev environment

Work:
- Improve error states and operator guidance
- Add packaging, signing, and install flow
- Add diagnostics, structured logs, and performance tuning
- Add Intel-versus-Apple-Silicon backend fallback strategy where needed

Exit criteria:
- A non-developer can install and run the product on macOS
- Failures are visible and recoverable

## Immediate Next Slice

Build these in order:

1. Validate and harden the new local grounding backend behind `GroundingEngine`
2. Keep the current Apple speech + Vision tracking path in place
3. Preserve simulation mode as a fallback and debugging tool
4. After grounding is stable enough, return to:
   - transport hardening
   - CMIO virtual camera output
   - source-headroom optimization

That is the shortest path from the current hybrid AI prototype to a product that can actually lock onto named real-world objects predictably.
