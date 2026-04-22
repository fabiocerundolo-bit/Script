SHELL := /usr/bin/env bash

SCRIPT := ./setupT480.sh
ANSIBLE_DIR := ansible
PLAYBOOK := $(ANSIBLE_DIR)/devstation.yml
ANSIBLE := ansible-playbook
QUIET_PROGRESS ?= 0
LOG_DIR := .logs

ifneq ($(NO_COLOR),)
C_RESET :=
C_BOLD :=
C_BLUE :=
C_CYAN :=
C_GREEN :=
C_YELLOW :=
C_RED :=
else
C_RESET := \033[0m
C_BOLD := \033[1m
C_BLUE := \033[34m
C_CYAN := \033[36m
C_GREEN := \033[32m
C_YELLOW := \033[33m
C_RED := \033[31m
endif

.PHONY: help dashboard menu doctor readiness-report readiness-report-soft bootstrap quickstart go-live go-live-all bash-all bash-dry bash-phase bash-phase-dry deps-ansible ansible-check ansible-full ansible-phase ansible-aur ansible-phase6-throttled

help:
	@printf "%b\n" "$(C_BOLD)T480 Dev Station - Targets$(C_RESET)"
	@printf "\n"
	@printf "%b\n" "$(C_CYAN)Preflight$(C_RESET)"
	@echo "  make dashboard                     # Visual summary (doctor + readiness)"
	@echo "  make menu                          # Interactive menu for common tasks"
	@echo "  make doctor                        # Check required commands/files"
	@echo "  make readiness-report              # Go/No-Go report for real run"
	@echo "  make bootstrap                     # Doctor + shell dry-run + ansible check"
	@echo "  make quickstart                    # Dry-run phases 1+3+4 + readiness report"
	@echo "  make go-live                       # Readiness gate + confirm + run phases 1+3+4"
	@echo "  make go-live-all                   # Readiness gate + confirm + run full install"
	@echo ""
	@printf "%b\n" "$(C_CYAN)Output control$(C_RESET)"
	@echo "  QUIET_PROGRESS=1 make quickstart   # Keep progress bar, save detailed logs"
	@echo "  QUIET_PROGRESS=1 make go-live      # Quiet run with logs in .logs/"
	@printf "\n"
	@printf "%b\n" "$(C_CYAN)Bash installer$(C_RESET)"
	@echo "  make bash-all                      # Run all 7 phases"
	@echo "  make bash-dry                      # Dry-run all phases"
	@echo "  make bash-phase PHASE=3            # Run one phase"
	@echo "  make bash-phase-dry PHASE=3        # Dry-run one phase"
	@printf "\n"
	@printf "%b\n" "$(C_CYAN)Ansible installer$(C_RESET)"
	@echo "  make deps-ansible                  # Install ansible + community.general"
	@echo "  make ansible-check                 # --check --diff"
	@echo "  make ansible-full                  # Run full playbook"
	@echo "  make ansible-phase PHASE=phase3    # Run one tagged phase"
	@echo "  make ansible-aur                   # Run only AUR tasks"
	@echo "  make ansible-phase6-throttled      # Run phase6 with throttled"

dashboard:
	@printf "%b\n" "$(C_BOLD)===============================$(C_RESET)"
	@printf "%b\n" "$(C_BOLD)   T480 DevStation Dashboard$(C_RESET)"
	@printf "%b\n" "$(C_BOLD)===============================$(C_RESET)"
	@$(MAKE) --no-print-directory doctor
	@printf "\n"
	@$(MAKE) --no-print-directory readiness-report-soft
	@printf "\n"
	@printf "%b\n" "$(C_YELLOW)Next:$(C_RESET) make quickstart"
	@printf "%b\n" "$(C_YELLOW)Then:$(C_RESET) make go-live"

menu:
	@while true; do \
		printf "\n%b\n" "$(C_BOLD)T480 DevStation Menu$(C_RESET)"; \
		echo "  1) dashboard"; \
		echo "  2) quickstart"; \
		echo "  3) go-live (phases 1,3,4)"; \
		echo "  4) go-live-all (all phases)"; \
		echo "  5) ansible-check"; \
		echo "  6) deps-ansible"; \
		echo "  q) quit"; \
		read -r -p "Select option: " choice; \
		case "$$choice" in \
			1) $(MAKE) --no-print-directory dashboard ;; \
			2) $(MAKE) --no-print-directory quickstart ;; \
			3) $(MAKE) --no-print-directory go-live ;; \
			4) $(MAKE) --no-print-directory go-live-all ;; \
			5) $(MAKE) --no-print-directory ansible-check ;; \
			6) $(MAKE) --no-print-directory deps-ansible ;; \
			q|Q) echo "Bye"; break ;; \
			*) printf "%b\n" "$(C_RED)Invalid selection$(C_RESET)" ;; \
		esac; \
	done

