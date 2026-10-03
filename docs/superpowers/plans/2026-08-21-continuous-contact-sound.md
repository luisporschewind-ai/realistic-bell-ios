# Continuous Bell Contact Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add physically driven, highly realistic clapper-on-brass sliding sound for slow and fast circular shaking without changing the accepted bell geometry, clapper motion, impact counting, haptics, or modal impact character.

**Architecture:** `BellClapperSimulator` remains the only contact authority and emits a continuous `BellContactState` beside discrete `BellImpactEvent` values. A lock-free event stream carries contact state to the C11 DSP, where a deterministic surface-roughness profile produces micro-collision excitation that is injected into the existing middle and upper brass modes; no dry noise is mixed into output. Impact and sustained-contact excitation remain separate but share the same resonators.

**Tech Stack:** Swift 6, CoreMotion, AVFoundation `AVAudioSourceNode`, C11 atomics, modal synthesis, standalone Swift/C tests, Xcode iPhoneOS build.

**Spec:** `docs/superpowers/specs/2026-08-21-3d-bell-design.md`

## Global Constraints

- Preserve checkpoint commit `8d86d14` and tag `realistic-bell-baseline-v1`; do not rewrite or move the tag.
- Keep portrait orientation, accepted 3D geometry, camera, lighting, layout, clapper limits, collision count, and haptic behavior unchanged.
- `BellClapperSimulator` is the sole authority for contact and impact; audio must not read CoreMotion or infer a second collision path.
- Sound remains disabled by default and must not claim an audio session while disabled.
- Audio render remains 48 kHz, non-interleaved Float32, allocation-free, lock-free, file-I/O-free, and log-free.
- Surface roughness, envelopes, and event storage are preallocated before rendering starts.
- Sustained contact never increments collision count and never triggers haptics.
- Sample fallback continues to cover discrete impacts only; it must not synthesize fake rubbing.
- No dry white or pink noise may be mixed directly into final output.
- A missing contact update for more than 80 ms must release the contact source to silence.

---

### Task 1: Model continuous physical contact

**Files:**
- Create: `RealisticBell/Models/BellContactState.swift`
- Modify: `RealisticBell/Services/BellClapperSimulator.swift`
- Modify: `RealisticBell.xcodeproj/project.pbxproj`
- Create: `Tests/BellContactStateTests.swift`
- Modify: `Tests/BellClapperSimulatorTests.swift`

**Interfaces:**
- Consumes: existing `BellMotionInput`, `BellClapperState`, collision boundary, effective acceleration, and tangent velocity.
- Produces: `BellContactState` and `BellSimulationStep.contact`.

```swift
struct BellContactState: Equatable {
    let timestamp: TimeInterval
    let isTouchingWall: Bool
    let normalAcceleration: Double
    let tangentialSpeed: Double
    let contactDirection: SIMD3<Double>

    static func detached(timestamp: TimeInterval) -> BellContactState
    var isFinite: Bool { get }
}

struct BellSimulationStep: Equatable {
    let state: BellClapperState
    let contact: BellContactState
    let impact: BellImpactEvent?
}
```

- [x] **Step 1: Write failing contact-contract tests**

In `Tests/BellContactStateTests.swift`, construct one valid touching state and assert exact field preservation and `isFinite == true`. Construct states with `.nan` in timestamp, normal acceleration, tangential speed, and each direction component; assert `isFinite == false`. Assert `detached(timestamp: 2.5)` is non-touching with zero acceleration, zero speed, and fallback direction `(0, -1, 0)`.

- [x] **Step 2: Extend simulator tests before implementation**

Add these behavioral cases to `BellClapperSimulatorTests.swift`:

```swift
private static func testFreeMotionReportsDetachedContact()
private static func testBoundarySlidingReportsPhysicalContactState()
private static func testStaticWallContactHasLoadButNoTangentialMotion()
private static func testInvalidInputReturnsDetachedContact()
```

For boundary sliding, drive the existing circular/boundary scenario until `state.isTouchingWall` and assert:

