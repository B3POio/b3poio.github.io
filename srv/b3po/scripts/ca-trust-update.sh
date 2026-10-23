#!/usr/bin/env bash
# b3po ca-trust-update: audit first, optionally update vendor CA packages.
# Host-only; does not manage Docker, remove CA files or restart services.
set -Eeuo pipefail
umask 077

MODE=audit
REQUESTED_OS=menu
ISSUES=0
WARNINGS=0
DOCKER_MONITOR=0
DOCKER_BEFORE=""

usage() {
  cat <<'HELP'
Usage: bash ca-trust-update.sh [--audit | --update] [--os auto|ubuntu|debian|fedora|rhel|arch]

  --audit     Read-only security assessment (default)
  --update    Preview and, after typing UPDATE, apply targeted CA updates
  --os        Select Linux OS; without this option, interactive users get a menu
  --help      Display this help

Run as a normal user. Sudo is requested only for optional package updates.
The script does not modify Docker containers or restart services.
Arch Linux is audit-only: a full pacman -Syu belongs in a maintenance window.
HELP
}

while (($#)); do
  case "$1" in
    --audit) MODE=audit ;;
    --update) MODE=update ;;
    --os)
      if (($# < 2)); then echo "Missing value for --os" >&2; exit 2; fi
      REQUESTED_OS="$2"
      shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != Linux ]]; then
  echo "This script is Linux-only. macOS uses a different trust store." >&2
  exit 2
fi
if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify this Linux distribution (/etc/os-release missing)." >&2
  exit 2
fi
# shellcheck source=/dev/null
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"
OS_NAME="${PRETTY_NAME:-$OS_ID}"

case "$OS_ID" in
  ubuntu|debian|fedora|rhel|rocky|almalinux|centos|ol|arch) ;;
  *) echo "Unsupported Linux distribution: $OS_NAME. No changes made." >&2; exit 2 ;;
esac

if [[ "$REQUESTED_OS" == menu ]]; then
  if [[ ! -t 0 ]]; then
    REQUESTED_OS=auto
  else
    printf '\nSelect your Linux operating system:\n'
    printf '  1) Auto-detect (%s)\n' "$OS_NAME"
    printf '  2) Ubuntu\n  3) Debian\n  4) Fedora\n'
    printf '  5) RHEL / Rocky / AlmaLinux / CentOS / Oracle Linux\n'
    printf '  6) Arch Linux\n  0) Cancel\n'
    read -r -p 'Selection [1]: ' CHOICE
    case "${CHOICE:-1}" in
      1) REQUESTED_OS=auto ;;
      2) REQUESTED_OS=ubuntu ;;
      3) REQUESTED_OS=debian ;;
      4) REQUESTED_OS=fedora ;;
      5) REQUESTED_OS=rhel ;;
      6) REQUESTED_OS=arch ;;
      0) exit 0 ;;
      *) echo "Invalid selection. No changes made." >&2; exit 2 ;;
    esac
  fi
fi

case "$REQUESTED_OS" in
  auto) ;;
  ubuntu|debian|fedora|arch)
    if [[ "$OS_ID" != "$REQUESTED_OS" ]]; then
      echo "Selection does not match detected OS ($OS_NAME). Refusing to proceed." >&2
      exit 2
    fi ;;
  rhel)
    case "$OS_ID" in
      rhel|rocky|almalinux|centos|ol) ;;
      *) echo "Selection does not match detected OS ($OS_NAME)." >&2; exit 2 ;;
    esac ;;
  *) echo "Unsupported --os value: $REQUESTED_OS" >&2; exit 2 ;;
esac

case "$OS_ID" in
  ubuntu|debian) FAMILY=apt ;;
  fedora|rhel|rocky|almalinux|centos|ol) FAMILY=dnf ;;
  arch) FAMILY=arch ;;
esac

# Log only in the user's state folder. Never touch application data.
STATE_DIR="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/b3po/ca-trust"
if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  echo "Could not create log directory: $STATE_DIR" >&2
  exit 2
fi
LOG_FILE="$STATE_DIR/$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
warn() { WARNINGS=$((WARNINGS+1)); printf '[WARN] %s\n' "$*"; }
fail() { ISSUES=$((ISSUES+1)); printf '[FAIL] %s\n' "$*"; }

