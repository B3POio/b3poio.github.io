`// start of transmission`

```text
admin@server:~$ ./ca-trust-update.sh --audit

[BOOT]    linux distribution detected
[CA]      certificate trust assessment started
[CHECK]   compromised root certificates... VERIFYING
[PATCH]   installed security package versions... VERIFYING
[DOCKER]  inspected only if the daemon and containers are running
[SAFETY]  container restart, prune and rebuild commands... DISABLED
[LOG]     local report saved

// BEGIN MAINTENANCE LOG
```

# Certificate Trust: Patching the Chain Without Taking Down the Server

In October 2026, several eMudhra (emSign) intermediate certificate authority private keys were exposed. Related vulnerability tracking includes CVE-2026-114406 (Linux CA bundles), CVE-2026-111943 (Go) and CVE-2026-91403 (Java). A person holding those keys and positioned between a server and a service it communicates with could potentially impersonate a legitimate HTTPS endpoint. A familiar padlock means very little if the certificate chain itself is compromised.

The fix is not to delete every certificate that looks unfamiliar. It's to install the trusted certificate authority updates from the operating system vendor, confirm that the affected roots are no longer trusted and check the software that maintains separate certificate stores.

I dealt with this on Ubuntu 26.04.1 LTS. The CA package was updated and the Docker containers remained up. That is the goal of this process: change as little as necessary, inspect before and after and leave running applications alone wherever practical.

## The Problem: A Trusted Root Can Become a Liability

`$ openssl verify`

The October 2026 incident affected intermediate authorities under the emSign hierarchy. In particular, the root named `emSign ECC Root CA - G3` was removed from several system trust bundles. Some chains could also lead to `AAA Certificate Services` through cross-signing, so the exact remediation differs between distributions.

An empty `trust list --filter=blocklist` is **not** evidence of a vulnerability. Many fixed packages remove a root from the active trusted bundle rather than adding an entry to an explicit blocklist.

The important checks are the installed **vendor security package version**, the **actual trusted CA bundle** and, where available, the **p11-kit trusted anchor list**.

## One Repository, Two Kinds of Files

`$ tree var srv`

This repository already uses `/var/log/b3po/` for transmissions and writing. I'm adding `/srv/b3po/scripts/` as a server-specific home for operational utilities, following the same Linux filesystem analogy.

```text
b3poio.github.io/
|-- var/
|   `-- log/
|       `-- b3po/
|           `-- certificate-trust-maintenance.md
`-- srv/
    `-- b3po/
        `-- scripts/
            `-- ca-trust-update.sh
```

The files live **inside the repository**. You do not need to copy them into the actual `/srv` or `/var/log` directories on your machine. These paths are organizational conventions, not installation requirements.

## Run an Assessment First

`$ bash srv/b3po/scripts/ca-trust-update.sh --audit`

After reviewing the script, clone the repository and run it as your **regular user**:

```bash
git clone https://github.com/B3POio/b3poio.github.io.git
cd b3poio.github.io
bash srv/b3po/scripts/ca-trust-update.sh --audit
```

The interactive menu offers automatic Linux detection or a manual choice of Ubuntu, Debian, Fedora, RHEL-family or Arch. It refuses a selection that doesn't match the actual machine, rather than running the wrong package manager.

The default is **read-only**. It reports the current distribution, CA and NSS versions, any known affected roots in the OpenSSL bundle and p11-kit trust anchors when the `trust` command is available. You do not need to install p11-kit just for this check. If it detects that it is running *inside a container*, it warns and refuses update mode: patch the host from the host.

Results are logged privately in `~/.local/state/b3po/ca-trust/` (or the configured XDG state directory).

## Apply a Targeted Security Update

`$ bash srv/b3po/scripts/ca-trust-update.sh --update`

```bash
bash srv/b3po/scripts/ca-trust-update.sh --update
```

For Ubuntu and Debian, the tool refreshes APT metadata, prints a **dry-run transaction** for `ca-certificates` and, on Ubuntu when already installed, `libnss3`. It refuses a transaction that would remove or upgrade unrelated packages. It applies only the proposed targeted upgrades after you type `UPDATE`, then regenerates the CA bundle and audits again. If everything it checks is already patched, it makes no changes.

For Fedora and the RHEL family, the script targets `ca-certificates` and installed `nss` packages through DNF. It also requires confirmation and regenerates the system CA trust extraction.

**Arch Linux is audit-only in this script.** Arch recommends `ca-certificates-mozilla >= 3.131.1-1`, but partial package upgrades aren't supported. Plan a maintenance window for a normal `sudo pacman -Syu`, then rerun the audit.

The utility does **not** run `apt full-upgrade`, `apt autoremove`, `dnf distro-sync`, `pacman -Syu`, force a reboot, manually delete root certificates or pin packages to old versions.

Package managers can still execute maintainer hooks or trigger service reloads as part of installing even targeted updates. No maintenance script can guarantee zero downtime on every server. Review the displayed transaction and use a maintenance window for especially sensitive workloads.

## Docker: Check Only If It's Actually Running

`$ docker ps`

The script checks for Docker **only when applying an update**, and only proceeds with the Docker inspection when the Docker CLI exists and the daemon responds. If there are no running containers, it skips the comparison.

If containers are running, it captures their IDs before the OS package update and checks them again afterward. The script never executes `docker stop`, `docker restart`, `docker compose`, `docker system prune` or any image or volume modification command.

A successful host CA update **does not patch an old container image**. A container may contain its own CA store or a Node.js, Python, Java or other bundled trust store. Existing containers can keep serving traffic, but affected images still need to be rebuilt and redeployed later under normal change control. Do not assume that updating the host automatically changes TLS validation inside those containers.

## What Counts as Patched?

`$ dpkg-query -W ca-certificates libnss3`

The script checks published minimums when available:

| Distribution | Component | Security-fixed version |
| --- | --- | --- |
| Ubuntu 26.04 LTS | `ca-certificates` | `20260816ubuntu0.26.04.1` |
| Ubuntu 26.04 LTS | `libnss3` | `2:3.120-1ubuntu2.2` |
| Debian 13 | `ca-certificates` | `20250419+deb13u1` |
| Debian 12 | `ca-certificates` | `20250419~deb12u2` |
| Arch Linux | `ca-certificates-mozilla` | `3.131.1-1` |

For other Ubuntu releases the script also includes the corresponding fixed package minimums. Fedora and RHEL-family versions vary by release and repository, so their package version is reported for review instead of claiming an unverified threshold.

A reported `FAIL` requires attention. `WARN` means verification is incomplete or needs a distribution-specific review. Certificate subjects found in a bundle do not, on their own, reveal every possible cross-signed trust path, which is why the official advisory and updated vendor packages matter.

## What This Does Not Fix

`// trust nothing, verify everything`

