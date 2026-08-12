#!/usr/bin/env bash

INSTALL_COMPLETED=()
INSTALL_SKIPPED=()
INSTALL_OPTIONAL_FAILURES=()
INSTALL_REQUIRED_FAILURES=()
INSTALL_SUMMARY_ENABLED=false
INSTALL_SUMMARY_PRINTED=false

report_completed() { INSTALL_COMPLETED+=("$1"); }
report_skipped() { INSTALL_SKIPPED+=("$1"); }
report_optional_failure() { INSTALL_OPTIONAL_FAILURES+=("$1"); }
report_required_failure() { INSTALL_REQUIRED_FAILURES+=("$1"); }
enable_install_summary() { INSTALL_SUMMARY_ENABLED=true; }

print_install_summary() {
    printf '\n%s\n' "──────────────── Installation summary ────────────────"
    printf 'Completed: %d\n' "${#INSTALL_COMPLETED[@]}"
    printf 'Skipped: %d\n' "${#INSTALL_SKIPPED[@]}"
    printf 'Optional failures: %d\n' "${#INSTALL_OPTIONAL_FAILURES[@]}"
    printf 'Required failures: %d\n' "${#INSTALL_REQUIRED_FAILURES[@]}"

    local item
    if ((${#INSTALL_OPTIONAL_FAILURES[@]} > 0)); then
        for item in "${INSTALL_OPTIONAL_FAILURES[@]}"; do
            printf '  warning: %s\n' "$item"
        done
    fi
    if ((${#INSTALL_REQUIRED_FAILURES[@]} > 0)); then
        for item in "${INSTALL_REQUIRED_FAILURES[@]}"; do
            printf '  error: %s\n' "$item"
        done
    fi
    INSTALL_SUMMARY_PRINTED=true
}

installer_exit_summary() {
    local status="$1"

    if ! $INSTALL_SUMMARY_ENABLED || $INSTALL_SUMMARY_PRINTED; then
        return
    fi
    if ((status != 0)) && ((${#INSTALL_REQUIRED_FAILURES[@]} == 0)); then
        report_required_failure "installer exited with status $status"
    fi
    print_install_summary
}