doctor:
	@printf "%b\n" "$(C_BLUE)[doctor]$(C_RESET) Checking local files"
	@test -x $(SCRIPT) || { echo "Missing executable script: $(SCRIPT)"; exit 1; }
	@test -f $(PLAYBOOK) || { echo "Missing playbook: $(PLAYBOOK)"; exit 1; }
	@printf "%b\n" "$(C_BLUE)[doctor]$(C_RESET) Checking command availability"
	@for cmd in bash make sudo; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "Missing command: $$cmd"; exit 1; }; \
	done
	@if command -v pacman >/dev/null 2>&1; then \
		echo "  - pacman: OK"; \
	else \
		echo "  - pacman: MISSING (expected on CachyOS/Arch)"; \
	fi
	@printf "%b\n" "$(C_BLUE)[doctor]$(C_RESET) Optional commands status"
	@for cmd in $(ANSIBLE) ansible-galaxy git curl; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "  - $$cmd: OK"; \
		else \
			echo "  - $$cmd: MISSING"; \
		fi; \
	done

readiness-report:
	@printf "%b\n" "$(C_BLUE)[readiness]$(C_RESET) Evaluating execution readiness"
	@status=0; \
	if command -v pacman >/dev/null 2>&1; then \
		echo "  - Platform package manager: pacman OK"; \
	else \
		echo "  - Platform package manager: pacman MISSING"; \
		echo "    Action: run this setup on CachyOS/Arch"; \
		status=1; \
	fi; \
	if command -v $(ANSIBLE) >/dev/null 2>&1; then \
		echo "  - Ansible: OK"; \
	else \
		echo "  - Ansible: MISSING"; \
		echo "    Action: make deps-ansible"; \
		status=1; \
	fi; \
	if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1 || command -v cachyos-helper >/dev/null 2>&1; then \
		echo "  - AUR helper: OK"; \
	else \
		echo "  - AUR helper: MISSING (optional, needed for AUR targets)"; \
	fi; \
	if [[ $$status -eq 0 ]]; then \
		printf "%b\n" "$(C_GREEN)[readiness] GO: prerequisites satisfied$(C_RESET)"; \
	else \
		printf "%b\n" "$(C_RED)[readiness] NO-GO: resolve items above before real install$(C_RESET)"; \
		exit 3; \
	fi