```swift
precondition(step.contact.isTouchingWall)
precondition(step.contact.normalAcceleration >= 0)
precondition(step.contact.tangentialSpeed > 0)
precondition(abs(magnitude(step.contact.contactDirection) - 1) < 0.000_001)
```

Also count `BellImpactEvent` values before and after continued sliding and assert contact updates do not create extra impact events without a new qualifying normal impulse.

- [x] **Step 3: Run the tests and verify the missing-type failure**

```bash
swiftc -parse-as-library -module-cache-path /tmp/bell-contact-model-cache \
  Tests/BellContactStateTests.swift \
  RealisticBell/Models/BellContactState.swift \
  -o /tmp/bell-contact-model-tests
```

Expected before implementation: compilation fails because `BellContactState.swift` does not exist.

- [x] **Step 4: Implement the contact state and simulator output**

Create the model exactly as declared. In `BellClapperSimulator`, compute `normalAcceleration` from the positive outward component of the effective linear acceleration at the boundary, in `m/s²`; do not expose the angular acceleration currently used internally. Compute `tangentialSpeed` from cone-tangent velocity times clapper length. Every return path must include a contact value:

- valid free motion: `.detached(timestamp: input.timestamp)`;
- valid boundary motion: touching state with normalized contact direction;
- invalid/stale input: detached state at the incoming timestamp;
- reset: next step starts detached.

Do not change impact thresholds, restitution, cooldown, clapper direction, or tangent velocity.

- [x] **Step 5: Add the new model to the Xcode target and run both tests**

Compile/run `BellContactStateTests.swift`, then compile/run `BellClapperSimulatorTests.swift` with `MotionSample.swift`, `BellMotionInput.swift`, `BellClapperParameters.swift`, `BellContactState.swift`, `BellImpactEvent.swift`, `BellGeometryProfile.swift`, `BellConfig.swift`, and `BellClapperSimulator.swift`.

Expected: both executables print their `passed` message and exit `0`.

- [x] **Step 6: Commit the physical contact contract**

```bash
git add RealisticBell/Models/BellContactState.swift \
  RealisticBell/Services/BellClapperSimulator.swift \
  RealisticBell.xcodeproj/project.pbxproj \
  Tests/BellContactStateTests.swift Tests/BellClapperSimulatorTests.swift
git commit -m "功能：输出连续铃舌接触状态"
```

---

### Task 2: Add contact acoustics configuration and audio routing

**Files:**
- Create: `RealisticBell/Models/BellContactSoundProfile.swift`
- Modify: `RealisticBell/Services/BellAudioPlaying.swift`
- Modify: `RealisticBell/Services/BellAudioEngine.swift`
- Modify: `RealisticBell/Services/BellSampleAudioEngine.swift`
- Modify: `RealisticBell.xcodeproj/project.pbxproj`
- Create: `Tests/BellContactSoundProfileTests.swift`
- Modify: `Tests/BellAudioRoutingTests.swift`

**Interfaces:**
- Consumes: `BellContactState` from Task 1.
- Produces: `BellContactSoundProfile.smallBrassHandbell` and `update(contact:profile:)` across the audio facade.

```swift
struct BellContactSoundProfile: Equatable {
    let loadReference: Double
    let speedReference: Double
    let surfaceSamplesPerMeter: Double
    let excitationGain: Double
    let attackSeconds: Double
    let releaseSeconds: Double
    let timeoutSeconds: Double
    let firstExcitedModeIndex: Int

    static let smallBrassHandbell: BellContactSoundProfile
}

protocol BellAudioPlaying: AnyObject {
    func prepare() -> Bool
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool
    func update(contact: BellContactState, profile: BellContactSoundProfile)
    func stop()
}
```

- [x] **Step 1: Write failing profile tests**

Assert the reference profile has positive finite values, attack in `0.005...0.010`, release in `0.030...0.050`, timeout exactly `0.080`, and `firstExcitedModeIndex` inside the 12-mode bell profile. Use literal expected ranges, not production helpers.

- [x] **Step 2: Write failing routing tests**

Extend `FakePlayer` with captured contact updates. Assert:

- modal-active facade forwards each contact update to modal exactly once and never to sample fallback;
- sample-fallback facade sends no contact update to either renderer;
- contact updates never change `activeEngine`;
- `stop()` still reaches both renderers.

- [x] **Step 3: Run the tests and verify compilation fails**

Compile `BellContactSoundProfileTests.swift` with `BellContactSoundProfile.swift` and `BellModalProfile.swift`. Compile `BellAudioRoutingTests.swift` with the audio facade, routing policy, contact model, impact model, config, and clapper parameters.

Expected before implementation: missing type/method failures.

- [x] **Step 4: Implement profile and routing contract**

Use these initial physically scaled values in one place:

```swift
static let smallBrassHandbell = BellContactSoundProfile(
    loadReference: 9.80665,
    speedReference: 0.55,
    surfaceSamplesPerMeter: 1_400,
    excitationGain: 1.8,
    attackSeconds: 0.008,
    releaseSeconds: 0.040,
    timeoutSeconds: 0.080,
    firstExcitedModeIndex: 4
)
```

`BellAudioEngine.update` forwards only while `.modal` is active. `BellSampleAudioEngine.update` is an explicit no-op. Do not trigger fallback when a contact update is unavailable; sample fallback cannot represent this layer.

- [x] **Step 5: Run profile and routing tests**

Expected: both test executables print `passed` and exit `0`.

- [x] **Step 6: Commit the audio contract**

```bash
git add RealisticBell/Models/BellContactSoundProfile.swift \
  RealisticBell/Services/BellAudioPlaying.swift \
  RealisticBell/Services/BellAudioEngine.swift \
  RealisticBell/Services/BellSampleAudioEngine.swift \
  RealisticBell.xcodeproj/project.pbxproj \
  Tests/BellContactSoundProfileTests.swift Tests/BellAudioRoutingTests.swift
git commit -m "功能：定义持续接触声音接口"
```

---

### Task 3: Synthesize resonant surface micro-collisions in C11

**Files:**
- Modify: `RealisticBell/AudioDSP/BellModalDSP.h`
- Modify: `RealisticBell/AudioDSP/BellModalDSP.c`
- Modify: `Tests/BellModalDSPTests.c`

**Interfaces:**
- Consumes: ordered impact and contact updates plus `BellDSPContactProfile` at DSP creation.
- Produces: bounded modal output with no dry-noise path.

```c
typedef struct {
    double timestamp;
    bool is_touching_wall;
    float normal_acceleration;
    float contact_x;
    float contact_y;
    float contact_z;
    float tangential_speed;
} BellDSPContact;

typedef struct {
    float load_reference;
    float speed_reference;
    float surface_samples_per_meter;
    float excitation_gain;
    float attack_seconds;
    float release_seconds;
    float timeout_seconds;
    unsigned int first_excited_mode_index;
} BellDSPContactProfile;

bool BellModalDSPEnqueueContact(BellModalDSP *dsp, BellDSPContact contact);
```

Extend `BellModalDSPCreate` with `const BellDSPContactProfile *contact_profile`. Keep a single ordered SPSC event queue with an internal event kind so impact and contact ordering is deterministic.

- [x] **Step 1: Write failing contact-output tests**

Add literal-fixture tests for:

```c
test_detached_contact_produces_no_new_energy();
test_zero_load_or_zero_speed_produces_no_contact_energy();
test_contact_with_zero_gain_modes_has_no_dry_noise_output();
test_fast_slide_is_brighter_and_denser_than_slow_slide();
test_contact_updates_do_not_create_packet_boundary_clicks();
test_stale_contact_releases_after_eighty_milliseconds();
test_impact_tail_survives_contact_updates();
test_tangential_impact_excites_modes_without_dry_noise();
```

For the no-dry-noise case, create valid modes with gain `0`, enqueue a touching contact, render 4,800 frames, and assert every sample is exactly zero. For slow/fast comparison, use identical nonzero load and render one second; compare first-difference energy and require fast energy to exceed slow energy by at least 20%, while peak remains below `0.98`.

