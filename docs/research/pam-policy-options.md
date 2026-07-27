# PAM policy options for a Quickshell lock screen on Arch

Research for [#47](https://github.com/bhdai/quickshell_config/issues/47) (part of [#45](https://github.com/bhdai/quickshell_config/issues/45)).

**This document lays out options and their costs. It does not pick one** — the decision
belongs to the grilling ticket ([#51](https://github.com/bhdai/quickshell_config/issues/51)).

Everything below was verified against primary sources: the Linux-PAM 1.7.2 source, the
Quickshell 0.3.0 source and docs, ArchWiki, fprintd's `pam_fprintd.c`, and this machine's
actual `/etc/pam.d`. Where a claim is inference rather than verification, it says so.

---

## 0. Ground truth on this machine

Verified 2026-07-27 against the live system.

| Fact | Value |
| --- | --- |
| Quickshell | 0.3.0 (Arch package) |
| `pam` | 1.7.2-2 |
| `/etc/pam.d/hyprlock` | `auth include login` (plus comments) — verbatim copy of swaylock's upstream file |
| `/etc/pam.d/sudo` auth | `auth sufficient pam_rootok.so`, then `auth required pam_unix.so` — **does not include `system-auth` for `auth`**; only `password include system-auth` |
| `/etc/pam.d/su` auth | `pam_rootok.so` + `pam_unix.so` directly |
| `pam_faillock` | Active in `system-auth` (`preauth` / `authfail` / `authsucc`) |
| `/etc/security/faillock.conf` | Every line commented → defaults `deny=3`, `fail_interval=900`, `unlock_time=600` |
| `pam_faildelay` | Module present at `/usr/lib/security/pam_faildelay.so`, **not referenced by any file in `/etc/pam.d`** |
| `/run/faillock/dai` | Exists, `-rw-rw---- dai:root` — user-writable |
| `pam_fprintd.so` | **Absent.** `fprintd` / `libfprint` not installed (available in `extra`: fprintd 1.94.5-2, libfprint 1.94.10-2) |
| Fingerprint hardware | Synaptics Prometheus `06cb:00fc` — **on libfprint's supported-devices list** |
| `/usr/lib/pam.d/` | Contains vendor files `kde` and `kde-fingerprint` (from kscreenlocker) |
| `/home/dai` | `drwx------` — unreadable by any other unprivileged local user |
| `~/.config/quickshell` | symlink → `~/ghq/github.com/bhdai/dotfiles/config/quickshell` |
| SDDM daemon | runs as **root** (`User=` empty); greeter account `sddm`, home `/var/lib/sddm` |
| `unix_chkpwd` | `-rwsr-sr-x root:root` — the setuid helper that lets an unprivileged locker check passwords |
| User shell | `/usr/bin/fish`, present in `/etc/shells` |

### The include graph that actually matters

```
sudo   ──► pam_rootok + pam_unix          (auth never reaches system-auth)
su     ──► pam_rootok + pam_unix
login  ──► system-local-login ──► system-login ──► system-auth
sshd   ──► system-remote-login ─► system-login ──► system-auth
sddm   ──► system-login ─────────────────────────► system-auth
hyprlock ► login ────────────────────────────────► system-auth
```

Two consequences worth stating up front:

1. On **this** machine, `sudo`'s `auth` stack is `pam_rootok.so` + `pam_unix.so` directly.
   It does *not* `include system-auth` for `auth`. So the classic warning "editing
   `system-auth` leaks fingerprint into sudo" is **not** literally true here — but it
   remains the right instinct, because `system-auth` is the shared trunk and Arch's
   `sudo` policy is a `backup=` file that a future package or manual edit could change to
   `auth include system-auth` (that is the more common Arch layout). Do not rely on this
   machine's `sudo` file staying as it is.
2. `system-login` is shared with **sshd** via `system-remote-login`. Anything added there
   reaches remote logins.

---

## 1. What `configDirectory` actually does

**Docs** ([PamContext v0.3.0](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Pam/PamContext),
identical text in `src/services/pam/qml.hpp`):

> `config` — "The pam configuration to use. Defaults to `login`. The configuration should
> name a file inside `configDirectory`."
>
> `configDirectory` — "The pam configuration directory to use. Defaults to `/etc/pam.d`.
> The configuration directory is resolved relative to the current file if not an absolute
> path. On FreeBSD this property is ignored as the pam configuration directory cannot be
> changed."

**Quickshell issues no warning about `configDirectory`.** Not in the property docs, not in
the module overview. On the contrary, `src/services/pam/module.md` actively encourages a
shell-specific policy:

> "It is a good idea to write pam configurations specifically for quickshell if you want to
> do anything other than match the default login flow."

**Mechanism** — `src/services/pam/subprocess.cpp`:

```c
#ifdef __FreeBSD__
	auto result = pam_start(config, user, &conv, &handle);
#else
	auto result = pam_start_confdir(config, user, &conv, configDir, &handle);
#endif
```

`pam_start_confdir(3)` is stock Linux-PAM: "allows setting confdir argument with a path to
a directory to override the default (`/etc/pam.d`) path for service policy files."

### Four behaviours of `confdir` that the docs do not mention

All verified in Linux-PAM `libpam/pam_handlers.c` (master, matching 1.7.x):

1. **`confdir` fully replaces `/etc/pam.d` — there is no fallback.** In
   `_pam_open_config_file`, once `pamh->confdir != NULL` the function builds
   `confdir/<service>` and returns `PAM_ABORT` if that single path fails to open. The
   `/etc/pam.d`, `/usr/lib/pam.d` search loop is skipped entirely.

2. **`include` and `substack` resolve inside `confdir` too.** The include argument is
   passed straight to `_pam_open_config_file`. So a repo-local file containing
   `auth include system-auth` looks for `<confdir>/system-auth`, **not**
   `/etc/pam.d/system-auth`. *This is the single biggest practical cost of the repo-local
   option: you cannot inherit Arch's stack, you must inline it.*

3. **An absolute path bypasses `confdir`.** `_pam_open_config_file` special-cases
   `service[0] == '/'` before consulting `confdir`, so `auth include /etc/pam.d/system-auth`
   inside a repo-local file *does* work. This behaviour is **not documented in
   `pam.d(5)`** — it is source-verified only. Treat it as a fragile trick, not a
   supported interface.

4. **Missing service file fails closed.** With `confdir` set, PAM tries
   `confdir/<service>` and then `confdir/other`; if neither is read successfully,
   `_pam_init_handlers` sets `retval = PAM_ABORT` (the `read_something` check). So a typo
   in `config:` does not silently authenticate — it errors out. (Note the fallback is
   `confdir/other`, **not** `/etc/pam.d/other`. This is why DankMaterialShell ships an
   `other` file of `pam_deny.so` in its own pam directory.)

### Prior art — the repo-local pattern is the dominant one in the wild

GitHub code search for `configDirectory` in QML returns ~15 Quickshell shells, essentially
all of them using a repo-local directory:

| Shell | Value |
| --- | --- |
| `caelestia-dots/shell` | `Quickshell.shellPath("assets/pam.d")` |
| `AvengeMedia/DankMaterialShell` | `Quickshell.shellDir + "/assets/pam"` |
| `hireri/israshell` | `Quickshell.shellDir + "/pam"` |
| `JwpAT/hyprstar` | `Quickshell.shellDir + "/modules/lockscreen/pam"` |
| many others | bare relative `"pam"` (resolved relative to the QML file) |
| `Linco02/Atheris-shell` | `"/etc/pam.d"` (the only one using system policy) |

Their file contents are instructive. **caelestia** `assets/pam.d/passwd`:

```
#%PAM-1.0

auth    required                    pam_faillock.so     preauth
auth    [success=1 default=bad]     pam_unix.so         nullok
auth    [default=die]               pam_faillock.so     authfail
auth    required                    pam_faillock.so     authsucc
```

— i.e. a faithful inline copy of Arch's `system-auth` faillock idiom. And
`assets/pam.d/fprint`:

```
#%PAM-1.0

auth    required    pam_fprintd.so  max-tries=1
```

Note the architecture: **two separate `PamContext` objects with two separate config
files**, run concurrently, not one stacked file. See §5 for why that matters.

`Quickshell.shellDir` is documented as "the full path to the root directory of your
shell"; `Quickshell.shellPath(p)` is `shellDir + "/" + p`. (`configDir`/`configPath()` are
the deprecated old names.)

---

## 2. The security trade-off, argued properly

The reflex answer is "a user-writable PAM config is bad". That reflex is worth
interrogating, because in *this* threat model it mostly does not survive contact with the
facts.

### What an attacker at a locked screen can do

Nothing to the filesystem. The lock surface is enforced by the **compositor**, via
`ext-session-lock-v1`, not by Quickshell. Quickshell's own `WlSessionLock` docs are
explicit about the failure mode:

> "conformant compositors will leave the screen locked and painted with a solid color […]
> The lock dying will not expose your session, but it will render it inoperable."

So the keyboard attacker cannot get a shell, cannot edit `assets/pam.d/passwd`, cannot
even crash their way out. For this attacker, the ownership of the policy file is
irrelevant — they cannot reach it either way.

### What an attacker who is already `uid dai` can do

This is where the argument is actually decided. Ask what root-ownership *buys* against
someone who already has the user's uid, and the answer is: nothing, because the unlock
decision does not live in PAM.

- **The unlock decision is made in user-owned QML.** `PamContext` reports a
  `PamResult`; it is `lock/…​.qml` — a file owned by `dai`, hot-reloaded, no signature, no
  integrity check — that decides to call `WlSessionLock.unlock()`. An attacker with write
  access to the shell config replaces that one line and the lock opens regardless of what
  `/etc/pam.d/quickshell-lock` says. **A root-owned policy file protects a component that
  sits downstream of a user-owned trust decision.** That is the crux.
- Same uid can also just not lock: edit or kill `hypridle`, or bind the lock keybind to
  nothing.
- Same uid can read every file the lock is protecting, directly, without unlocking
  anything. It *is* the user.
- Even the rate limiting is already user-controlled: `/run/faillock/dai` is
  `-rw-rw---- dai:root`, so `faillock --reset` works unprivileged. `pam_faillock` was
  never a boundary against this uid.
- No *other* unprivileged local user can reach the file anyway: `/home/dai` is `0700`.

Conclusion: **for the lock screen specifically, a user-writable PAM policy grants no
capability that `uid dai` does not already have.** It is not a bypass. Anyone claiming
otherwise has to explain how root-owning the policy constrains the user-owned QML that
consumes its result.

### What root-ownership does genuinely buy

Four things, none of them "prevents bypass":

1. **Reach beyond Quickshell.** SDDM's daemon runs as root and its greeter as `sddm`;
   neither can read a policy under `/home/dai` (`0700`). If one policy is to serve both the
   lock screen and SDDM, it must live in `/etc/pam.d`. This is the strongest concrete
   argument, and it is an interoperability argument, not a security one.
2. **Correctness by inheritance.** `auth include system-auth` works only from
   `/etc/pam.d`. A repo-local file must inline Arch's faillock idiom, and that copy will
   **silently drift** when `pambase` updates `system-auth`. A future Arch change to the
   base stack (`pam_systemd_home`, faillock semantics, anything new) reaches `hyprlock`
   automatically and reaches a repo-local copy never. This is a real, ongoing maintenance
   cost and arguably the best argument for `/etc/pam.d`.
3. **A write-only primitive.** A bug that lets an attacker write files as the user but not
   execute code as the user would be stopped by root-ownership. On a single-user laptop
   where the shell is a directory of hot-reloading QML, this is contrived — the same
   primitive rewrites the QML.
4. **Convention and legibility.** It matches how every other locker on the system does it
   (`/etc/pam.d/hyprlock`, swaylock upstream, `/usr/lib/pam.d/kde-fingerprint`), and it
   puts the policy where a person auditing the machine will look.

### What repo-local genuinely buys

1. **Zero root, zero out-of-band setup.** The shell works from a fresh `git clone` on a
   new machine with no install step. For a config that is deployed as a dotfiles submodule,
   this is the whole point.
2. **Strictly lower lockout risk.** A broken repo-local file breaks only the lock screen.
   A botched edit to `/etc/pam.d/system-auth` or `login` can lock every account out of
   the machine. See §7 — this cuts hard against the "user-writable is unsafe" framing,
   because the failure mode that actually bites people is lockout, not bypass.
3. **Per-method policy files without touching system state** (`passwd`, `fprint`,
   `u2f`…), which is what the concurrent password + fingerprint UX needs. (Achievable with
   root-owned files too — just several of them.)

---

## 3. Options table

| | **A — root-owned `/etc/pam.d/quickshell-lock`** | **B — repo-local `configDirectory`** | **C — reuse an existing service name** | **D — hybrid: repo-local + absolute-path include** |
| --- | --- | --- | --- | --- |
| `PamContext` | `config: "quickshell-lock"`, `configDirectory` default | `config: "passwd"` / `"fprint"`, `configDirectory: Quickshell.shellPath("assets/pam.d")` | `config: "hyprlock"` (or `"login"` — the default) | as B |
| Needs root | Yes, once per machine (and again on each new machine) | No | No (files already exist) | No |
| Inherits Arch `system-auth` updates | Yes, via `auth include system-auth` | **No — inlined copy, drifts silently** | Yes | Yes, via `include /etc/pam.d/system-auth` |
| Can also serve SDDM | Yes | **No** — `/home/dai` is `0700`, sddm can't read it | Yes (SDDM already has its own file) | No |
| Security vs keyboard attacker | Same as B/C/D — irrelevant, no filesystem access | Same | Same | Same |
| Security vs same-uid attacker | **No better than B** — the unlock decision is user-owned QML either way | No worse | No worse | No worse |
| Blast radius of a mistake | **Contained to the new file**, as long as you create a *new* service name and never edit `system-auth`/`login`/`system-login` | Contained to the lock screen | **None** — no files changed | Contained to the lock screen |
| Fingerprint scoping | Clean: own file, invisible to sudo by construction | Clean: outside `/etc/pam.d` entirely | **Bad**: `hyprlock`→`login`→`system-local-login`, so adding fprintd here means editing a shared file | Clean |
| Deployment cost | An install step the repo does not currently have (§6) | None | None | None |
| Matches upstream Quickshell guidance | Yes (module.md: write your own config) | Yes (module.md), and it is what `configDirectory` exists for | No — module.md says write your own if you want more than the default login flow | Yes, but relies on undocumented behaviour |
| Prior art | swaylock, hyprlock, KDE `kde-fingerprint` | ~15 Quickshell shells incl. caelestia, DankMaterialShell | current hyprlock setup | none found |
| Main honest objection | Needs root and a deployment mechanism; SDDM aside, buys little security | Duplicates Arch's stack and drifts; cannot serve SDDM | Inflexible; `login` drags in `pam_nologin`/`pam_shells`; no place to put fprintd without widening scope | Depends on `include <absolute path>`, which `pam.d(5)` does not document |

**Not viable / rejected:**

- `/usr/lib/pam.d/quickshell-lock` — this is the *vendor* directory for packages
  (`pam.d(5)`: used only "if no machine configuration file is found"). It is package
  territory, not sysadmin territory, and gets clobbered.
- Editing `system-auth` — reaches everything on the machine including any future
  `sudo` that includes it. Never.
- Editing `system-login` — reaches sshd via `system-remote-login`.

---

## 4. Concrete file contents

### Option A — `/etc/pam.d/quickshell-lock` (root:root 0644)

Minimal, inheriting the distro stack. This is the direct analogue of what `hyprlock`
already has:

```
#%PAM-1.0
# Quickshell lock screen. Only the auth stack is used — PamContext cannot run
# account/password/session, which require root.

auth      include   system-auth
```

**Why `system-auth` and not `login`?** `hyprlock` and swaylock both use
`auth include login`, and `login` adds two modules that are login-appropriate but wrong for
a screen locker:

- `pam_nologin.so` (requisite) — if `/etc/nologin` exists (created by `shutdown(8)`), the
  lock **refuses to unlock your own already-running session**. Rare, but it is a genuine
  self-lockout that has nothing to do with authentication.
- `pam_shells.so` (required) — the user's login shell must be in `/etc/shells`. Currently
  fine (`/usr/bin/fish` is listed), but it makes unlocking depend on an unrelated file.

Going straight to `system-auth` keeps `pam_faillock` + `pam_unix` + `pam_env` and drops
both. So: **following hyprlock's precedent works, but it is convention rather than
correctness** — hyprlock's file is a verbatim copy of swaylock's, comment and all.
KDE's `/usr/lib/pam.d/kde` uses `auth include system-local-login`, which drops
`pam_nologin` but keeps `pam_shells`. Any of the three authenticate correctly today; only
the failure modes differ.

If you want fingerprint as a *second* service (recommended — see §5), add:

`/etc/pam.d/quickshell-fprint` (root:root 0644):

```
#%PAM-1.0
# Fingerprint-only auth for the Quickshell lock screen.
# The leading '-' silences the syslog entry when fprintd is not installed; it does
# NOT skip the line — a missing module still fails this stack closed.

auth      requisite   pam_faillock.so   preauth
-auth     required    pam_fprintd.so    max-tries=1
```

### Option B — repo-local `assets/pam.d/`

`assets/pam.d/passwd`:

```
#%PAM-1.0
# Mirrors /etc/pam.d/system-auth's auth stack. Because pam_start_confdir replaces
# the whole search path, `include system-auth` would look for assets/pam.d/system-auth
# and fail — the stack has to be inlined here, and re-checked whenever pambase changes.

auth      required                    pam_faillock.so   preauth
auth      [success=1 default=bad]     pam_unix.so       try_first_pass nullok
auth      [default=die]               pam_faillock.so   authfail
auth      required                    pam_faillock.so   authsucc
```

`assets/pam.d/fprint`:

```
#%PAM-1.0

-auth     required    pam_fprintd.so    max-tries=1
```

`assets/pam.d/other` (defence in depth — with `confdir` set, a bad `config:` value falls
through to `other` in *this* directory, not `/etc/pam.d/other`):

```
#%PAM-1.0
auth      required    pam_deny.so
account   required    pam_deny.so
password  required    pam_deny.so
session   required    pam_deny.so
```

QML side:

```qml
PamContext {
    id: passwd
    config: "passwd"
    configDirectory: Quickshell.shellPath("assets/pam.d")
}
```

Note what is deliberately **omitted** relative to `system-auth`: `pam_systemd_home.so`
(irrelevant — no systemd-homed user here) and `pam_env.so` (an `auth`-stack env loader with
no bearing on the unlock decision). Both are safe to drop; both are also exactly the kind
of thing that will diverge from `pambase` over time.

### Option D — repo-local delegating to system policy

`assets/pam.d/passwd`:

```
#%PAM-1.0
auth      include   /etc/pam.d/system-auth
```

Verified to work by reading `_pam_open_config_file` (absolute paths bypass `confdir`), but
**not documented in `pam.d(5)`**. If this is chosen, pin it with a test.

---

## 5. The fprintd stack

ArchWiki [`fprint`](https://wiki.archlinux.org/title/Fprint) is the reference, as
instructed.

### Provisioning (nothing is installed yet)

```
# pacman -S fprintd            # 1.94.5-2; pulls libfprint 1.94.10-2
$ fprintd-enroll               # needs a running polkit authentication agent
$ fprintd-verify
```

Prints land in `/var/lib/fprint/`. The device (`06cb:00fc`, Synaptics Prometheus) is on
libfprint's supported list, so the stock `libfprint` should work — no `libfprint-tod` fork
needed.

Two device-specific items from the wiki that apply directly here:

- ArchWiki's "fprintd starts before fingerprint reader device is initialized after
  resuming from sleep" section uses **this exact USB ID** as its example, so expect to need
  `/etc/udev/rules.d/01-fingerprint.rules`:
  ```
  ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="06cb", ATTRS{idProduct}=="00fc", ATTR{power/persist}="1", RUN="/usr/bin/chmod 444 %S%p/../power/persist"
  ```
- By default **any user may enrol new fingerprints without authenticating**. Restrict it
  with the wiki's polkit rule on `net.reactivated.fprint.device.enroll` if that matters.

### Exact lines, and where they go

**The scoping answer is: do not edit any shared file. Create a new service name.**

Adding `pam_fprintd.so` to a *new* file that only the lock screen names is scoped
correctly **by construction** — sudo, su, sshd, polkit and login never resolve that
service name, so there is no path by which fingerprint can reach them. No negative
configuration, no exclusion list, nothing to get wrong.

| Target | File | Lines |
| --- | --- | --- |
| Lock screen only (Option A) | `/etc/pam.d/quickshell-fprint` (new) | `auth requisite pam_faillock.so preauth` / `-auth required pam_fprintd.so max-tries=1` |
| Lock screen only (Option B) | `<shellDir>/assets/pam.d/fprint` (new) | `-auth required pam_fprintd.so max-tries=1` |
| SDDM (opt-in, separate decision) | `/etc/pam.d/sddm` (existing, **edit**) | prepend the two lines below |
| **Never** | `system-auth`, `system-login`, `system-local-login`, `sudo`, `su`, `polkit-1` | — |

SDDM, per [ArchWiki SDDM § Using a fingerprint reader](https://wiki.archlinux.org/title/SDDM),
password-*or*-fingerprint variant, prepended to `/etc/pam.d/sddm`:

```
auth      [success=1 new_authtok_reqd=1 default=ignore]   pam_unix.so try_first_pass likeauth nullok
auth      sufficient                                      pam_fprintd.so
```

`/etc/pam.d/sddm` is consumed by SDDM alone (nothing includes it), so this is scoped. But
note ArchWiki's own warning on that section: *"Fingerprint support is not completely
working properly yet, and it seems logging in with only a password no longer works using
this method."* Treat SDDM as a separate, later, optional step, and test it with a root TTY
open.

Verification after any change:

```
$ grep -rn fprintd /etc/pam.d/
```
should match only the lock file (and `sddm`, if you opted in). Nothing else, ever.

### Why "never sudo" is right — the citable reason

ArchWiki's `fprint` page carries this warning:

> "This setting (fingerprint-only authentication) is a security breach if used for su,
> polkit, or sudo as it allows background processes to obtain permissions without prompting
> the user for a fingerprint (via fingerprint hijacking). See CVE-2024-37408."

[CVE-2024-37408](https://nvd.nist.gov/vuln/detail/cve-2024-37408) (CVSS 7.3, CWE-287):
*"fprintd through 1.94.3 lacks a security attention mechanism, and thus unexpected actions
might be authorized by `auth sufficient pam_fprintd.so` for Sudo."* The supplier disputes
it as a code bug, arguing the fix is a PAM configuration change — which is precisely the
point: **the mitigation is configuration scoping, so the constraint is permanent, not
something a version bump retires.** The installed repo version (1.94.5-2) is outside the
"through 1.94.3" range, but there is still no security-attention mechanism, so a
background process can raise a sudo prompt that the user's next legitimate finger-touch
silently authorizes.

### Do not put fingerprint and password in one stacked file

Quickshell's own `module.md` offers:

```
auth sufficient pam_fprintd.so
auth required pam_unix.so
```

ArchWiki flags the problem with exactly this shape:

> "Adding `pam_fprintd.so` as *sufficient* to any configuration file in `/etc/pam.d/` when
> a fingerprint signature is present will only prompt for fingerprint authentication. This
> prevents the use of a password if you cannot Ctrl+c fingerprint authentication (due to
> the lack of a shell)."

The mechanism, from `pam_fprintd.c`: the module blocks in a D-Bus verify loop
(`while (data->max_tries > 0)`) for up to `timeout` seconds per try — defaults
`DEFAULT_MAX_TRIES 3`, `DEFAULT_TIMEOUT 30`, i.e. up to 90 s — and never calls the
conversation function to request a response. Through `PamContext` that means
`responseRequired` stays `false` for the whole time, so the password field cannot submit.
A lock screen with this config is unusable if the reader is dirty.

**Every real Quickshell shell solves it the same way: two `PamContext` objects, two config
files, run concurrently, first success wins.** caelestia additionally sets `max-tries=1` and
drives the retry loop from QML, which is what makes a "keep scanning" UX possible.
This is a design constraint for the lock module spec, not just a PAM detail.

---

## 6. Failure delay and rate limiting

**Delay on failure.** `pam_faildelay` is installed but unused — nothing in `/etc/pam.d`
references it. The delay that actually exists comes from `pam_unix` itself:
`pam_unix(8)` documents the `nodelay` option as suppressing it, and says *"The default
action is for the module to request a delay-on-failure of the order of two seconds."*
So ~2 s per failed attempt, already active, inherited by anything that runs `pam_unix`.

**Rate limiting.** `pam_faillock` is active in `/etc/pam.d/system-auth` in the standard
Arch three-call arrangement (`preauth` / `authfail` / `authsucc`), with
`/etc/security/faillock.conf` entirely commented out, so the defaults apply:
`deny=3`, `fail_interval=900`, `unlock_time=600`. Today `hyprlock` inherits this via
`login → system-local-login → system-login → system-auth`.

> **Regression to watch:** a repo-local policy of just `auth required pam_unix.so` — the
> naive version, and what Quickshell's `module.md` example shows — **silently drops
> faillock**, so the lock screen would accept unlimited guesses at ~2 s each where hyprlock
> today locks the account after 3. If the repo-local option is chosen, the faillock lines
> must be copied in (caelestia does this correctly).

**Does `PamResult.MaxTries` correspond to `pam_faillock` tripping? No.**

Traced end to end:

- `pam_faillock(8)` RETURN VALUES: `PAM_AUTH_ERR` — *"An invalid option was given, the
  module was not able to retrieve the user name, no valid counter file was found, **or too
  many failed logins**."* It never returns `PAM_MAXTRIES`.
- Quickshell `subprocess.cpp` maps `PAM_AUTH_ERR → PamIpcExitCode::AuthFailed`, and
  `conversation.cpp` maps that to **`PamResult.Failed`**.
- The only `auth`-stack module here that returns `PAM_MAXTRIES` is `pam_fprintd`:
  `if (data->max_tries == 0) return PAM_MAXTRIES;`. Quickshell maps that to
  `PamResult.MaxTries`.

So in practice: **`MaxTries` means "fingerprint attempts exhausted", and account lockout
arrives as `Failed`.** Lockout is only distinguishable through `PamContext.message` — the
faillock text ("The account is locked due to N failed logins", "(N minutes left to
unlock)"). caelestia's lock module matches those exact strings, which independently
corroborates the mapping. The lock UI must read `message`, not the result code, to tell the
user they are locked out.

Two more mappings worth recording for the state machine ticket, both from
`subprocess.cpp`'s `default:` branch → `PamResult.Error`:

- `PAM_AUTHINFO_UNAVAIL` — what `pam_fprintd` returns when fprintd is not running, the
  device is absent/disconnected, no prints are enrolled, or the 30 s timeout expires. So
  "no fingerprint hardware" and "you took too long" both surface as **`Error`, not
  `Failed`**.
- `PAM_MODULE_UNKNOWN` — what the stack yields when `pam_fprintd.so` is not installed.
  Also `Error`. (Verified in `pam_dispatch.c`: a handler with `func == NULL` yields
  `PAM_MODULE_UNKNOWN`.)

**On the `-` prefix**: `pam.d(5)` says a leading `-` means PAM "will not log to the system
log if it is not possible to load the module". It is *only* a logging suppressor. Confirmed
in `pam_dispatch.c` — `PAM_HT_SILENT_MODULE` is not special-cased there; the handler is
still dispatched, still has `func == NULL`, and still returns `PAM_MODULE_UNKNOWN`, which
under `required` is a failure. **`-auth required pam_fprintd.so` therefore fails closed
when fprintd is absent** — which is exactly why KDE can ship
`/usr/lib/pam.d/kde-fingerprint` unconditionally, and why this repo can reference
`pam_fprintd.so` before installing it.

**One caveat on faillock under an unprivileged locker.** `open_tally()` in
`modules/pam_faillock/faillock.c` opens `/run/faillock/<user>` with `O_CREAT`, but
`/run/faillock` is `drwxr-xr-x root root` — an unprivileged process cannot create the file.
On `EACCES`, both `check_tally` and `write_tally` return `PAM_SUCCESS`, i.e. **faillock
silently no-ops**. On this machine `/run/faillock/dai` already exists as
`-rw-rw---- dai:root` (created by a root-context authentication, i.e. the SDDM login), so
an unprivileged lock screen can read and write it and faillock works normally. Since SDDM
authenticates before the shell ever runs, this holds in practice — but it is worth knowing
that faillock's enforcement here depends on a root-created file, and that the same
user-writability means `faillock --reset` is available unprivileged.

---

## 7. Deployment (if a root-owned file is chosen)

`/etc/pam.d` is outside everything this repo manages. The repo currently has exactly one
thing in `scripts/` — `scripts/colors/apply-colors.sh` — and no install step, no
`Makefile`, no packaging.

Three ways to close the gap, in rough order of how well they fit what is already here:

1. **A documented manual step.** A short section in `AGENTS.md` / a `lock/README` giving
   the file contents and the `install -o root -g root -m 644` command. Zero machinery,
   honest about being a one-time-per-machine action. The weakness is that it is invisible
   at deploy time: the failure only shows up when the lock screen errors on a new machine.
   Mitigable by having the lock module detect the missing policy (a `PamResult.Error`
   with a "policy not installed" hint) rather than failing mutely.
2. **`scripts/install-pam-policy.sh`.** Fits the existing `scripts/` convention. It must
   be idempotent, refuse to overwrite a differing existing file without `--force`, use
   `install -D -o root -g root -m 644`, and — importantly — **only ever create new service
   names**, never touch `system-auth`/`login`/`system-login`. The script itself lives in a
   user-writable repo and is run with `sudo`, so it is not a security boundary; it is
   ergonomics. Say so in the script rather than implying otherwise.
3. **Move it up to the `dotfiles` superrepo.** `~/.config/quickshell` is a submodule of
   `dotfiles`, which is the layer that already owns machine-level setup (`hyprpaper.conf`,
   `hypridle.conf`, autostart). A root-owned PAM policy is arguably *that* repo's concern,
   not this one's — this repo is a shell config. That keeps `quickshell_config` free of
   root-touching scripts and puts the file next to the other machine-level state. Downside:
   it splits the lock feature across two repos, and the shell would depend on something it
   cannot see.

Note that **option B (repo-local) makes this whole question disappear**, and that is a real
part of its value on a repo explicitly designed to be cloned onto new machines. Whether
that outweighs the `system-auth` drift cost in §3 is exactly the decision #51 has to make.

---

## 8. Lockout risk and safe test procedure

**Read this before touching anything.** ArchWiki `PAM` carries the standing warning:

> "Changes to the PAM configuration fundamentally affect user authentication. Erroneous
> changes can result in that **no user** can log in, or **all users** being able to log in."

Concrete risks, ranked:

1. **Editing `system-auth`, `login`, `system-login`, or `system-local-login` can lock every
   account out of the machine.** A syntax error, a wrong control flag, or a module name
   typo in any of these takes effect immediately, for the *next* authentication, with no
   reload and no warning. Recovery is an Arch install medium and `arch-chroot`. **None of
   the options in §3 require touching these files. Do not touch them.**
2. **A broken lock policy costs the graphical session.** If the lock screen cannot
   authenticate, the compositor keeps the screen locked — that is the design, per
   `WlSessionLock`'s docs ("will not expose your session, but it will render it
   inoperable"). Recovery is: switch to a TTY (Ctrl+Alt+F2), log in, fix the file, and
   restart quickshell. *I could not verify on this machine whether Hyprland lets a
   restarted client take over an orphaned `ext-session-lock`; if it does not, the fallback
   is killing the compositor and losing the session's window state.* Treat "the lock
   screen cannot authenticate" as a session-loss event, not an inconvenience.
3. **Editing `/etc/pam.d/sddm` can lock you out of graphical login.** ArchWiki explicitly
   reports that after adding fingerprint to SDDM, "logging in with only a password no
   longer works using this method". You would still have TTY login. This is a good reason
   to treat SDDM fingerprint as a separate, later change.
4. **`fprintd` not installed is safe**, per §6 — `-auth required pam_fprintd.so` fails
   closed rather than passing. Referencing the module before installing it is not a risk.

### Safe test procedure

1. **Open a root shell on another VT first and leave it open.** Ctrl+Alt+F2, log in, `su -`.
   ArchWiki's PAM page recommends exactly this: *"login preferably locally on the testing
   machine and develop, keeping the session constantly running, while checking the results
   from another user on another console."* Do this **before** the first edit, not after
   something breaks.
2. **Back up before editing:** `cp -a /etc/pam.d /root/pam.d.bak.$(date +%F)`.
3. **Test the policy in isolation before wiring it to the lock**, with `pamtester` (AUR,
   listed on ArchWiki's PAM page):
   `pamtester quickshell-lock "$USER" authenticate` — a plain pass/fail, no session at
   risk. For the repo-local option this only works against `/etc/pam.d`, so test the file
   contents by temporarily copying them there under a throwaway service name, or accept
   that the first real test is the lock screen itself.
4. **Disable `hypridle` while iterating** so nothing locks the screen mid-edit.
5. **Keep hyprlock working** — leave `/etc/pam.d/hyprlock` and the hyprlock binary in place
   until the Quickshell lock is proven. It is the fallback locker.
6. **Test the dev clone as its own instance**, per `AGENTS.md`:
   `killall quickshell; qs -p ~/ghq/github.com/bhdai/quickshell_config`.
7. **Test the failure paths deliberately**: wrong password 4× (should hit faillock and
   surface the lockout text in `message`), and — once fprintd is installed — an unenrolled
   finger and a disconnected reader (both should surface as `PamResult.Error`).
8. Watch `journalctl -f` while testing. PAM logs configuration errors to syslog; a
   malformed line produces an entry there and nothing in the UI.

---

## 9. Sources

**Tier A — primary**

- Quickshell 0.3.0 [`PamContext`](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Pam/PamContext),
  [`WlSessionLock`](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlSessionLock),
  [`Quickshell`](https://quickshell.org/docs/v0.3.0/types/Quickshell/Quickshell)
- Quickshell source (GitHub mirror, `master`): `src/services/pam/{qml.hpp, conversation.hpp,
  conversation.cpp, subprocess.cpp, module.md}`
- Linux-PAM source (`linux-pam/linux-pam`, `master`): `libpam/pam_handlers.c`,
  `libpam/pam_dispatch.c`, `modules/pam_faillock/{pam_faillock.c, faillock.c}`
- fprintd source: [`pam/pam_fprintd.c`](https://gitlab.freedesktop.org/libfprint/fprintd/-/blob/master/pam/pam_fprintd.c)
- Local man pages (pam 1.7.2-2): `pam.d(5)`, `pam_start_confdir(3)`, `pam_unix(8)`,
  `pam_faillock(8)`, `faillock(8)`
- ArchWiki [`fprint`](https://wiki.archlinux.org/title/Fprint),
  [`PAM`](https://wiki.archlinux.org/title/PAM),
  [`SDDM`](https://wiki.archlinux.org/title/SDDM) (all read as raw wikitext)
- [CVE-2024-37408](https://nvd.nist.gov/vuln/detail/cve-2024-37408) (NVD)
- [libfprint supported devices](https://fprint.freedesktop.org/supported-devices.html)
- This machine: `/etc/pam.d/*`, `/usr/lib/pam.d/*`, `/etc/security/faillock.conf`,
  `/run/faillock/`, `lsusb`, `pacman -Q`

**Tier B — practitioner**

- [swaylock upstream `pam/swaylock`](https://github.com/swaywm/swaylock/blob/master/pam/swaylock)
  — the origin of hyprlock's `auth include login`
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) `modules/lock/Pam.qml`,
  `assets/pam.d/{passwd,fprint,howdy}`
- [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
  `quickshell/Modules/Lock/Pam.qml`, `quickshell/assets/pam/{login,fprint,u2f,other}`
- GitHub code search for `configDirectory` in QML (~15 shells, table in §1)

**Single-source / unverified, flagged in place**

- `include <absolute path>` bypassing `confdir` — source-verified in
  `_pam_open_config_file`, undocumented in `pam.d(5)`.
- Whether Hyprland lets a restarted client take over an orphaned `ext-session-lock` — not
  tested (no display available to this session).
