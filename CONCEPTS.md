# Concepts

This file tracks the technical concepts, protocols, and system building blocks used while CallDP is being built.

Use it for:
- understanding why a feature was implemented a certain way
- knowing which platform APIs are in play
- seeing which concepts are already in use versus planned for later

## Current Core Concepts

### Language-grounded reframing
- Natural-language commands are converted into structured control actions.
- Vision decides what object or region is relevant.
- Deterministic crop control decides how the frame should move.

### Deterministic crop controller
- The app treats reframing as movement of a crop window inside a larger source image.
- Crop movement uses explicit math:
  - dead zone
  - velocity limit
  - acceleration limit
  - damping
  - clamp-to-bounds
- This avoids per-frame LLM camera movement.

### Tracking state machine
- The app uses explicit tracking modes:
  - `idle`
  - `detecting`
  - `tracking`
  - `lost_target`
  - `reacquiring`
- State transitions are logged and surfaced in the UI.

### Same-app dual-role architecture
- The same macOS app runs in two roles:
  - `Director`
  - `Camera Agent`
- This keeps the product logic in one binary and allows same-machine testing before real networking.

## Current Platform APIs

### SwiftUI
- Used for the app shell, multiple windows, operator UI, and debug panels.

### AVFoundation
- Used for built-in camera capture through `AVCaptureSession`.
- The current prototype still uses a generic session preset rather than explicit source-format selection.
- Also used for microphone input permission and live audio capture for speech transcription.

### Combine
- Used for transport event streams and UI updates.
- Transport implementations publish session state, agent snapshots, and incoming commands.

### Network.framework
- Used for the first real two-Mac control-plane transport.
- The current implementation is a direct TCP connection, not a backend service.

### Speech
- Used for native speech recognition on macOS through `SFSpeechRecognizer`.
- The current real backend pass uses Apple speech for live voice commands while keeping the command parser deterministic.

### Vision
- Used for native object tracking on macOS through `VNTrackObjectRequest`.
- The current real backend pass uses Vision for frame-to-frame tracking after a target box has been selected or detected.

### Python inference worker
- Used for the first real model-backed grounding path.
- The current `Grounded` backend sends a downscaled JPEG frame plus candidate text queries to a local Python process.
- The Python worker runs a Hugging Face zero-shot object detection model and returns normalized bounding boxes plus confidences.
- The current implementation is one worker process per grounding request for simplicity; a persistent worker is still planned.

## Current Transport Concepts

### Loopback transport
- In-process transport for same-machine testing.
- Used to validate the role split and consent flow before adding networking.

### Network transport
- Direct Mac-to-Mac control transport using `Network.framework`.
- Intended for the crux of the product:
  - Director on Mac A
  - Camera Agent on Mac B

### Control plane vs media plane
- The current network implementation is only for control messages.
- It does not transport video or audio.
- Existing call apps remain the media plane until a virtual camera is added.

### Session semantics
- The transport layer preserves the same product semantics across loopback and network modes:
  - connect
  - pending consent
  - accept
  - pause
  - resume
  - disconnect

### Protocol shape
- Remote messages are structured, not free-form.
- Current transport messages carry:
  - role registration
  - session state
  - agent snapshots
  - director commands

## Current Interface Boundaries

### `RemoteCommandTransport`
- Shared transport abstraction for loopback and network implementations.
- Publishes:
  - session state
  - agent snapshots
  - incoming commands

### `AudioTranscribing`
- Boundary for live transcription input.
- Backed by either a stub transcriber or a native Apple speech transcriber.

### `CommandParsing`
- Boundary for converting transcripts into structured `DirectorCommand` objects.
- Currently backed by a heuristic parser.

### `GroundingEngine`
- Boundary for open-vocabulary object grounding.
- Backed by simulation in the lightweight paths and by a local Python worker in the `Grounded` backend mode.

### Grounding worker protocol
- Request:
  - one camera frame encoded as JPEG
  - target description
  - expanded candidate query list
  - score threshold and top-k settings
- Response:
  - ranked detection candidates
  - normalized bounding boxes
  - confidence scores
- Failure path:
  - worker launch/setup errors are surfaced in the Camera Agent and Director UI instead of being silently dropped

### `TrackingEngine`
- Boundary for target tracking and reacquisition.
- Backed by stub, simulation, or a native Vision tracker.

### `VirtualCameraPublishing`
- Boundary for publishing processed frames to a virtual camera.
- Currently stubbed.

## Planned But Not Yet Fully Implemented

### CMIO camera extension
- Needed so the Camera Agent's reframed output appears as a camera in FaceTime, Zoom, Meet, and similar macOS apps.

### Widest-source capture selection
- The product should capture the widest usable source first, then crop within it.
- This is important because pan freedom depends on source headroom, not just zoom math.

### Real AI backends
- local open-vocabulary grounding backend
- production-grade command parsing for ambiguous language
- production hardening of the native speech and tracking path

## Current Technical Direction

The product is being built in this order:

1. Local two-role proof of interaction
2. Real two-Mac command transport
3. First real AI backend slice:
   - Apple speech transcription
   - Vision tracking
   - simulated grounding retained temporarily
4. Model-backed grounding backend:
   - local Python worker
   - Hugging Face zero-shot object detection model
5. Virtual camera output
6. Source-format optimization and headroom visibility
