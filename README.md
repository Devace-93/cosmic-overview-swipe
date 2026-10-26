# cosmic-overview-swipe

Continuous, finger-following left/right swipe **inside the COSMIC workspace
overview** on Pop!_OS 24.04.

## The problem

On Pop!_OS 24.04 (COSMIC), open the workspace overview (`Super+W`). While it
is open, a horizontal touchpad swipe does nothing: you only see the current
workspace. This is true with the laptop's native touchpad, so it is not a
device or driver issue, it is compositor behaviour (`cosmic-comp`).

On macOS, in Mission Control, a horizontal swipe keeps moving between
desktops, and the motion follows the fingers (continuous, not a discrete
"jump one workspace" step).

## Goal

Make a horizontal swipe work while the COSMIC overview is open:

1. **Continuous**: the workspace strip follows the fingers while they move,
   pauses when they pause, goes back when they go back, and settles with the
   release velocity. Not a discrete "swipe = next workspace" keybinding.
2. **Any touchpad**: libinput touchpad swipe gestures (3 or 4 fingers, same
   as the out-of-overview workspace swipe). Devices that already emit
   synthetic touchpad swipes (e.g. [mousetouch](https://github.com/Devace-93/magic-mouse-gestures)
   for the Magic Mouse) then work for free.
3. Outside the overview nothing changes.

## Where to look

- `cosmic-comp` (System76, Rust/Smithay): https://github.com/pop-os/cosmic-comp
  - The overview is the "workspace overview" / "ToggleOverview"-style mode in
    the shell. Find where its state lives and how input is routed while it is
    active.
  - Workspace swipe handling: search for the Smithay gesture events
    (`GestureSwipeBegin` / `GestureSwipeUpdate` / `GestureSwipeEnd`) and for
    how the normal 4-finger workspace swipe drives the workspace animation.
    The likely fix is to route those same events to the overview's layout
    while it is open, instead of dropping them.
  - Check whether the overview already reacts to anything horizontal (mouse
    wheel, `Super+Ctrl+Left/Right`), which shows how it changes workspace.
- COSMIC on Pop!_OS 24.04 ships `cosmic-comp` from the `cosmic-epoch`
  packaging; check which git revision the installed package matches
  (`apt show cosmic-comp`, `dpkg -L cosmic-comp`) and build against that tag
  so the patch applies cleanly.
- Smithay docs for touchpad gestures: https://docs.rs/smithay (look for
  `GestureSwipeBeginEvent` and friends in `backend::input`).

## Suggested approach

1. Reproduce: confirm the behaviour on the installed version and note the
   `cosmic-comp` version.
2. Clone `cosmic-comp` at that revision, build it (`cargo build --release`),
   and figure out how to test without replacing the live session: cosmic-comp
   supports running nested as a window in an existing session for
   development; verify how in its README. Mousetouch's `demo-swipe left 40`
   can inject a synthetic 4-finger swipe for testing when no touchpad is at
   hand.
3. Prototype the change in a fork; keep it as a small, reviewable patch so it
   can be proposed upstream.
4. Deliver, in this repository:
   - `patches/` with the change against the pinned revision, and a build +
     install/rollback recipe for Pop!_OS 24.04 (so the stock package can be
     restored with one `apt` command).
   - Notes on what did and did not work (file paths, functions, why).
   - If upstream accepts it, a link to the PR.

## Non-goals

- Changing anything in the Magic Mouse driver. If a device cannot produce
  touchpad swipe gestures, that is a separate project.
- Replacing the discrete keybindings; they keep working.

## License

MIT
