# Where a stable CPU package temperature comes from

Research for [Where a stable CPU package temperature
comes from](https://github.com/bhdai/quickshell_config/issues/140), performed on 2026-08-08.
Part of [#135](https://github.com/bhdai/quickshell_config/issues/135).

## Executive answer

**Resolve the channel once per process with a single `sh -c`, then read a plain `FileView`
every tick.** The resolution costs ~4 ms of wall clock, once, at startup. Nothing cheaper
exists, and nothing more expensive is justified.

Six findings decide it, all verified on this machine:

1. **The package channel is identified by its `_label`, never by its index.** On this
   machine it is `/sys/class/hwmon/hwmon7/temp1_input`, whose `temp1_label` reads
   `Package id 0`. `coretemp` computes the index as `is_pkg_temp_data(tdata) ? 1 :
   tdata->cpu_core_id + 2`, so `temp1` is the package *only when a package sensor exists*
   — pre-Sandy-Bridge Intel has none and `temp1` is simply absent. The indices are not
   contiguous either: this CPU exposes `temp1, temp2, temp6, temp10…temp17` and nothing
   else. **Read labels; do not count.**
2. **The unit is millidegree Celsius**, stated verbatim by the hwmon ABI. `temp1_input`
   read `55000` while `sensors` reported `Package id 0: +55.0°C`. Divide by 1000.
3. **There is no stable symlink that sidesteps resolution.** The *device* half of the path
   is stable (`/sys/devices/platform/coretemp.0/`) but the hwmon leaf under it is still
   `hwmon7` — the same globally-allocated index. hwmon names come from `ida_alloc` in
   registration order (`drivers/hwmon/hwmon.c:918,985`), and on this laptop `coretemp`
   registers *after* an iwlwifi firmware load, i.e. behind an asynchronous race.
4. **`FileView` cannot glob.** `path:
   "/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input"` fails with
   `FileViewError.FileNotFound`. It *does* follow symlinks transparently — the
   `/sys/class/hwmon/hwmon7` symlink and a hand-made `/tmp` symlink both read fine.
5. **`watchChanges` does nothing on sysfs.** A `FileView` with `watchChanges: true` on
   `temp1_input` emitted **zero** `fileChanged` signals across 12 seconds while the value
   moved from 55000 to 63000. Polling with `reload()` is the only option.
6. **The `reload()`-then-`text()` pattern in `ResourceUsage.qml` is one tick stale.**
   Verified: reads are async by default, so `text()` immediately after `reload()` returns
   the previous value. A raw sysfs read costs **7.7 µs** — half of `/proc/stat`'s 15.5 µs,
   which this service already reads every tick — so `blockAllReads: true` is the correct
   setting and costs nothing measurable.

**Recommended fallback chain: `coretemp` → `k10temp` → `acpitz` → nothing.** When nothing
resolves, the service property must read **`null`**, not `0`, so the QML tab can hide or
grey the card. `thinkpad`'s `temp1_label: CPU` is a **trap** — see §4.

## Evidence and confidence labels

- **Verified locally** — I ran it on this machine (`13th Gen Intel Core i7-1365U`, Linux
  `6.18.41-1-lts`, `quickshell 0.3.0-2`) on 2026-08-08, or read it out of the installed
  `quickshell-io.qmltypes`.
- **Verified in source** — read from the Linux kernel tree at
  `github.com/torvalds/linux` (`drivers/hwmon/coretemp.c`, `drivers/hwmon/hwmon.c`,
  `drivers/hwmon/k10temp.c`) or from kernel `Documentation/`.
- **Documented** — stated by `quickshell.org/docs/v0.3.0` or by kernel
  `Documentation/`/`ABI`.
- **Inferred** — follows from the above but was not reproduced here.

The Quickshell behaviour in §3 was established by running a throwaway probe config under
`QT_QPA_PLATFORM=offscreen` with no compositor, the same harness
`tests/brightness-without-ddcutil.sh` uses. Its results are quoted verbatim.

## 1. Which node carries the package temperature

### This machine, enumerated

`/sys/class/hwmon/hwmon7` (`name` = `coretemp`), **verified locally**:

| node | `_label` | `_input` | `_max` | `_crit` |
| --- | --- | --- | --- | --- |
| `temp1` | **`Package id 0`** | 55000 | 100000 | 100000 |
| `temp2` | `Core 0` | 51000 | 100000 | 100000 |
| `temp6` | `Core 4` | 50000 | 100000 | 100000 |
| `temp10`…`temp17` | `Core 8`…`Core 15` | 53000–55000 | 100000 | 100000 |

Every channel also carries `_crit_alarm`, which was `0` throughout.

Cross-checked with `sensors coretemp-isa-0000`, which prints `Package id 0: +49.0°C (high
= +100.0°C, crit = +100.0°C)` — the same three numbers, taken a moment later.

### Why the numbering looks like that

**Verified in source**, `drivers/hwmon/coretemp.c`, `create_core_attrs()`:

```c
int attr_no = is_pkg_temp_data(tdata) ? 1 : tdata->cpu_core_id + 2;
```

and `show_label()`:

```c
if (is_pkg_temp_data(tdata))
	return sprintf(buf, "Package id %u\n", pdata->pkg_id);

return sprintf(buf, "Core %u\n", tdata->cpu_core_id);
```

The index is a *function of the hardware core id*, not a counter. The i7-1365U has two
P-cores with core ids 0 and 4 and eight E-cores with ids 8–15, which is exactly the
`2, 6, 10…17` set observed. **There is no rule that says the numbers start at 1 or run
consecutively**, and the hwmon interface spec says so directly
(`Documentation/hwmon/sysfs-interface.rst:50-55`):

> Numbering usually starts from 1, except for voltages which start from 0 (because most
> data sheets use this). A number is always used for elements that can be present more
> than once, even if there is a single element of the given type on the specific chip.

### Why `temp1` is not a safe assumption

Three cases break it, all **verified in source or documentation**:

- **Pre-Sandy-Bridge Intel has no package sensor.** `Documentation/hwmon/coretemp.rst:35-37`:
  the package sensor is "available on Sandy Bridge and all newer processors". Without it
  there is no `temp1` at all and the lowest channel is `temp2` = `Core 0`.
- **`k10temp` numbers by meaning, not by aggregation level.** `temp1` is `Tctl`, `temp2` is
  `Tdie`, `temp3…10` are `Tccd1…8`. `Tctl` is explicitly *not* a physical temperature (§4).
- **Multi-socket machines get one hwmon per package** (`coretemp.0`, `coretemp.1`, …), each
  with its own `Package id N`. **Inferred** from the platform-device naming; not reproduced,
  and out of scope for a laptop, but it means "the package temperature" is per-chip.

The label contract is stated by the driver docs (`coretemp.rst:58-60`):

> `tempX_label` Contains string "Core X", where X is processor number. For Package temp,
> this will be "Package id Y", where Y is the package number.

and by the generic ABI (`Documentation/ABI/testing/sysfs-class-hwmon`, `tempY_label`):

> Suggested temperature channel label. … Should only be created if the driver has hints
> about what this temperature channel is being used for, and user-space doesn't.

### One free bonus: `_crit`

`temp1_crit` is 100000 (= 100 °C), documented as "Maximum junction temperature"
(`coretemp.rst:55`). #135 lists "colour semantics for a metric under pressure" as not yet
specified; the driver hands us a per-machine threshold for nothing. Resolve it in the same
one-shot and the tab gets `temp / crit` as a real proportion instead of a hardcoded 80 °C.

## 2. What unit it reports

**Millidegree Celsius.** `Documentation/ABI/testing/sysfs-class-hwmon`, verbatim:

```
What:		/sys/class/hwmon/hwmonX/tempY_input
Description:
		Temperature input value.

		Unit: millidegree Celsius

		RO
```

`tempY_crit` and `tempY_max` carry the identical `Unit: millidegree Celsius` line.

**Verified locally**, at one instant:

| raw | converted |
| --- | --- |
| `temp1_input` = `55000` | 55.0 °C |
| `temp1_crit` = `100000` | 100.0 °C |

The underlying resolution is coarser than the unit suggests —
`coretemp.rst:39-41` says "measurement resolution is 1 degree C", and the driver computes
`tjmax - ((val.l >> 16) & 0xff) * 1000`, so the last three digits are always zero on this
driver. Formatting to one decimal place would display a digit that is always `0`. Round to
a whole degree.

There is one documented exception to the unit, which does not apply here: chips reading
external thermistors report **millivolt** instead
(`sysfs-interface.rst:308-315`). No CPU driver does this.

### `coretemp` self-caches at exactly 1 Hz

**Verified in source**, `show_temp()`:

```c
	/* Check whether the time interval has elapsed */
	if (time_after(jiffies, tdata->last_updated + HZ)) {
		rdmsrq_on_cpu(tdata->cpu, tdata->status_reg, &val.q);
```

The MSR is re-read at most once per second per channel; reads in between return the cached
value. The map's "1s always" cadence lands exactly on the driver's own refresh granularity
— polling faster buys nothing, and a reading may be up to 1 s old. Worth knowing for the
plot: the temperature series is genuinely 1 Hz data, not a smoothed 1 Hz sample of
something faster.

## 3. Resolving the directory

### The index is a global allocation counter

**Verified in source**, `drivers/hwmon/hwmon.c`:

```c
static DEFINE_IDA(hwmon_ida);
...
	id = ida_alloc(&hwmon_ida, GFP_KERNEL);
...
	dev_set_name(hdev, HWMON_ID_FORMAT, id);
```

The number in `hwmonN` is whatever the IDA handed out when that device registered, across
*all* hwmon providers in the system. **Verified locally**, this boot's ten registrations
come from seven unrelated subsystems:

| index | name | backing device |
| --- | --- | --- |
| 0 | `AC` | `power_supply/AC` (ACPI) |
| 1 | `acpi_fan` | `platform/PNP0C0B:00` |
| 2 | `acpitz` | `virtual/thermal/thermal_zone0` |
| 3 | `BAT0` | `power_supply/BAT0` (ACPI) |
| 4 | `nvme` | `pci…/nvme/nvme0` |
| 5 | `thinkpad` | `platform/thinkpad_hwmon` |
| 6 | `iwlwifi_1` | `virtual/thermal/thermal_zone7` |
| **7** | **`coretemp`** | **`platform/coretemp.0`** |
| 8, 9 | `ucsi_source_psy_USBC000:00{1,2}` | `platform/USBC000:00` |

`coretemp` is index 7 because six other things won the race. `coretemp` is a loadable
module here (`lsmod` shows `coretemp 24576 0`, refcount 0, not in `modules.builtin`), and
`hwmon6` is `iwlwifi_1`, which only appears once iwlwifi has loaded firmware — the kernel
log shows that firmware load two seconds after the thermal zones registered. **Inferred:**
`coretemp`'s index depends on the outcome of an asynchronous module-load and
firmware-load race, so it is not something to hardcode. I did not observe the index
actually differing across boots — hwmon indices are not written to the journal, and I did
not unbind the driver on the user's live machine to force a reallocation.

**Within a single boot the index is stable**, because the IDA id lives as long as the
device. Hotplugging a USB-C source adds a *new* index; it does not renumber existing ones.
That is what makes one-shot resolution correct rather than merely convenient.

### There is no stable symlink

**Verified locally.** Every candidate still ends in the volatile leaf:

| path | stable? |
| --- | --- |
| `/sys/class/hwmon/hwmon7` → `…/platform/coretemp.0/hwmon/hwmon7` | no — the whole basename is the index |
| `/sys/devices/platform/coretemp.0/hwmon/` | directory is stable, but contains exactly one entry named `hwmon7` |
| `/sys/bus/platform/devices/coretemp.0/hwmon/` | same directory, same leaf |
| `/sys/class/hwmon/hwmon7/device` → `../../../coretemp.0` | points *up* to the stable half; useless as an entry point |
| `/sys/class/thermal/thermal_zone9` (`x86_pkg_temp`) | same package sensor, same index problem, and it registers **no** hwmon node — only `thermal_zone{0,7}` do here |

So the device path removes *most* of the ambiguity: everything but one path component is
fixed, and that component matches a single-entry glob. But **a glob is still a glob**, and
`FileView` cannot expand one.

Reading `coretemp.0` off the stable device path also does not solve the AMD/VM cases,
which need a different device name entirely. A resolution step is unavoidable; it may as
well be the one that handles every case.

### What `FileView` v0.3.0 actually does against sysfs

**Verified locally** by an offscreen probe. Enum values read from the installed
`/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes`: `Success=0, Unknown=1,
FileNotFound=2, PermissionDenied=3, NotAFile=4`.

| probe | result |
| --- | --- |
| `path` containing `hwmon*` | `WARN … Read of …/hwmon*/temp1_input failed: File does not exist.` → `loadFailed(2)`. **No glob support.** |
| `path` through the `/sys/class/hwmon/hwmon7` symlink | `loaded: "55000\n"` |
| `path` through a hand-made `/tmp` symlink to the hwmon dir | `loaded: "55000\n"` |
| `path` through the stable device path | `loaded: "55000\n"` |
| `path` = a directory | `loadFailed(4)` (`NotAFile`) |
| `path` = a nonexistent `hwmon42` | `loadFailed(2)` (`FileNotFound`) |
| `watchChanges: true` on `temp1_input`, 12 s | **0** `fileChanged` signals, while the value went 55000 → 63000 |
| `reload()` then `text()` in the same tick, default settings | returns the **old** value every tick; the new one arrives via `onLoaded` afterwards |
| `reload()` then `text()` with `blockAllReads: true` | returns the **fresh** value in the same tick |
| `printErrors: false` on a missing path | warning suppressed; `loadFailed` still fires |
| binding `path` to a property that starts `""` then becomes a real path | loads on assignment, no error while empty |
| assigning a bad `path` after a good one | `loadFailed(2)`, then `loaded === false` and `text() === ""` |

The `watchChanges` result is the important one and it is not a Quickshell defect: sysfs
attribute files have no inotify modification events to deliver — the kernel notifies
pollers through `sysfs_notify`/`poll()` on the attribute, which `QFileSystemWatcher` does
not use. **Any design that waits for `fileChanged` on a sysfs node will sit at its initial
reading forever.**

Two consequences for the service:

- **Poll with `reload()`**, which is what `ResourceUsage.qml` already does.
- **Set `blockAllReads: true`** on the temperature view, or restructure to read in
  `onLoaded`. The current `reload()`-then-`text()` shape in `ResourceUsage.qml:50-61` is
  one tick behind, which nobody notices at 3 s for a memory bar but which would visibly
  skew a 60-sample timeseries against the CPU-usage series sampled beside it. At 7.7 µs a
  blocking sysfs read is cheaper than the `/proc/stat` read already on that code path.
  *(Fixing the existing `/proc` reads is out of scope for this ticket; note it and move on.)*

### The three options, costed

| approach | startup cost | per-tick cost | correctness |
| --- | --- | --- | --- |
| Hardcode `hwmon7` | 0 | 7.7 µs read | **Wrong.** Breaks on the next boot that reorders probes, silently reading someone else's sensor — `hwmon7` on another ordering could be a battery or a USB-C PD chip. |
| **One-shot `Process`, then `FileView` per tick** | **~4 ms, once** | **7.7 µs read** | Correct. |
| `Process` per tick | 0 | ~4 ms wall + a `fork`/`exec` | Correct but absurd: 86 400 process spawns a day to re-derive a constant. |
| `FileView` on the device path with a glob | — | — | **Impossible.** `FileViewError.FileNotFound`. |
| `FileView` + `watchChanges` instead of polling | — | — | **Impossible.** Never fires on sysfs. |
| Ten `FileView`s, one per `hwmonN`, reading `name` | ~10 × 7.7 µs | 7.7 µs | Works without a subprocess, but only finds the *chip*; picking the channel by label needs another N reads. Needs a fixed upper bound on N chosen arbitrarily. Not worth it to avoid one 4 ms `sh`. |

Measured: 100 full resolutions took 0.428 s wall, i.e. **4.3 ms each**, dominated by the
`sh` spawn. One of those at shell startup is invisible next to everything else Quickshell
does in its first second — and it is *already* the pattern this repo uses for
`brightnessctl`, `ddcutil` and `hyprctl`.

### Recommendation

**Resolve once with one `sh -c`, bind `FileView.path` to the result, poll with `reload()`
on the existing 1 s `Timer`. Re-run the resolver — once, not on a timer — if the view ever
emits `loadFailed`,** which covers a driver being unbound at runtime.

The exact command, **verified locally** against the real machine and against five synthetic
sysfs trees:

```qml
command: ["sh", "-c", RESOLVE_SCRIPT]
```

```sh
for want in coretemp k10temp acpitz; do
  for d in /sys/class/hwmon/hwmon*; do
    [ -r "$d/name" ] || continue
    read -r n < "$d/name"
    [ "$n" = "$want" ] || continue
    pick=
    for l in "$d"/temp*_label; do
      [ -r "$l" ] || continue
      read -r lbl < "$l"
      c=${l%_label}
      read -r v < "${c}_input" 2>/dev/null || continue
      [ "$v" -gt 0 ] 2>/dev/null || continue
      case "$lbl" in
        "Package id "*|Tdie) pick=$c; break ;;
        Tctl) [ -n "$pick" ] || pick=$c ;;
      esac
    done
    if [ -z "$pick" ]; then
      for i in "$d"/temp*_input; do
        read -r v < "$i" 2>/dev/null || continue
        [ "$v" -gt 0 ] 2>/dev/null || continue
        pick=${i%_input}; break
      done
    fi
    [ -n "$pick" ] || continue
    lbl=; [ -r "${pick}_label" ] && read -r lbl < "${pick}_label"
    crit=; [ -r "${pick}_crit" ] && read -r crit < "${pick}_crit"
    printf '%s\t%s\t%s\t%s\n' "$n" "$lbl" "${pick}_input" "$crit"
    exit 0
  done
done
exit 1
```

Points worth keeping when this is turned into code:

- **`sh`, not `fish`.** `Process.command` is an `execve` argv, so the login shell is
  irrelevant; this is POSIX `sh` and must stay that way.
- **Every candidate channel is read before it is chosen.** This is not defensive
  paranoia — see §4: `thinkpad` has `temp*_input` files that return `ENXIO` and others that
  return literal `0`, and picking one of those is exactly the garbage-0 °C the ticket
  wants avoided.
- **Exit 1 with no output means "no CPU sensor".** No stderr noise on that path; verified
  against an empty tree.
- **Tab-separated, not JSON.** Chip names are constrained by the ABI ("a short, lowercase
  string, not containing whitespace") but *labels are not* — `Package id 0` has spaces.
  Tabs separate cleanly; quoting JSON in `sh` does not.

End-to-end **verified locally** in Quickshell: the `Process` above returned
`coretemp\tPackage id 0\t/sys/class/hwmon/hwmon7/temp1_input\t100000\n`, the `FileView`
bound to field 3 loaded `50000\n`, and reassigning a bad path dropped it to
`loaded === false`, `text() === ""`.

### The parsing seam

Per `AGENTS.md`, the resolver's stdout is a `string → data` boundary and belongs in a
`.pragma library` beside the service — `services/cpu_temperature.js`, matching the newest
naming in the repo (`services/weather_format.js`, 2026-08-07;
`modules/dashboard/dashboard_metrics.js`, 2026-08-08). Two functions, both pure:

```js
// The single line the hwmon resolver prints, or "" when it found nothing.
// Returns null for anything unusable, so the caller renders no card rather than a guess.
// -> { chip, label, path, criticalCelsius } | null
function parseSensorLine(stdout)

// The contents of the resolved tempN_input node. Kernel reports millidegree Celsius
// (Documentation/ABI/testing/sysfs-class-hwmon); coretemp's resolution is 1 degree, so
// the result is rounded rather than carrying a digit that is always zero.
// -> number | null
function parseTemperature(text)
```

Cases a later ticket should spec tests for, all of which this research produced real
strings for:

- `parseSensorLine`: the real `coretemp\tPackage id 0\t/sys/…/temp1_input\t100000\n`;
  `k10temp\tTdie\t…\t` with an **empty** crit field (AMD Tdie has no `_crit`); `acpitz\t\t…\t`
  with an **empty label**; `""` (exit 1, no sensor); a truncated line with too few fields.
- `parseTemperature`: `"55000\n"` → `55`; `""` (unloaded view) → `null`; `"0\n"` → `null`
  (a `thinkpad`-style dead channel that slipped through); non-numeric junk → `null`.

## 4. When there is no `coretemp`

### AMD — `k10temp`

**Verified in source**, `drivers/hwmon/k10temp.c:195-208`, the label table is
`{"Tctl", "Tdie", "Tccd1" … "Tccd12"}`, and `Tctl` is always shown (`:449`, comment
`/* Always show Tctl */`).

**Prefer `Tdie` and fall back to `Tctl`.** `Documentation/hwmon/k10temp.rst:105-126`
quotes the AMD manual:

> Tctl is the processor temperature control value, used by the platform to control cooling
> systems. Tctl is a non-physical temperature on an arbitrary scale measured in degrees.
> It does _not_ represent an actual physical temperature like die or case temperature.

and:

> While Tctl is always available as temp1_input, the driver exports Tdie temperature as
> temp2_input for those CPUs which support it.

For Family 17h+ "the driver aims to compensate and report the real temperature", so `Tctl`
is a tolerable second choice; on older families it can read tens of degrees high. The
`Tccd*` channels are per-die, not a package figure — ignore them. The script above encodes
exactly this: `Tdie` wins immediately, `Tctl` is held as a fallback and only used if no
`Tdie` turns up. **Verified** against a synthetic `k10temp` tree with `Tctl`/`Tdie`/`Tccd1`
(picks `Tdie`) and one with `Tctl` alone (picks `Tctl`).

`zenpower`, the out-of-tree replacement some AMD users install, unbinds `k10temp` and
exposes its own names. Not handled, and deliberately: it is not in the kernel tree, and
the `acpitz` rung catches those machines anyway. **Inferred.**

### VMs

**Inferred**, not reproduced — no VM was available. `coretemp` needs
`IA32_THERM_STATUS`/`MSR_IA32_TEMPERATURE_TARGET`, which hypervisors do not normally
expose, so the module fails to probe and no `coretemp` hwmon exists. Whether an `acpitz`
appears depends entirely on whether the virtual firmware ships a thermal zone; many do
not. **A VM with no CPU temperature at all is a real, common case and the design must
treat it as normal, not as an error.**

### This machine's other hwmons, judged

| name | what it actually is | verdict |
| --- | --- | --- |
| `acpitz` | `thermal_zone0`, ACPI `THM0`, one unlabelled `temp1_input` = 53000 | **Last-resort fallback.** It is a firmware-defined zone, usually near but not on the die, and it may be a skin/ambient sensor. Better than nothing; label the card honestly. |
| `thinkpad` | `thinkpad_hwmon`, EC registers. `temp1_label: CPU`, `temp2_label: GPU` | **Trap. Do not use.** See below. |
| `nvme` | `Composite` 35.85 °C, `Sensor 1/2` | SSD, not CPU. Real data for a *storage* card, wrong data for this one. |
| `iwlwifi_1` | `thermal_zone7`, 37 °C | Wi-Fi radio. Not CPU. |
| `BAT0`, `AC` | power_supply hwmons | **No `temp*` nodes at all** on this machine. |
| `acpi_fan` | `PNP0C0B:00` | **No `temp*` nodes.** Fan control, not a sensor. |
| `ucsi_source_psy_*` (×2) | USB-C PD source | **No `temp*` nodes.** Also hotpluggable, so they come and go. |

### Why `thinkpad` is a trap even though it says `CPU`

**Verified locally:**

```
temp1_input = 53000   temp1_label = CPU
temp2_input = <read fails: ENXIO>   temp2_label = GPU
temp3..temp7_input = 0
temp8_input = <read fails: ENXIO>
```

Three separate problems:

1. **The label is a guess by the driver, not a hardware fact.**
   `Documentation/admin-guide/laptops/thinkpad-acpi.rst:918-934`: "The mapping of thermal
   sensors to physical locations varies depending on system-board model (and thus, on
   ThinkPad model)", followed by "Most (newer?) models *seem* to follow this pattern: 1:
   CPU …" and then several models that do not.
2. **It is an EC sensor, not the die.** It read 53 °C at the same instant `coretemp`'s
   package read 55 °C, at 1 °C granularity, and it lags — it tracks board temperature near
   the package, which is a different physical quantity from junction temperature.
3. **Half its channels are landmines.** `temp2`/`temp8` return `ENXIO`
   (`thinkpad-acpi.rst:973`: "Sensors that are not available return the ENXIO error"), and
   `temp3`–`temp7` return a literal `0`. **Any resolver that takes "the first `temp*_input`
   in the directory" and lands on this chip has a one-in-two chance of publishing 0 °C as a
   CPU temperature.** This is precisely the failure the ticket asks to avoid, and it is why
   the recommended script validates `> 0` on the actual read before committing to a channel.

`thinkpad` is also *this laptop only*. Putting a vendor-specific chip in a general fallback
chain trades a correct "unknown" on every other machine for a marginally-plausible number
on one. Leave it out.

### The chain, and what "nothing" reads as

```
coretemp  (label "Package id N", else lowest live channel)
   ↓
k10temp   (label "Tdie", else "Tctl")
   ↓
acpitz    (single unlabelled channel — a firmware zone, not the die)
   ↓
nothing
```

**The service property must be `null` when nothing resolves, never `0`.** Concretely:

- `cpuTemperature: real` defaulting to `0` is wrong — 0 °C is a *valid* reading (a cold
  boot in a cold room), so the tab cannot distinguish "no sensor" from "very cold", and a
  ring buffer of zeroes silently drags the plot's y-axis to the floor.
- Use `property var cpuTemperature: null`. QML binds `null` cleanly and
  `Item.visible: ResourceUsage.cpuTemperature !== null` reads as what it means.
- Expose the provenance too — the resolver already returns it for free:
  `cpuTemperatureChip` (`"coretemp"`), `cpuTemperatureLabel` (`"Package id 0"`) and
  `cpuTemperatureCritical` (100). The tab can then say *Package id 0* where the reading is
  the real package, and grey out or caption differently on the `acpitz` rung, where the
  number is a firmware zone and deserves the hedge.
- **Feed `null` into the ring as a hole, not as a sample.** Whatever #135's ring buffer
  ends up being, a missing reading must not become a `0` datapoint — the map already
  commits to uniform sample spacing, so the plot needs a gap representation regardless.
- The card is hidden or greyed by the *`null`*, not by a separate `hasTemperature` boolean.
  One source of truth.

The re-resolve trigger is `FileView.onLoadFailed`, and `printErrors: false` on that view
keeps an unbound driver from writing a warning to the log every second (**verified
locally**: the flag suppresses the warning, `loadFailed` still fires).

## Sources

**Linux kernel** (`github.com/torvalds/linux`, master as fetched 2026-08-08):
`drivers/hwmon/coretemp.c` (`create_core_attrs`, `show_label`, `show_temp`),
`drivers/hwmon/hwmon.c` (`hwmon_ida`, `ida_alloc`, `dev_set_name`),
`drivers/hwmon/k10temp.c` (`k10temp_temp_label`, `TCTL_BIT`/`TDIE_BIT`),
`Documentation/hwmon/sysfs-interface.rst`, `Documentation/hwmon/coretemp.rst`,
`Documentation/hwmon/k10temp.rst`, `Documentation/ABI/testing/sysfs-class-hwmon`,
`Documentation/admin-guide/laptops/thinkpad-acpi.rst`.

**Quickshell:** `https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/`;
`FileViewError` enum read from the installed
`/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes`.

**Local:** ThinkPad X1 Carbon Gen 11 (`21HNS42T00`), 13th Gen Intel Core i7-1365U, Linux
`6.18.41-1-lts`, `quickshell 0.3.0-2`, `lm_sensors`. Full `/sys/class/hwmon` walk,
`/sys/class/thermal` walk, `lsmod`, `sensors coretemp-isa-0000`, read-latency benchmark,
and an offscreen Quickshell probe config run under `QT_QPA_PLATFORM=offscreen` with no
compositor, on 2026-08-08. Resolver script exercised against the live tree and five
synthetic hwmon trees (AMD `Tctl`+`Tdie`+`Tccd`, AMD `Tctl`-only, pre-Sandy-Bridge Intel,
`acpitz`-only, empty).

**Repo:** `services/ResourceUsage.qml`, `tests/brightness-without-ddcutil.sh` (the offscreen
harness this research reused), `AGENTS.md`.
