# Notes

Pinned versions (Pop!_OS 24.04, 2026-11-07):

| package             | installed version                     | git rev   |
|---------------------|---------------------------------------|-----------|
| `cosmic-comp`       | `0.1~1765324739~24.04~fa88002`        | `fa88002` |
| `cosmic-workspaces` | `0.1.0~1765315332~24.04~954a45c`      | `954a45c` |

Latest published (2026-11-08, tested in a VM, see below):

| package             | version                               | git rev   |
|---------------------|---------------------------------------|-----------|
| `cosmic-comp`       | `0.1~1793802426~24.04~ec674cd`        | `ec674cd` |
| `cosmic-workspaces` | `1.0.12~1790783807~24.04~cb953ea`     | `cb953ea` |

Patches live in `patches/cosmic-workspaces/<rev>/`; `scripts/overview-swipe.sh
build` picks the directory matching the installed revision.

## Finding: the fix belongs in `cosmic-workspaces`, not `cosmic-comp`

- `Super+W` runs `WorkspaceOverview: "cosmic-workspaces"`
  (`/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions`).
  The overview is a separate client
  ([cosmic-workspaces-epoch](https://github.com/pop-os/cosmic-workspaces-epoch)),
  a full-screen layer-shell surface with namespace `cosmic-workspace-overview`.
- While that surface exists, `cosmic-comp` draws **only layer-shell surfaces**
  (`ElementFilter::LayerShellOnly` in `src/backend/render/mod.rs`); the
  windows you see are screencopy captures drawn by the overview client.
  So cosmic-comp's own workspace-slide animation would be invisible anyway.
- `cosmic-comp` turns off its workspace swipe on purpose while the overview is
  open: commit `7acfa10b` "Disable workspace change gestures when workspaces
  overview is open — *without animation between workspaces, the behavior is a
  bit jarring*". `src/input/mod.rs`, `InputEvent::GestureSwipeBegin`:
  `if event.fingers() >= 3 && !workspace_overview_is_open(..)`.
- In that case the `else` branch **forwards** the swipe to the client under
  the pointer (`pointer.gesture_swipe_begin/update/end`, i.e.
  `zwp_pointer_gestures_v1`). That client is the overview. It never bound
  pointer gestures, so the events were dropped. → **No compositor patch is
  needed**; the overview just has to listen and animate.
- iced/winit (libcosmic `3b8ad45`) don't expose touchpad gestures on Wayland.
  But the overview's Wayland thread (`src/backend/wayland/mod.rs`) runs on
  `Connection::from_backend(..)` of iced's own connection, i.e. the **same
  Wayland client**, so it can create its own `wl_pointer` + swipe gesture
  object and receive the gestures that land on the overview's surfaces.

## The overview patch (`patches/cosmic-workspaces/954a45c/`)

- `backend/wayland/mod.rs`: bind `zwp_pointer_gestures_v1`; for each seat
  with a pointer, `get_pointer` + `get_swipe_gesture`; forward
  begin/update/end as `backend::Event::Swipe`.
- `swipe.rs` (new): the gesture model.
  - Position in "pages" (fractional workspace index).
  - Same units as cosmic-comp: 150 touchpad units = one workspace;
    natural-scroll setting honoured (read from `CosmicComp` config).
  - Axis lock after 4 units; only the workspace axis (horizontal layout →
    horizontal swipe, vertical → vertical) moves the strip.
  - Rubber band past the first/last workspace.
  - Release: velocity over the last 150 ms, projected ~0.33 s ahead,
    rounded, at most one workspace past where the fingers are.
  - Settle: critically damped spring starting at the release offset **and
    velocity**, so the motion continues smoothly. Grabbing again mid-settle
    continues from where it is on screen.
- `widgets/workspace_strip.rs` (new): lays out the (≤2) visible workspace
  pages at full size, shifted by a fractional offset.
- `view/mod.rs`: while a swipe/settle is running on that output, show the
  strip instead of only the active workspace.
- `main.rs`: state, 8 ms ticks only while settling, capture toplevels of the
  workspaces next to the active one so they're ready when a swipe starts,
  activate the target workspace on release.
- 3 or 4 fingers both work inside the overview. Outside the overview nothing
  changes (cosmic-comp keeps handling the swipe itself).

## Port to the latest release (`patches/cosmic-workspaces/cb953ea/`)

- Checked on 2026-11-08 in a Pop!_OS 24.04 VM fully upgraded to the latest
  packages (kernel 7.2.15, `cosmic-comp ec674cd`, `cosmic-workspaces cb953ea`,
  which is upstream `main` at that date). Stock behaviour is unchanged: a
  touchpad swipe switches workspaces outside the overview, and does nothing
  inside it. `cosmic-comp` still skips its own swipe when the overview is
  open (`src/input/mod.rs`, `workspace_overview_is_open`) and the overview
  still never binds pointer gestures.
- `0001` is the original patch rebased; `0002` adapts it to the newer
  libcosmic/iced:
  - `Widget::on_event` became `update` (no `event::Status`), and `layout` /
    `operate` take `&mut self` (`widgets/workspace_strip.rs`).
  - `widget::Space::new()` is a builder now; `cosmic_theme::Theme::background`
    is a method taking `transparent: bool`.
  - The layer surface is created through `cosmic::surface` /
    `simple_layer_shell` with `LiveSettings`; the negative margin goes into the
    `SctkLayerSurfaceSettings` returned by its closure.
  - Upstream now passes `window_id` + a `RectangleTracker` through the view
    functions; the strip pages pass them on to `toplevel_previews`.
- Verified in the VM with the laptop touchpad passed through
  (`virtio-input-host-pci`): vertical layout, 4 fingers, the strip follows the
  fingers and lands on the right workspace (debug log: `swipe begin ...
  visible=true` / `swipe end ... -> target N`). Unit tests pass.
- **Crash found and fixed (`0004`)**: with windows on several workspaces the
  patched overview died on open with `ext_image_copy_capture_session_v1`
  error 1, "create_frame sent before the previous frame was destroyed"
  (`WAYLAND_DEBUG=client` showed frame #116 `ready`, the next
  `create_frame` 0.6 ms later, and the `destroy` of #116 0.3 ms after
  that). It is an upstream race: cctk destroys the frame only after the
  `ready` / `failed` handler returns, but `screencopy.rs` requests the next
  capture from the thread pool (`ready`, immediately when there is no
  buffer release to wait for) or from inside the handler (`failed` with
  `BufferConstraints`). Stock hits it less because it captures fewer
  windows; the swipe also captures the neighbouring workspaces. Fix: the
  thread pool sends the capture back to the Wayland thread through a
  calloop channel, so `create_frame` is always processed after the destroy.
  Verified: overview opened 5/5 times with 3 windows on 3 workspaces (it
  crashed every time before). Worth its own upstream PR.
- **Negative-margin workaround**: re-checked with a build that can switch
  it off (`OVERVIEW_SWIPE_NO_OVERFLOW=1`, test-only). With `cosmic-comp
  ec674cd`, a synthetic swipe (`mousetouch demo-swipe down 50 4`) with a
  window preview half past the top edge leaves the sidebar and panel
  pixel-identical in every frame of a QMP screendump burst, with and
  without the workaround. So the bounding-box shift no longer happens
  (vertical layout tested; horizontal not, the VM stays vertical). For the
  upstream PR the workaround can likely be dropped.

## What did not work (and why)

- **Fixed "touchpad units per page"** (cosmic-comp uses 150): the protocol's
  deltas are *pointer-accelerated*. libinput 1.25's touchpad curve
  (`filter-touchpad.c`, `touchpad_accel_profile_linear`) ranges from ~0.09
  to ~1.4 (≈16x), so slow swipes barely moved and fast ones overshot. Fix:
  `swipe::Deaccel` inverts that curve (speed estimated over 40 ms) to get
  finger travel in mm; 60 mm = one workspace
  (`COSMIC_WORKSPACES_SWIPE_MM` to tune).
- **Direction**: first version read `natural_scroll` from the wrong place,
  then "always follow the fingers" broke mousetouch (Magic Mouse): it adapts
  its synthetic swipe to cosmic-comp's convention, so it came out reversed in
  the overview. Final: same rule as cosmic-comp's own workspace swipe
  (`input_touchpad.scroll_config.natural_scroll`, default false; natural =
  strip follows the fingers). Any device that works outside the overview
  works the same inside. To make a *touchpad* swipe-left go to the right
  workspace, enable natural scrolling for the touchpad in Settings (this
  also flips two-finger scrolling, as in cosmic-comp).
- **Honouring `cancelled` on swipe end**: libinput sets it whenever the
  finger count changes first (lifting fingers one by one), so nearly every
  swipe snapped back. Ignored now, like cosmic-comp does.
- **Velocity from stale samples**: pausing before lifting still "flung".
  Velocity is now 0 if the last sample is >50 ms before the end event.
- **Release feel**: a plain critically damped spring with the release
  velocity overshot on fast flicks and reversed on short flicks back
  ("rough bounce"). Now: velocity heading away from the target is dropped,
  and the spring stiffens to |v0|/|x0| (9-30 rad/s) so it lands without
  overshoot while keeping the release speed. Flings coast
  `velocity * 0.3 s` and may cross several workspaces; windows of every
  workspace the strip passes over are captured on the fly.
- **Empty workspaces**: all look the same (just wallpaper), so the motion
  was invisible. They now show a faint outline of an empty window.
- **Activating on release**: cosmic-comp adds/removes empty workspaces on a
  switch, reflowing the bar mid-animation. Activation now happens when the
  settle animation ends.
- **Widening the draw viewport for off-screen pages** (`viewport.union`):
  with wgpu's GLES backend this left the *whole* overview surface blank
  after a swipe (bar shrinking/ghosting, then nothing). Found by recording
  the screen, then reproducing with `mousetouch demo-swipe` + screenshots
  and an A/B (strip on/off). Children now get the parent's viewport.
- **Off-screen pages shifting the whole overview** (bar "moving and coming
  back" during a swipe): cosmic-comp positions layer surfaces with smithay's
  `LayerMap::layer_geometry()`, which is the surface tree's *bounding box*
  (subsurfaces included) offset by the layer location. A window preview
  (subsurface) sliding past the left edge has x < 0, so `bbox.loc.x < 0` and
  the whole layer surface is drawn shifted left by that amount. Confirmed by
  a mid-animation screenshot (shift == overhang of the left-most preview).
  Client-side fix: the overview's layer surface gets a negative left (top,
  for vertical layout) margin of one output width + 64 px and pads its
  content by the same amount, so no subsurface is ever at negative
  coordinates. Upstream cosmic-comp bug worth reporting: it should place the
  surface at the layer location, not at the bbox origin
  (`src/shell/focus/order.rs`, `layer_surfaces()`).
- **Testing**: `cosmic-session` supervises `cosmic-workspaces` and respawns it
  by name through its PATH (`~/.local/bin` first), so `try` drops a wrapper
  there; `pkill -x` never matches (15-char comm). After many quick restarts
  cosmic-session backs off and gives up; the next Super+W then starts it
  unsupervised (fine until next login). `systemctl --user set-environment`
  doesn't reach it; the wrapper sources `~/.config/cosmic-overview-swipe.env`.

## cosmic-comp patch: no wrap-around on swipe (`patches/cosmic-comp/`)

- Outside the overview, cosmic-comp's 4-finger swipe wraps from the last
  workspace to the first and vice versa: `to_next_workspace` /
  `to_previous_workspace` in `src/input/actions.rs` wrap on purpose, for
  both shortcuts and gestures.
- Patch: when `gesture == true` they return `InvalidWorkspaceIndex` at the
  ends instead of wrapping. `handle_swipe_action` ignores the error, so no
  `previously_active` is set and the swipe simply doesn't move.
  `Super+Ctrl+Left/Right` still wrap.
- Inside the overview the strip already stops at the ends (rubber band);
  the overview's own mouse-wheel switching (`Msg::OnScroll`, stock code)
  used `rem_euclid` to wrap and now clamps too.
- Install: `cosmic-session` starts `cosmic-comp` by name through the login
  PATH, so a copy in `/usr/local/bin` shadows the package; takes effect on
  the next login. Rollback = remove it (or `apt install --reinstall
  cosmic-comp` if `/usr/bin` was overwritten).

## Overview: selection follows the swipe

- The highlighted thumbnail in the workspace bar is the workspace nearest to
  the strip position (`round(pos)`), so it moves as soon as a swipe passes
  the halfway point, several times on a long/fast swipe. The real
  activation still happens when the animation settles.

## Known limitations / to verify

- Capture images are Wayland subsurfaces and can't be clipped, so a sliding
  page goes past the strip's padding up to the screen edge (by design it
  moves perpendicular to the workspace bar, so it never covers it).
- The overview surface is ~2x the output width (see the negative margin
  above); the extra half is transparent and off-screen.
- Which output a swipe applies to comes from the last `CursorEntered`
  layer surface (falls back to the first one). Single monitor: no issue.
- If cosmic-comp removes an empty workspace while settling, indices shift
  and the animation may jump one page.

## Status

- [x] Root cause found, patch written.
- [x] Builds; unit tests pass (strip paging, rubber band, accel inverse).
- [x] Verified with synthetic swipes (mousetouch) + screenshots: strip moves,
      lands, activates, overview intact after repeated swipes.
- [x] Tested on the live session (2026-11-07, works well) (`scripts/overview-swipe.sh try`, then
      `mousetouch demo-swipe left 40` or a real touchpad).
- [x] Still broken upstream (latest release, 2026-11-08); patch ported to
      `cb953ea` and tested in a VM with a real touchpad (vertical layout).
- [x] Fixed an upstream screencopy race that the swipe made visible (crash
      on open with windows on several workspaces).
- [x] Negative-margin workaround not needed with `cosmic-comp ec674cd`
      (vertical layout; horizontal not tested).
- [ ] Upstream PR to `pop-os/cosmic-workspaces-epoch` (fork branch
      `Devace-93/cosmic-workspaces-epoch:overview-swipe-cb953ea`).
