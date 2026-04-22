# T480 Dev Station Setup (CachyOS)

This folder contains two automation paths:

- `setupT480.sh`: Bash installer with 7 modular phases
- `ansible/devstation.yml`: Ansible playbook with matching phase tags

## 1) Bash workflow

### Dry-run first (recommended)

```bash
./setupT480.sh --phase 1 --dry-run
```

### Run one phase

```bash
./setupT480.sh --phase 3
```

### Run all phases

```bash
./setupT480.sh --all
```

### Optional variables

```bash
INSTALL_THROTTLED=1 DOTFILES_DIR=$HOME/dotfiles ./setupT480.sh --phase 6
```

## 2) Ansible workflow (local)

Install dependencies:

```bash
sudo pacman -S --needed ansible
ansible-galaxy collection install community.general
```

Optional AUR helper (if not already present on your system):

```bash
sudo pacman -S --needed yay
```

Dry-run (check mode):

```bash
cd ansible
ansible-playbook devstation.yml --check --diff
```

Run one phase via tags:

```bash
cd ansible
ansible-playbook devstation.yml --tags phase3
```

Run AUR-only tasks:

```bash
cd ansible
ansible-playbook devstation.yml --tags aur
```

Run full setup:

```bash
cd ansible
ansible-playbook devstation.yml
```

Enable optional throttled via extra vars:

```bash
cd ansible
ansible-playbook devstation.yml --tags phase6 -e install_throttled=true
```

## Notes

- The Ansible playbook now installs AUR packages when one helper is available: cachyos-helper, yay, or paru.
- If no AUR helper is found, AUR tasks are skipped with a warning.
- After Docker group changes, logout/login is required.

## 3) Makefile workflow (recommended)

List available targets:

```bash
make help
```

Show a visual status dashboard (doctor + readiness):

```bash
make dashboard
```

Open the interactive terminal menu:

```bash
make menu
```

Disable colors if needed:

```bash
NO_COLOR=1 make dashboard
```

Run preflight checks:

```bash
make doctor
```

Generate a go/no-go readiness report:

```bash
make readiness-report
```

Run bootstrap flow (doctor + shell dry-run + ansible check if installed):

```bash
make bootstrap
```

Run fast dry-run sequence (phases 1, 3, 4) and then readiness report:

```bash
make quickstart
```

Quickstart and go-live targets show a dynamic single-line terminal progress bar for better execution feedback.

Quiet mode with detailed logs:

```bash
QUIET_PROGRESS=1 make quickstart
```

Logs are written in .logs/ (for example .logs/quickstart.log).

For real runs, you can also use:

```bash
QUIET_PROGRESS=1 make go-live
```

Run guarded real install for phases 1, 3, 4:

```bash
make go-live
```

Run guarded real install for all phases:

```bash
make go-live-all
```

Both targets require readiness-report to pass and explicit YES confirmation.

Dry-run a single shell phase:

```bash
make bash-phase-dry PHASE=1
```

Run a shell phase:

```bash
make bash-phase PHASE=3
```

Ansible check mode:

```bash
make ansible-check
```

Run one Ansible phase:

```bash
make ansible-phase PHASE=phase4
```

Run only AUR tasks:

```bash
make ansible-aur
```
