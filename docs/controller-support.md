# Controller support

| Input | Action |
| --- | --- |
| Left stick | Move |
| Right stick | Aim directly; stick magnitude sets attack distance |
| R2 / RT | Part-pull to aim; cross 95% to dash; release to reset |
| R1 / RB or mouse attack | Hold to aim, release to dash |
| L2 / LT or L1 / LB | Hold slow motion |
| Options / Start | Pause or resume |
| D-pad / left stick | Navigate menus |
| Cross / A (south) | Select |
| Circle / B (east) | Back or resume from pause |
| Triangle / Y (north) | Restart room |

The right stick uses the input map's radial deadzone. At the outer edge, the
attack reaches `DashComponent.max_distance`, subject to walls. A partial tilt
gives a shorter attack. Returning the stick to centre retains the last aim and
distance. Controller aiming does not use or move the virtual mouse cursor.

Settings fields and their text labels enlarge together on focus. Left/right adjusts sliders; up/down moves
between fields. Settings subpages retain focus and return it to their opener.
The right stick scrolls the credits and licenses. Settings > Controller has
vibration strength and trigger strength, independent off settings at zero, and test
buttons. The R2 test lasts three seconds and stops when leaving the page.

Desktop feedback uses Godot's standard vibration API. Web feedback uses the
browser Gamepad API through `JavaScriptBridge`, since Godot 4.7's web input
backend does not forward standard joypad vibration calls. Where advertised by
the browser/controller, attack feedback includes trigger rumble; otherwise it
falls back to ordinary rumble. Missing or denied haptics are ignored without
affecting controls.

## DualSense resistance