run_admin() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Sudo is required to update packages. No changes made." >&2
    return 1
  fi
}

installed_deb_version() {
  dpkg-query -W -f='${Status}\t${Version}\n' "$1" 2>/dev/null | awk -F '\t' '$1 == "install ok installed" {print $2}' || true
}

check_min_deb() {
  local package="$1" minimum="$2" installed
  installed="$(installed_deb_version "$package")"
  if [[ -z "$installed" ]]; then
    if [[ "$package" == ca-certificates ]]; then
      fail "Required ca-certificates package is not installed"
    else
      info "$package: not installed"
    fi
    return
  fi
  info "$package installed: $installed"
  if [[ -z "$minimum" ]]; then
    warn "$package: no fixed-version baseline recorded for $OS_NAME; check vendor advisory"
  elif dpkg --compare-versions "$installed" ge "$minimum"; then
    pass "$package meets published minimum ($minimum)"
  else
    fail "$package is older than the security-fixed minimum ($minimum)"
  fi
}

check_packages() {
  printf '\n--- Distribution packages ---\n'
  case "$FAMILY" in
    apt)
      local ca_min="" nss_min=""
      if [[ "$OS_ID" == ubuntu ]]; then
        case "$OS_VERSION" in
          22.04) ca_min=20260816ubuntu0.22.04.1; nss_min=2:3.98-0ubuntu0.22.04.5 ;;
          24.04) ca_min=20260816ubuntu0.24.04.1; nss_min=2:3.98-1ubuntu0.3 ;;
          26.04) ca_min=20260816ubuntu0.26.04.1; nss_min=2:3.120-1ubuntu2.2 ;;
          26.10) ca_min=20260816ubuntu0.26.10.1; nss_min=2:3.127-1ubuntu0.1 ;;
        esac
      elif [[ "$OS_ID" == debian ]]; then
        case "$OS_VERSION" in
          12) ca_min='20250419~deb12u2' ;;
          13) ca_min='20250419+deb13u1' ;;
        esac
      fi
      check_min_deb ca-certificates "$ca_min"
      if [[ "$OS_ID" == ubuntu ]]; then
        check_min_deb libnss3 "$nss_min"
      else
        local nss_version
        nss_version="$(installed_deb_version libnss3)"
        if [[ -n "$nss_version" ]]; then
          info "libnss3 installed: $nss_version (check Debian NSS security advisories separately)"
        else
          info "libnss3: not installed"
        fi
      fi ;;
    dnf)
      if ! command -v rpm >/dev/null 2>&1; then
        warn "rpm not found; cannot inspect package versions"
      else
        rpm -q ca-certificates || warn "ca-certificates package not found"
        rpm -q nss || info "nss package not installed"
      fi
      warn "RPM vendor fixed versions vary; confirm security errata and the trust-store checks below" ;;
    arch)
      if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found; cannot inspect package versions"
      else
        local current
        current="$(pacman -Q ca-certificates-mozilla 2>/dev/null | awk '{print $2}')"
        if [[ -z "$current" ]]; then
          fail "ca-certificates-mozilla package not found"
        else
          info "ca-certificates-mozilla: $current"
          if command -v vercmp >/dev/null 2>&1; then
            local compared
            compared="$(vercmp "$current" '3.131.1-1')"
            if [[ "$compared" -ge 0 ]]; then
              pass "Meets Arch fixed minimum: 3.131.1-1"
            else
              fail "Below Arch fixed minimum: 3.131.1-1"
            fi
          else
            warn "vercmp not available to compare versions"
          fi
        fi
      fi ;;
  esac
}