- [x] **Step 2: Run normal C tests and verify new tests fail**

```bash
clang -std=c11 -Wall -Wextra -Werror \
  Tests/BellModalDSPTests.c RealisticBell/AudioDSP/BellModalDSP.c \
  -I RealisticBell/AudioDSP -lm -o /tmp/bell-modal-contact-tests
/tmp/bell-modal-contact-tests
```

Expected: compilation or behavioral failure because contact synthesis is absent.

- [x] **Step 3: Replace dry transient with ordered contact events**

Introduce an internal tagged event containing either `BellDSPImpact` or `BellDSPContact`; retain release/acquire SPSC ordering. Remove `noise_left`, `noise_right`, and direct calls that add random samples to `left_sample`/`right_sample`. Map impact tangential energy into the existing upper modal excitation only.

- [x] **Step 4: Precompute deterministic multi-scale roughness**

Allocate a fixed `1024`-sample roughness table inside `BellModalDSP`. Fill it during creation using the existing deterministic xorshift generator, then smooth at two scales and remove DC. Rendering only reads/interpolates this table; it performs no allocation and does not regenerate randomness per contact packet.

- [x] **Step 5: Implement per-sample contact excitation**

Maintain continuous phase, previous roughness, smoothed load/speed/contact direction, envelope, and frames-since-update. Advance phase by:

```c
phase += tangential_speed * surface_samples_per_meter / sample_rate;
```

Linearly interpolate the circular roughness table. Convert positive high-passed roughness changes into micro-collision force, multiply by the smoothed load, speed-dependent brightness, envelope, and `excitation_gain`, then inject only into modes at or above `first_excited_mode_index`. Apply equal-power panning from contact direction. Do not add the source directly to final samples.

Use the configured attack/release coefficients. After `timeout_seconds * sample_rate` frames without a fresh valid contact packet, set the target to detached and release the envelope.

- [x] **Step 6: Run normal and sanitized DSP tests**

Run the normal executable, then compile with:

```bash
clang -std=c11 -Wall -Wextra -Werror \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  Tests/BellModalDSPTests.c RealisticBell/AudioDSP/BellModalDSP.c \
  -I RealisticBell/AudioDSP -lm -o /tmp/bell-modal-contact-sanitized
/tmp/bell-modal-contact-sanitized
```

Expected: `BellModalDSPTests passed`, finite bounded output, no sanitizer report.

- [ ] **Step 7: Commit the contact DSP**

```bash
git add RealisticBell/AudioDSP/BellModalDSP.h \
  RealisticBell/AudioDSP/BellModalDSP.c Tests/BellModalDSPTests.c
git commit -m "功能：合成铜铃持续接触微碰撞"
```

---

### Task 4: Connect contact physics to the real-time modal engine

**Files:**
- Create: `RealisticBell/Models/BellModalContact.swift`
- Modify: `RealisticBell/Services/BellModalAudioEngine.swift`
- Modify: `RealisticBell/Features/Bell/BellViewModel.swift`
- Modify: `RealisticBell.xcodeproj/project.pbxproj`
- Create: `Tests/BellModalContactMappingTests.swift`

**Interfaces:**
- Consumes: `BellContactState`, `BellContactSoundProfile`, and Task 3 C API.
- Produces: validated `BellDSPContact` packets at each motion update while modal audio is active.

- [x] **Step 1: Write failing mapping tests**

Define `BellModalContactPayload` mirroring the C fields. Test exact preservation of valid physical units, normalization of contact direction, clamping of negative acceleration/speed to zero, and safe detached fallback for any non-finite input.

- [x] **Step 2: Run tests and verify missing mapping failure**

Compile mapping tests with `BellContactState.swift` and the new mapping file. Expected: missing type/file failure.

- [x] **Step 3: Implement Swift-to-C mapping and engine update**

`BellModalAudioEngine.prepare` maps `BellContactSoundProfile.smallBrassHandbell` into `BellDSPContactProfile` and passes it to DSP creation. `update(contact:profile:)` validates/maps the state and calls `BellModalDSPEnqueueContact` only when ready and running.