The bow tension is inspired by [Ghost of Tsushima's DualSense support](https://blog.playstation.com/2024/03/06/ghost-of-tsushima-directors-cut-is-coming-to-pc-on-may-16/).
The 95% firing point and recoil below are our own tuning and control scheme;
they are not a reproduction of Sucker Punch's proprietary haptic profile.

R2 starts aiming at 20% travel. Crossing 95% activates the existing dash attack
and consumes one stored arrow immediately, without waiting for release. A
pull that returns below 12% before firing cancels aiming and slow motion. Once
fired, R2 must return below 12% before it can fire again, preventing repeated
shots from holding it down or fluctuating near the firing point. Mouse and R1
retain hold-to-aim, release-to-dash controls. Attacks are consumed in the render
update alongside aim queries so slow motion does not delay the firing point.

The trigger profile is preloaded as soon as attacks are available. Resistance
builds to maximum across the latter part of the pull, including the final
hardware zone. Crossing the 95% input threshold switches it to the shot recoil
sequence below. Strength defaults to 100%. There is no trigger tension without
an available attack, or after recoil ends while the trigger remains held.

At a successful R2 shot, both triggers immediately receive the automatic-trigger
vibration command used by [DualSense Tester](https://github.com/daidr/dualsense-tester/blob/main/src/router/DualSense/views/_OutputPanel/TriggerEffect.vue):
mode 0x06, frequency parameter 10, force 255 at 100% strength, and start position
20. It runs for 260 ms, then turns off. There is no initial static-resistance
phase. Lower trigger strength scales the force byte, independently of body rumble.
L2 has no resistance while drawing. A finger lightly depressing L2 can feel its
active pushback; this does not command a released trigger to pull itself inward.

macOS and WebHID send identical trigger-effect bytes directly. The native path
uses non-exclusive IOHID access rather than converting frequency through Apple's
GameController API. Only the two trigger update flags are set, leaving body
motors, LEDs, microphone and audio routing to their existing owners. This is a
legacy effect supported by the open-source tester; firmware support can vary.
A successful HID write confirms delivery, not measured force or visible movement.

Body recoil starts at full strength for 120 ms, keeps the low-frequency motor
at maximum for another 100 ms, then fades through a 100 ms tail. Before the
shot, progressive body rumble begins at 55% pull. Timings use real time, even
in slow motion. Recoil also works on the last available attack. A new draw
replaces an unfinished recoil tail; cancellation discards delayed feedback.
The trigger and body effects respect their separate strength settings.

The three-second R2 settings test uses the same 95% firing point, paired kick
and reset latch. Lightly hold L2 while pulling R2 to test the left pulse. Backing off before the threshold does not produce a shot effect. Pause,
focus loss, death and disconnection cancel feedback and require a fresh pull.
Native and web backends expire the kick locally after 260 ms, checked every
20 ms; sustained resistance has a separate one-second heartbeat timeout.

macOS 12.3+ uses an optional, local GDExtension and IOKit HID access
inside the game process. Build it with Xcode Command Line Tools installed:

```sh
sh native/dualsense/build-macos.sh
```

Restart the game after building. The universal library supports Apple silicon
and Intel. Generated binaries are ignored by Git. The extension is loaded only
on macOS; missing binaries leave ordinary controls and vibration available.
Native Windows and Linux builds currently have ordinary vibration only.

For Web exports, Settings > Controller > Connect DualSense opens a browser
connection prompt. The user must click its button with a mouse and select their
controller. The bridge uses WebHID for DualSense and DualSense Edge, with USB
and Bluetooth output framing. It writes R2 tension and recoil on both triggers,
leaving LEDs, audio routing and microphone state untouched. No companion app
is needed.

WebHID needs a secure context and a supporting desktop browser such as Chrome
or Edge. Safari and Firefox fall back to ordinary controls. An itch.io iframe
also needs the host to delegate the `hid` permission. The game detects a denied
policy and explains that a standalone browser build is needed; it cannot grant
itself the parent page's permission. A browser permission cancellation never
blocks normal gameplay. The Web export does not include the native library.

Pause, death, scene exit, device changes, focus loss and a zero resistance
setting release the trigger. Native and web backends have a one-second
heartbeat timeout. Pending browser writes cannot reapply an old effect after
reset. Only one DualSense should be connected when testing native resistance.

Feedback stops on pause, loss of focus, disconnection and scene exit. Pausing
also cancels a prepared attack so returning to the game cannot fire it.

## Checks

After importing the project:

```sh
godot --headless --path . res://tests/controller_support.tscn
godot --headless --path . res://tests/draw_feedback.tscn
node tests/web_haptics_test.cjs
node tests/adaptive_triggers_test.cjs
```

The Godot check injects controller input through the normal event path and
tests analog aim distance, attack release, pause cancellation and menu focus.
The feedback check verifies preloading before input, increasing motor strength,
threshold firing, trigger kick duration, recoil decay, slow-motion independence,
last-charge release, rapid redraw and cancellation.
The JavaScript checks exercise the browser bridge with simulated actuators and
HID devices, including packet encoding, Bluetooth CRC, permission failures,
pending writes, focus loss and the watchdog.

On macOS, test the native effect sequence without driving a physical controller:

```sh
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -mmacosx-version-min=12.3 \
  -framework Foundation -framework IOKit tests/native_recoil.m \
  -o /tmp/arrow-head-native-recoil-test
/tmp/arrow-head-native-recoil-test
```

This runs the actual native timer and report encoder against a simulated HID
transport, checking paired force bytes, expiry, strength, CRC and cancellation.

For a connected physical DualSense on macOS, run the native round-trip check:

```sh
godot --path . res://tests/native_trigger.tscn
```

This checks the controller-reported effect mode, including reset after release
and watchdog expiry. It requires a real connection, not only a paired device
listed by the operating system. The current local implementation has passed
software checks; physical resistance and its feel still require a playtest.
The native export must bundle `dualsense.gdextension` and its signed library at
the paths specified there; this checkout's export preset is Web only.

Protocol references: [DualSense HID reports](https://github.com/nondebug/dualsense),
[trigger effect encoding](https://gist.github.com/Nielk1/6d54cc2c00d2201ccb8c2720ad7538db),
[Apple adaptive triggers](https://developer.apple.com/documentation/gamecontroller/gcdualsenseadaptivetrigger),
and [WebHID permissions](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy/hid).
The vendored GDExtension header is the unmodified Godot 4.4 stable ABI header,
compatible with this project's newer Godot version; its MIT notice is retained.

Before shipping, test a physical controller in the itch.io embed: click/focus
the game once, press a controller button, check movement and attack distance,
pause while holding attack, navigate all settings and subpages, and unplug the
controller during play. Test vibration on each intended browser and connection
type; its availability depends on both the browser and controller.
