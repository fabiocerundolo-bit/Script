#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
PHASE="all"
DRY_RUN=0

# Optional settings (override via environment variables before running the script)
: "${DOTFILES_DIR:=$HOME/dotfiles}"
: "${DOTFILES_NIRI_FILE:=niri/config.kdl}"
: "${INSTALL_THROTTLED:=0}"

log() {
	printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

warn() {
	printf '[%s] WARNING: %s\n' "$SCRIPT_NAME" "$*" >&2
}

die() {
	printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
	./setupT480.sh [--all] [--phase N] [--dry-run] [--help]

Options:
	--all        Run all phases (default)
	--phase N    Run only one phase (1..7)
	--dry-run    Print commands without executing them
	--help       Show this help

Environment variables:
	DOTFILES_DIR         Dotfiles root directory (default: $HOME/dotfiles)
	DOTFILES_NIRI_FILE   Niri config path inside dotfiles (default: niri/config.kdl)
	INSTALL_THROTTLED    Install throttled from AUR (0/1, default: 0)
EOF
}

run_cmd() {
	if [[ "$DRY_RUN" == "1" ]]; then
		printf '[%s] DRY-RUN: ' "$SCRIPT_NAME"
		printf '%q ' "$@"
		printf '\n'
		return 0
	fi

	"$@"
}

require_sudo() {
	if [[ "$DRY_RUN" == "1" ]]; then
		log "Dry-run mode enabled: skipping sudo authentication"
		return
	fi

	if [[ $EUID -eq 0 ]]; then
		return
	fi

	if ! command -v sudo >/dev/null 2>&1; then
		die "sudo is required to run this script"
	fi

	sudo -v
}

pacman_install() {
	if [[ $# -eq 0 ]]; then
		return
	fi

	run_cmd sudo pacman -S --needed --noconfirm "$@"
}

choose_aur_helper() {
	if command -v cachyos-helper >/dev/null 2>&1; then
		printf 'cachyos-helper'
		return
	fi

	if command -v yay >/dev/null 2>&1; then
		printf 'yay'
		return
	fi

	if command -v paru >/dev/null 2>&1; then
		printf 'paru'
		return
	fi

	printf ''
}

aur_install() {
	local helper
	helper="$(choose_aur_helper)"

	if [[ -z "$helper" ]]; then
		warn "No AUR helper found. Skipping AUR packages: $*"
		return
	fi

	run_cmd "$helper" -S --needed --noconfirm "$@"
}

refresh_mirrors() {
	if command -v cachyos-rate-mirrors >/dev/null 2>&1; then
		log "Refreshing mirror list with cachyos-rate-mirrors"
		run_cmd sudo cachyos-rate-mirrors
		return
	fi

	if command -v rate-mirrors >/dev/null 2>&1; then
		log "Refreshing mirror list with rate-mirrors"
		run_cmd sudo rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch
		return
	fi

	if command -v reflector >/dev/null 2>&1; then
		log "Refreshing mirror list with reflector"
		run_cmd sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
		return
	fi

	warn "No mirror ranking tool found. Skipping mirror optimization"
}

check_microarch_repo() {
	if grep -RqiE 'x86-64-v3|cachyos-v3' /etc/pacman.conf /etc/pacman.d 2>/dev/null; then
		log "Detected x86-64-v3/CachyOS microarchitecture repository configuration"
	else
		warn "x86-64-v3 repository not detected in pacman configuration"
		warn "Check /etc/pacman.conf and CachyOS mirror/repo config"
	fi
}

install_fnm() {
	if command -v fnm >/dev/null 2>&1; then
		log "fnm is already installed"
		return
	fi

	log "Installing fnm"
	if [[ "$DRY_RUN" == "1" ]]; then
		log "DRY-RUN: curl -fsSL https://fnm.vercel.app/install | bash"
		return
	fi

	curl -fsSL https://fnm.vercel.app/install | bash

	if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'fnm env' "$HOME/.bashrc"; then
		cat >>"$HOME/.bashrc" <<'EOF'
eval "$(fnm env --use-on-cd)"
EOF
	fi

	if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'fnm env' "$HOME/.zshrc"; then
		cat >>"$HOME/.zshrc" <<'EOF'
eval "$(fnm env --use-on-cd)"
EOF
	fi
}

phase_1_system_prep() {
	log "Phase 1/7 - System optimization and repositories"
	refresh_mirrors
	run_cmd sudo pacman -Syu --noconfirm
	pacman_install base-devel git curl pacman-contrib reflector
	check_microarch_repo
}

phase_2_niri_stack() {
	log "Phase 2/7 - Graphical core (Niri stack)"
	pacman_install \
		niri noctalia foot alacritty wayland-protocols \
		xdg-desktop-portal-wlr fuzzel wofi \
		mesa vulkan-intel intel-media-driver \
		swaybg mako pipewire pipewire-alsa pipewire-pulse wireplumber

	# Noctalia is commonly available via AUR on some setups.
	aur_install noctalia-git || true
}

phase_3_backend_toolchain() {
	log "Phase 3/7 - Backend toolchains (C++, C#, Python)"
	pacman_install \
		gcc clang cmake gdb ninja \
		dotnet-sdk aspnet-runtime \
		python python-pip

	# Prefer official Arch package name "uv", fallback to "python-uv" if needed.
	if pacman -Si uv >/dev/null 2>&1; then
		pacman_install uv
	elif pacman -Si python-uv >/dev/null 2>&1; then
		pacman_install python-uv
	else
		warn "uv package not found in enabled repositories"
	fi
}

phase_4_frontend_cloud() {
	log "Phase 4/7 - Frontend and cloud stack"
	pacman_install docker docker-compose postgresql-libs redis
	install_fnm

	run_cmd sudo systemctl enable --now docker
	if id -nG "$USER" | grep -qw docker; then
		log "User is already in docker group"
	else
		run_cmd sudo usermod -aG docker "$USER"
		warn "Added $USER to docker group. Logout/login required for group changes"
	fi
}

phase_5_editor_gui() {
	log "Phase 5/7 - GUI and editor"
	pacman_install neovim cachy-browser
	aur_install visual-studio-code-bin || true
}

phase_6_t480_tweaks() {
	log "Phase 6/7 - T480 hardware tweaks"
	pacman_install tlp fwupd

	run_cmd sudo systemctl enable --now tlp

	if systemctl list-unit-files | grep -q '^power-profiles-daemon.service'; then
		run_cmd sudo systemctl disable --now power-profiles-daemon || true
	fi

	if [[ "$INSTALL_THROTTLED" == "1" ]]; then
		aur_install throttled || true
	fi
}

phase_7_dotfiles() {
	log "Phase 7/7 - Dotfiles automation"

	local source_file
	local target_dir
	local target_file

	source_file="$DOTFILES_DIR/$DOTFILES_NIRI_FILE"
	target_dir="$HOME/.config/niri"
	target_file="$target_dir/config.kdl"

	if [[ ! -f "$source_file" ]]; then
		warn "Dotfile not found: $source_file"
		warn "Set DOTFILES_DIR and DOTFILES_NIRI_FILE to your repository layout"
		return
	fi

	run_cmd mkdir -p "$target_dir"
	run_cmd ln -sfn "$source_file" "$target_file"
	log "Created symlink: $target_file -> $source_file"
}

run_all() {
	phase_1_system_prep
	phase_2_niri_stack
	phase_3_backend_toolchain
	phase_4_frontend_cloud
	phase_5_editor_gui
	phase_6_t480_tweaks
	phase_7_dotfiles
}

run_phase() {
	case "$1" in
		1) phase_1_system_prep ;;
		2) phase_2_niri_stack ;;
		3) phase_3_backend_toolchain ;;
		4) phase_4_frontend_cloud ;;
		5) phase_5_editor_gui ;;
		6) phase_6_t480_tweaks ;;
		7) phase_7_dotfiles ;;
		*) die "Invalid phase: $1 (expected 1..7)" ;;
	esac
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--all)
				PHASE="all"
				shift
				;;
			--phase)
				[[ $# -ge 2 ]] || die "--phase requires an argument"
				PHASE="$2"
				shift 2
				;;
			--dry-run)
				DRY_RUN=1
				shift
				;;
			--help|-h)
				usage
				exit 0
				;;
			*)
				die "Unknown argument: $1"
				;;
		esac
	done
}

main() {
	parse_args "$@"
	require_sudo

	log "Starting reproducible full stack setup for T480 on CachyOS"
	if [[ "$PHASE" == "all" ]]; then
		run_all
	else
		run_phase "$PHASE"
	fi

	log "Completed. Reboot or re-login is recommended"
}

main "$@"
