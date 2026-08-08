# fprintd provisioning recommendation for issue #49

Research date: 2026-07-27. This note answers the hardware-provisioning question in
[issue #49](https://github.com/bhdai/quickshell_config/issues/49), within the lock-screen
[map #45](https://github.com/bhdai/quickshell_config/issues/45). It deliberately does not
repeat the PAM design analysis in
[`pam-policy-options.md`](./pam-policy-options.md) or apply any package/PAM change.

## Result

The stock Arch stack enrolled and repeatedly verified the reader successfully. The user
reported that verification works reliably.

| Item | Result |
| --- | --- |
| Reader | Synaptics Prometheus `06cb:00fc` |
| Driver | libfprint `synaptics` (`libfprint-synaptics`, reported as Synaptics Sensors) |
| fprintd | `1.94.5-2` |
| libfprint | `1.94.10-2` |
| Service behavior | D-Bus activation succeeded; the journal shows clean starts and idle exits |
| Permission or D-Bus problems | None reported during enrollment or verification |
| PAM changes | None; `/etc/pam.d` still has no `pam_fprintd.so` references |

The hardware gate in issue #49 therefore passes. Fingerprint authentication can remain
in scope for the Quickshell lock-screen design.

## Recommendation

Provision the reader with Arch's official `fprintd` and `libfprint` packages, prove
enrollment and verification using the command-line tools, and make **no PAM edits during
that proof**. The machine should not use an AUR `libfprint` fork unless the official
packages actually fail: the attached USB device is `06cb:00fc`, and upstream lists that
ID as supported by its Synaptics driver family. The upstream list warns that it describes
the development version, so successful enrollment and independent verification—not the
list alone—remain the acceptance test.
([ArchWiki: fprint](https://wiki.archlinux.org/title/Fprint);
[upstream supported devices](https://fprint.freedesktop.org/supported-devices.html))

If the reader proves reliable, enable fingerprint on the future Quickshell lock screen
through its own PAM service and a separate fingerprint `PamContext`; keep password
authentication independently available. Do not add `pam_fprintd.so` to `system-auth`,
`system-login`, `login`, or any other shared stack. In particular, this machine's current
`/etc/pam.d/sudo` now includes `system-auth` for `auth`, so a `system-auth` edit would
directly violate issue #49's “never sudo” constraint. Upstream documents that a PAM
conversation is serial: simultaneous password and fingerprint availability requires the
application to run separate PAM processes/stacks.
([pam_fprintd(8)](https://man.archlinux.org/man/pam_fprintd.8.en);
[CVE-2024-37408 record](https://nvd.nist.gov/vuln/detail/CVE-2024-37408))

Leave SDDM unchanged for the initial setup. If it is still wanted after the lock-screen
path is stable, scope the change to `/etc/pam.d/sddm` only and test it from a recoverable
TTY. ArchWiki's current SDDM recipe is password-first: entering a password authenticates
normally; submitting an empty password starts fingerprint authentication. The page warns
that fingerprint support is not fully reliable and password fallback has failed for some
setups. This is inferior to the planned Quickshell two-context UX, so SDDM should be a
separate opt-in follow-up rather than part of the hardware proof.
([ArchWiki: SDDM § Using a fingerprint reader](https://wiki.archlinux.org/title/SDDM#Using_a_fingerprint_reader))

## Machine facts that drive the recommendation

These were read locally without changing the system:

| Item | Observed state |
| --- | --- |
| USB device | `/sys/bus/usb/devices/*/{idVendor,idProduct}` contains `06cb:00fc` |
| Installed fingerprint packages | Neither `fprintd` nor `libfprint` is installed |
| Official repository candidates | `fprintd 1.94.5-2`; `libfprint 1.94.10-2` |
| Login manager | SDDM `0.21.0-7`; `/etc/pam.d/sddm` currently starts with `auth include system-login` |
| Shared auth reach | `/etc/pam.d/sudo` contains `auth include system-auth` |
| Existing fingerprint PAM references | None under `/etc/pam.d` |
| Keyring PAM modules | `pam_kwallet5.so` and `pam_gnome_keyring.so` are absent, despite optional lines in the SDDM policy |
| Sleep mode | `/sys/power/mem_sleep` is `[s2idle]` |
| Firmware updater | `fwupd` is not installed |

The package versions also match the current Arch package database. `fprintd` depends on
`libfprint` and installs the daemon, D-Bus activation files, CLI tools, polkit policy, and
`pam_fprintd.so`.
([Arch `fprintd` package](https://archlinux.org/packages/extra/x86_64/fprintd/);
[Arch `libfprint` package](https://archlinux.org/packages/extra/x86_64/libfprint/);
[Arch `fprintd` file list](https://archlinux.org/packages/extra/x86_64/fprintd/files/))

The existing `[s2idle]` selection already matches the ArchWiki recommendation for
libfprint devices; no sleep-mode change is indicated before testing.
([ArchWiki: fprint](https://wiki.archlinux.org/title/Fprint);
[ArchWiki: suspend modes](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Changing_suspend_method))

## Proposed ticket #49 runbook

Run these interactively on the real session, because enrollment requires touching the
reader and may require a graphical polkit authentication agent:

```sh
sudo pacman -S fprintd libfprint
pacman -Q fprintd libfprint
fprintd-list "$USER"
fprintd-enroll -f right-index-finger "$USER"
fprintd-list "$USER"
fprintd-verify -f right-index-finger "$USER"
sudo journalctl -b -u fprintd --no-pager
```

The tools talk to the daemon over D-Bus; `fprintd-list` requires a username, while
`fprintd-enroll` and `fprintd-verify` default to the current user. Enrolled prints are
stored below `/var/lib/fprint/`.
([fprintd(1)](https://man.archlinux.org/man/fprintd.1.en);
[fprintd project overview](https://fprint.freedesktop.org/))

Record all of the following in issue #49:

1. The `pacman -Q` versions.
2. Whether `fprintd-list` detects a device and the device name it prints.
3. Every enrollment status, especially `enroll-completed`, `enroll-duplicate`,
   `enroll-disconnected`, or `enroll-unknown-error`.
4. At least three fresh `fprintd-verify` attempts after enrollment, including whether
   they return `verify-match` consistently.
5. The journal's driver/device identification and any USB, firmware, D-Bus, device-claim,
   or polkit errors.

Upstream defines retry statuses separately from terminal failures, and identifies
`*-disconnected` and `*-unknown-error` as stop conditions; “unknown error” usually means a
driver problem. That distinction matters when deciding whether a poor scan or the driver
failed.
([fprintd D-Bus Device API](https://fprint.freedesktop.org/fprintd-dev/Device.html))

## Failure handling, in order

1. **Enrollment is denied:** confirm a graphical authentication agent is running. If the
   polkit action still returns `PermissionDenied`, ArchWiki permits root-assisted
   enrollment, but the target must remain the regular user:

   ```sh
   sudo fprintd-enroll -f right-index-finger "$USER"
   ```

   Never omit the username in that root command, or the print is enrolled for root.
   ([ArchWiki: unable to enroll as user](https://wiki.archlinux.org/title/Fprint#Unable_to_enroll_as_user);
   [upstream polkit behavior](https://fprint.freedesktop.org/fprintd-dev/Device.html#polkit-integration))

2. **No device / already in use / initialization error:** inspect
   `journalctl -b -u fprintd`. Do not install a fork yet. The ArchWiki points to firmware
   updates when logs report unsupported firmware; because `fwupd` is absent here, installing
   it is a separate decision only if the log gives firmware evidence.
   ([ArchWiki: no devices available](https://wiki.archlinux.org/title/Fprint#No_devices_available))

3. **Resume-only failure:** reproduce across suspend before adding a workaround. The
   machine already uses s2idle. Only if logs demonstrate the documented early-start race
   should the issue consider the ArchWiki USB-persistence udev rule for this exact
   `06cb:00fc`; do not preinstall that rule.
   ([ArchWiki: resume initialization race](https://wiki.archlinux.org/title/Fprint#fprintd_starts_before_fingerprint_reader_device_is_initialized_after_resuming_from_sleep))

4. **Enrollment succeeds but verification is unreliable:** treat that as a negative or
   qualified hardware result. Do not compensate by changing PAM or installing
   `pam-fprint-grosshack`; neither can repair driver/scanner reliability.

## Post-proof setup choice

If verification is reliable, the preferred machine setup is:

- fingerprint plus password on the Quickshell lock screen, using two app-specific PAM
  service names/contexts so both methods can be active and neither reaches sudo;
- password remains sufficient by itself;
- no fingerprint for sudo, `su`, or polkit;
- no SDDM fingerprint initially; revisit it only as a separately tested convenience.

For the later lock-screen policy ticket, `pam_fprintd` defaults to three tries and a
30-second timeout and accepts explicit `max-tries` and `timeout` options. Those values are
UI/policy decisions, not provisioning settings.
([pam_fprintd(8)](https://man.archlinux.org/man/pam_fprintd.8.en))

If enrollment or repeated direct verification fails with the official packages, close the
fingerprint design path as unsupported on this machine, as issue #49 requires. Do not
escalate to an AUR fork merely because the hardware has historically been awkward: that
would replace the ticket's clean test of the maintained Arch stack with a different,
ongoing system-maintenance commitment.