Do not recreate the engine or allocate audio buffers on contact updates. If enqueue fails, drop that intermediate update; the 80 ms DSP timeout is the fail-safe.

- [x] **Step 4: Connect `BellViewModel` lifecycle**

In every handled motion sample, publish `step.state`, then—when sound is enabled—forward `step.contact` before handling any optional impact. Keep impact count/haptic/audio handling in `handleImpact` unchanged. On sound off, stop, background, or recovery, DSP destruction/reset provides the detached state; no contact source survives the engine lifecycle.

- [x] **Step 5: Run mapping, impact-pipeline, routing, and simulator tests**

Expected: all four executables print `passed`. The existing impact-pipeline and simulator tests still prove that only `BellImpactEvent` values update collision metrics, while routing tests prove contact updates do not invoke sample impact playback.

- [x] **Step 6: Run an unsigned iPhoneOS build**

```bash
xcodebuild -project RealisticBell.xcodeproj -scheme RealisticBell \
  -configuration Debug -sdk iphoneos \
  -derivedDataPath /tmp/realistic-bell-contact-derived \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`, no channel-count assertion path, no new concurrency warning.

- [ ] **Step 7: Commit application integration**

```bash
git add RealisticBell/Models/BellModalContact.swift \
  RealisticBell/Services/BellModalAudioEngine.swift \
  RealisticBell/Features/Bell/BellViewModel.swift \
  RealisticBell.xcodeproj/project.pbxproj \
  Tests/BellModalContactMappingTests.swift
git commit -m "功能：接通铃舌持续接触声音"
```

---

### Task 5: Full regression, documentation, and real-device handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-08-21-3d-bell-design.md` only if implementation behavior differs from the approved contract.
- Modify: `docs/superpowers/plans/2026-08-21-continuous-contact-sound.md`
- Modify: `README.md` with the real-device acoustic matrix.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: verified build and explicit real-device acceptance procedure.

- [x] **Step 1: Run all standalone tests from fresh compiles**

Run every existing Swift test plus the new contact model, profile, and mapping tests. Run normal and ASan/UBSan C DSP tests. Count every executable and record pass/fail; do not report partial success as complete.

- [x] **Step 2: Run a fresh unsigned iPhoneOS build**

Use a new `/tmp/realistic-bell-contact-final-derived` path and require `** BUILD SUCCEEDED **`.

- [x] **Step 3: Inspect real-time safety and source ownership**

Verify by source inspection that `BellModalDSPRender` contains no allocation, lock, logging, file I/O, or Swift callback. Search for contact inference and confirm only `BellClapperSimulator` constructs touching `BellContactState` values.

- [x] **Step 4: Update documentation status**

Mark automated implementation complete while leaving acoustic acceptance pending. Document that sample fallback has no sustained contact layer and that the baseline remains recoverable through tag `realistic-bell-baseline-v1`.

- [x] **Step 5: Commit verified implementation state**

```bash
git add README.md docs/superpowers/specs/2026-08-21-3d-bell-design.md \
  docs/superpowers/plans/2026-08-21-continuous-contact-sound.md
git commit -m "文档：记录持续接触声验证状态"
```

- [ ] **Step 6: Real-device acoustic acceptance**

With sound enabled, test built-in speaker and headphones using:

1. no motion and static wall contact — no sustained scrape;
2. slow circular motion — sparse, quiet, darker brass grains;
3. medium circular motion — denser but still irregular grains;
4. fast circular motion — brighter, dense brass contact without white-noise hiss;
5. transition slow → fast → slow — continuous timbral change without packet-boundary clicks;
6. detach and reverse — contact layer releases, then a true impact remains clear;
7. upright and inverted shaking — impacts, contact sound, visuals, count, and haptics remain physically consistent;
8. sound off and Music playback — the bell does not interrupt system music.

Record subjective findings separately from automated pass evidence. Tune only `BellContactSoundProfile.smallBrassHandbell`; do not change accepted geometry or collision physics to compensate for sound.