readiness-report-soft:
	@printf "%b\n" "$(C_BLUE)[readiness]$(C_RESET) Evaluating execution readiness"
	@status=0; \
	if command -v pacman >/dev/null 2>&1; then \
		echo "  - Platform package manager: pacman OK"; \
	else \
		echo "  - Platform package manager: pacman MISSING"; \
		echo "    Action: run this setup on CachyOS/Arch"; \
		status=1; \
	fi; \
	if command -v $(ANSIBLE) >/dev/null 2>&1; then \
		echo "  - Ansible: OK"; \
	else \
		echo "  - Ansible: MISSING"; \
		echo "    Action: make deps-ansible"; \
		status=1; \
	fi; \
	if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1 || command -v cachyos-helper >/dev/null 2>&1; then \
		echo "  - AUR helper: OK"; \
	else \
		echo "  - AUR helper: MISSING (optional, needed for AUR targets)"; \
	fi; \
	if [[ $$status -eq 0 ]]; then \
		printf "%b\n" "$(C_GREEN)[readiness] GO: prerequisites satisfied$(C_RESET)"; \
	else \
		printf "%b\n" "$(C_RED)[readiness] NO-GO: resolve items above before real install$(C_RESET)"; \
	fi

bootstrap: doctor
	@echo "[bootstrap] Running shell dry-run phase 1"
	@$(MAKE) --no-print-directory bash-phase-dry PHASE=1
	@echo "[bootstrap] Running ansible check if available"
	@if command -v $(ANSIBLE) >/dev/null 2>&1; then \
		$(MAKE) --no-print-directory ansible-check; \
	else \
		echo "[bootstrap] ansible-playbook missing: run 'make deps-ansible' then 'make ansible-check'"; \
	fi

quickstart: doctor
	@mkdir -p $(LOG_DIR)
	@log_file="$(LOG_DIR)/quickstart.log"; : > "$$log_file"; \
	if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		printf "%b\n" "$(C_YELLOW)[quickstart] quiet mode enabled$(C_RESET) (log: $$log_file)"; \
	fi
	@printf "%b\n" "$(C_BLUE)[quickstart]$(C_RESET) Dry-run shell phases 1, 3, 4"
	@printf "%b" "$(C_CYAN)\r[--------------------] 0%  preparing quickstart$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=1 >> "$(LOG_DIR)/quickstart.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=1; \
	fi
	@printf "%b" "$(C_CYAN)\r[######--------------] 33% [1/3] phase 1 done$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=3 >> "$(LOG_DIR)/quickstart.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=3; \
	fi
	@printf "%b" "$(C_CYAN)\r[#############-------] 66% [2/3] phase 3 done$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=4 >> "$(LOG_DIR)/quickstart.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase-dry PHASE=4; \
	fi
	@printf "%b\n" "$(C_CYAN)\r[####################] 100% [3/3] phase 4 done$(C_RESET)"
	@printf "%b\n" "$(C_BLUE)[quickstart]$(C_RESET) Building readiness report"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory readiness-report-soft >> "$(LOG_DIR)/quickstart.log" 2>&1; \
		$(MAKE) --no-print-directory readiness-report-soft; \
	else \
		$(MAKE) --no-print-directory readiness-report-soft; \
	fi

go-live: readiness-report
	@mkdir -p $(LOG_DIR)
	@log_file="$(LOG_DIR)/go-live.log"; : > "$$log_file"; \
	if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		printf "%b\n" "$(C_YELLOW)[go-live] quiet mode enabled$(C_RESET) (log: $$log_file)"; \
	fi
	@printf "%b\n" "$(C_YELLOW)[go-live]$(C_RESET) Real execution plan: phases 1, 3, 4"
	@read -r -p "Type YES to continue: " reply; \
	if [[ "$$reply" != "YES" ]]; then \
		echo "[go-live] Aborted by user"; \
		exit 4; \
	fi
	@printf "%b" "$(C_CYAN)\r[--------------------] 0%  waiting confirmation$(C_RESET)"
	@printf "%b" "$(C_CYAN)\r[######--------------] 33% executing phase 1$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase PHASE=1 >> "$(LOG_DIR)/go-live.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase PHASE=1; \
	fi
	@printf "%b" "$(C_CYAN)\r[#############-------] 66% executing phase 3$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase PHASE=3 >> "$(LOG_DIR)/go-live.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase PHASE=3; \
	fi
	@printf "%b" "$(C_CYAN)\r[####################] 100% executing phase 4$(C_RESET)"
	@printf "\n"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-phase PHASE=4 >> "$(LOG_DIR)/go-live.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-phase PHASE=4; \
	fi
	@printf "\n"
	@printf "%b\n" "$(C_GREEN)[go-live] Completed phases 1, 3, 4$(C_RESET)"