check_bundle() {
  printf '\n--- Active OpenSSL CA bundle ---\n'
  local bundle="" subjects=""
  for candidate in \
    /etc/ssl/certs/ca-certificates.crt \
    /etc/pki/tls/certs/ca-bundle.crt \
    /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; do
    if [[ -s "$candidate" ]]; then bundle="$candidate"; break; fi
  done
  if [[ -z "$bundle" ]]; then
    warn "No standard CA bundle found; cannot verify OpenSSL trust"
    return
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    warn "openssl is not installed; cannot inspect the CA bundle"
    return
  fi
  info "Bundle: $bundle"
  if ! subjects="$(openssl crl2pkcs7 -nocrl -certfile "$bundle" 2>/dev/null | openssl pkcs7 -print_certs -noout 2>/dev/null)"; then
    warn "OpenSSL failed to parse the bundle; verification is incomplete"
    return
  fi
  # Subject lines only: an issuer reference does not mean that issuer is trusted.
  subjects="$(printf '%s\n' "$subjects" | grep '^subject=' || true)"
  if grep -Eiq 'emSign ECC Root CA - G3|emSign Root TLS CA - G3' <<< "$subjects"; then
    fail "An affected emSign G3 certificate appears in the CA bundle"
  else
    pass "Affected emSign G3 subjects not found in the CA bundle"
  fi
  if grep -Eiq 'AAA Certificate Services|Comodo AAA Services root' <<< "$subjects"; then
    if [[ "$OS_ID" == debian ]]; then
      fail "Comodo/AAA root found; Debian's published fix removes it"
    else
      warn "Comodo/AAA root found; review vendor policy for the cross-signing path"
    fi
  else
    pass "Comodo/AAA root subjects not found in the CA bundle"
  fi
}

check_p11() {
  if ! command -v trust >/dev/null 2>&1; then return; fi
  printf '\n--- Additional p11-kit trust anchors ---\n'
  local anchors
  if ! anchors="$(trust list --filter=ca-anchors 2>/dev/null)"; then
    warn "Could not query p11-kit trust anchors"
    return
  fi
  if grep -Eiq 'label:.*emSign (ECC Root CA|Root TLS CA) - G3' <<< "$anchors"; then
    fail "p11-kit still lists an affected emSign G3 trusted anchor"
  else
    pass "No affected emSign G3 trusted anchor found by p11-kit"
  fi
  info "An empty p11-kit blocklist is normal; removed roots need not appear there"
}

# Docker is OPTIONAL. Do not query it unless the executable and daemon work.
check_docker_before() {
  [[ "$MODE" == update ]] || return 0
  command -v docker >/dev/null 2>&1 || return 0
  docker info --format '{{.ServerVersion}}' >/dev/null 2>&1 || return 0
  local ids
  if ! ids="$(docker ps --format '{{.ID}}' 2>/dev/null | LC_ALL=C sort)"; then return 0; fi
  if [[ -z "$ids" ]]; then
    info "Docker is available, but no containers are running; no Docker snapshot needed"
    return 0
  fi
  DOCKER_MONITOR=1
  DOCKER_BEFORE="$ids"
  info "Docker running: $(printf '%s\n' "$ids" | wc -l | tr -d ' ') running container(s) recorded"
}

check_docker_after() {
  [[ "$DOCKER_MONITOR" == 1 ]] || return 0
  local current stopped
  if ! current="$(docker ps --format '{{.ID}}' 2>/dev/null | LC_ALL=C sort)"; then
    warn "Docker status could not be checked after the update"
    return
  fi
  stopped="$(comm -23 <(printf '%s\n' "$DOCKER_BEFORE") <(printf '%s\n' "$current"))"
  if [[ -z "$stopped" ]]; then
    pass "All previously running Docker containers are still running"
  else
    warn "Some previously running Docker containers are no longer running: $stopped"
    info "Container state can change independently; investigate rather than assuming causation"
  fi
}

apply_apt() {
  local pkgs=(ca-certificates)
  if [[ "$OS_ID" == ubuntu ]] && [[ -n "$(installed_deb_version libnss3)" ]]; then
    pkgs+=(libnss3)
  fi
  info "Refreshing APT package metadata (no services or containers modified)"
  run_admin apt-get update
  info "APT dry run for ONLY: ${pkgs[*]}"
  local plan extra_packages
  plan="$(apt-get -s install --only-upgrade --no-install-recommends "${pkgs[@]}")" || return 1
  printf '%s\n' "$plan"
  if grep -Eq '^Remv ' <<< "$plan"; then
    echo "APT plans a package removal. Stopping to protect unrelated software." >&2
    return 1
  fi
  extra_packages="$(printf '%s\n' "$plan" | awk '$1 == "Inst" && $2 != "ca-certificates" && $2 != "libnss3" {print $2}' | sort -u)"
  if [[ -n "$extra_packages" ]]; then
    printf 'APT would also change other packages: %s\n' "$extra_packages" >&2
    echo "Stopping. Review dependencies manually during a maintenance window." >&2
    return 1
  fi
  if ! grep -Eq '^Inst ' <<< "$plan"; then
    info "No targeted APT upgrades available; leaving the CA bundle unchanged"
    return 0
  fi
  printf '\nOnly the named packages will be upgraded if available.\n'
  read -r -p 'Review the plan above. Type UPDATE to apply it: ' answer
  if [[ "$answer" != UPDATE ]]; then
    info "Cancelled. No packages upgraded."
    return 1
  fi
  run_admin env NEEDRESTART_MODE=l apt-get install --only-upgrade --no-install-recommends "${pkgs[@]}"
  run_admin update-ca-certificates
}