A system-wide Linux trust-store update is one layer. It does not guarantee that every TLS consumer on the machine has been repaired. Browsers, Java runtimes, Node.js executables, Python `certifi`, compiled binaries, appliances and Docker images may carry different roots or different revocation logic.

Canonical also notes an **Ubuntu Java trust-store synchronization issue**: if Java is installed, consult its official October 2026 guidance before touching `/etc/ssl/certs/java/cacerts`. Rebuilding that Java store without accounting for locally added CA certificates can break application connections. The script deliberately never deletes or regenerates the Java store.

For macOS, use the separate Apple and application vendor guidance. **This script intentionally refuses to run on macOS**, rather than guessing how to edit the macOS trust store or forcing an operating system update that might require a reboot.

Keep the regular operating system security update process enabled so the fixed certificates are not replaced by an older bundle. Avoid manually restoring old CA bundles as a rollback. If the incident broke a dependency, find and replace the affected service certificate instead of silently trusting the compromised issuer again.

### Official Advisories

- [Canonical: eMudhra incident, including Java remediation](https://ubuntu.com/blog/emudhra-ca-compromise-fixes-available)
- [Ubuntu USN-8944-1: CA certificates](https://ubuntu.com/security/notices/USN-8944-1)
- [Ubuntu USN-8947-1: NSS](https://ubuntu.com/security/notices/USN-8947-1)
- [Debian DSA-6572-1: CA certificates](https://lists.debian.org/debian-security-announce/2026/msg00487.html)
- [Debian DLA-4845-1: Debian 12](https://lists.debian.org/debian-lts-announce/2026/10/msg00039.html)
- [Arch Linux: CA certificate security update](https://archlinux.org/news/update-to-ca-certificates-mozilla-31311-1-to-prevent-man-in-the-middle-attacks/)
- [Red Hat RHSB-2026-012: eMudhra certificate compromise](https://access.redhat.com/security/vulnerabilities/RHSB-2026-012)
- [Google Chrome security analysis](https://blog.google/security/protecting-chrome-and-android-users-from-compromised-emudhra-intermediate-ca-certificates/)

The principle is simple: patch the chain, verify the result and leave unrelated infrastructure untouched.

Beep boop.

---

[B3PO](https://b3po.io)  
Human-cyborg relations.

```text
// END MAINTENANCE LOG

[CA]      trust assessment complete
[HOST]    no automatic reboot requested
[DOCKER]  no container changes performed
[LOG]     report saved for later verification
[SYS]     transmission complete

admin@server:~$ exit
logout
```

`// end of transmission`

`return 0;`