go-live-all: readiness-report
	@mkdir -p $(LOG_DIR)
	@log_file="$(LOG_DIR)/go-live-all.log"; : > "$$log_file"; \
	if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		printf "%b\n" "$(C_YELLOW)[go-live-all] quiet mode enabled$(C_RESET) (log: $$log_file)"; \
	fi
	@printf "%b\n" "$(C_YELLOW)[go-live-all]$(C_RESET) Real execution plan: all 7 phases"
	@read -r -p "Type YES to continue: " reply; \
	if [[ "$$reply" != "YES" ]]; then \
		echo "[go-live-all] Aborted by user"; \
		exit 4; \
	fi
	@printf "%b" "$(C_CYAN)\r[--------------------] 0%  launching full setup$(C_RESET)"
	@if [[ "$(QUIET_PROGRESS)" == "1" ]]; then \
		$(MAKE) --no-print-directory bash-all >> "$(LOG_DIR)/go-live-all.log" 2>&1; \
	else \
		$(MAKE) --no-print-directory bash-all; \
	fi
	@printf "%b\n" "$(C_CYAN)\r[####################] 100% full setup completed$(C_RESET)"
	@printf "%b\n" "$(C_GREEN)[go-live-all] Completed all phases$(C_RESET)"

bash-all:
	$(SCRIPT) --all

bash-dry:
	$(SCRIPT) --all --dry-run

bash-phase:
	@if [[ -z "$(PHASE)" ]]; then echo "Set PHASE=1..7"; exit 2; fi
	$(SCRIPT) --phase $(PHASE)

bash-phase-dry:
	@if [[ -z "$(PHASE)" ]]; then echo "Set PHASE=1..7"; exit 2; fi
	$(SCRIPT) --phase $(PHASE) --dry-run

deps-ansible:
	sudo pacman -S --needed ansible
	ansible-galaxy collection install community.general

ansible-check:
	@command -v $(ANSIBLE) >/dev/null 2>&1 || { \
		echo "ansible-playbook not found. Run: make deps-ansible"; \
		exit 127; \
	}
	cd $(ANSIBLE_DIR) && $(ANSIBLE) devstation.yml --check --diff

ansible-full:
	@command -v $(ANSIBLE) >/dev/null 2>&1 || { \
		echo "ansible-playbook not found. Run: make deps-ansible"; \
		exit 127; \
	}
	cd $(ANSIBLE_DIR) && $(ANSIBLE) devstation.yml

ansible-phase:
	@if [[ -z "$(PHASE)" ]]; then echo "Set PHASE=phase1..phase7 (or aur)"; exit 2; fi
	@command -v $(ANSIBLE) >/dev/null 2>&1 || { \
		echo "ansible-playbook not found. Run: make deps-ansible"; \
		exit 127; \
	}
	cd $(ANSIBLE_DIR) && $(ANSIBLE) devstation.yml --tags $(PHASE)

ansible-aur:
	@command -v $(ANSIBLE) >/dev/null 2>&1 || { \
		echo "ansible-playbook not found. Run: make deps-ansible"; \
		exit 127; \
	}
	cd $(ANSIBLE_DIR) && $(ANSIBLE) devstation.yml --tags aur

ansible-phase6-throttled:
	@command -v $(ANSIBLE) >/dev/null 2>&1 || { \
		echo "ansible-playbook not found. Run: make deps-ansible"; \
		exit 127; \
	}
	cd $(ANSIBLE_DIR) && $(ANSIBLE) devstation.yml --tags phase6 -e install_throttled=true