apply_dnf() {
  local pkgs=(ca-certificates)
  if command -v rpm >/dev/null 2>&1 && rpm -q nss >/dev/null 2>&1; then
    pkgs+=(nss)
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf not found. No changes made." >&2
    return 1
  fi
  info "Available targeted upgrades:"
  local status=0
  dnf check-update "${pkgs[@]}" || status=$?
  if [[ "$status" -eq 0 ]]; then
    info "No targeted DNF upgrades available; leaving the CA bundle unchanged"
    return 0
  elif [[ "$status" -ne 100 ]]; then
    echo "DNF could not check for updates (exit $status). No changes made." >&2
    return 1
  fi
  printf '\nTargeted packages: %s\n' "${pkgs[*]}"
  read -r -p 'Type UPDATE to apply these vendor packages: ' answer
  if [[ "$answer" != UPDATE ]]; then
    info "Cancelled. No packages upgraded."
    return 1
  fi
  run_admin dnf upgrade --refresh "${pkgs[@]}"
  if command -v update-ca-trust >/dev/null 2>&1; then
    run_admin update-ca-trust extract
  fi
}

printf '\n// certificate trust assessment\n'
info "Host: $OS_NAME"
info "Mode: $MODE"
info "Log: $LOG_FILE"
info "Scope: OS trust store and selected CA/NSS packages; no broad OS upgrades"
if [[ -f /.dockerenv || -f /run/.containerenv ]]; then
  warn "This command is running INSIDE a container; it cannot patch the host"
  if [[ "$MODE" == update ]]; then
    echo "Run this update directly on the Linux host. No changes made." >&2
    exit 2
  fi
fi
check_packages
check_bundle
check_p11
if [[ "$OS_ID" == ubuntu ]] && command -v java >/dev/null 2>&1; then
  warn "Java detected: Canonical documents a separate Java cacerts synchronization issue; see the guide"
fi

if [[ "$MODE" == update ]] && ((ISSUES == 0 && WARNINGS == 0)); then
  pass "This host already meets the recorded package baselines with no affected roots found"
  info "Skipping unnecessary package updates; nothing was modified"
  exit 0
fi

if [[ "$MODE" == update ]]; then
  if [[ ! -t 0 ]]; then
    warn "Update mode requires an interactive terminal"
    exit 2
  fi
  if [[ "$FAMILY" == arch ]]; then
    warn "Arch requires a supported full-system pacman -Syu; not safe to perform as a targeted live-server update"
    info "Plan an Arch maintenance window, run sudo pacman -Syu, then re-run --audit"
    exit 2
  fi
  check_docker_before
  printf '\n--- Requested update ---\n'
  if [[ "$FAMILY" == apt ]]; then
    apply_apt
  else
    apply_dnf
  fi
  printf '\n--- Post-update verification ---\n'
  ISSUES=0
  WARNINGS=0
  check_packages
  check_bundle
  check_p11
  check_docker_after
fi

printf '\n--- Result ---\n'
info "Log saved to $LOG_FILE"
if ((ISSUES > 0)); then
  printf '[RESULT] ATTENTION REQUIRED: %d finding(s), %d warning(s).\n' "$ISSUES" "$WARNINGS"
  exit 2
elif ((WARNINGS > 0)); then
  printf '[RESULT] REVIEW WARNINGS: no confirmed failures; %d warning(s).\n' "$WARNINGS"
  exit 1
fi
pass "Known affected trust roots absent in checked stores; recorded package baselines pass"
info "This does not assess app-bundled CA stores or existing container image layers"
exit 0
