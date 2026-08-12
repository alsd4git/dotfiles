#!/usr/bin/env bash

INSTALL_COMPLETED=()
INSTALL_SKIPPED=()
INSTALL_OPTIONAL_FAILURES=()
INSTALL_REQUIRED_FAILURES=()
INSTALL_SUMMARY_ENABLED=false
INSTALL_SUMMARY_PRINTED=false
INSTALL_TEMP_PATHS=()

report_completed() { INSTALL_COMPLETED+=("$1"); }
report_skipped() { INSTALL_SKIPPED+=("$1"); }
report_optional_failure() { INSTALL_OPTIONAL_FAILURES+=("$1"); }
report_required_failure() { INSTALL_REQUIRED_FAILURES+=("$1"); }
enable_install_summary() { INSTALL_SUMMARY_ENABLED=true; }

run_step() {
    local policy="$1" label="$2"
    shift 2
    if "$@"; then
        report_completed "$label"
        return 0
    fi
    case "$policy" in
        required)
            report_required_failure "$label"
            echo "❌ Required step failed: $label" >&2
            return 1
            ;;
        optional)
            report_optional_failure "$label"
            echo "⚠️  Optional step failed: $label" >&2
            return 0
            ;;
        advisory)
            report_skipped "$label"
            echo "ℹ️  Advisory step did not complete: $label" >&2
            return 0
            ;;
        *)
            echo "❌ Unknown step policy: $policy" >&2
            return 2
            ;;
    esac
}
register_temp_path() { INSTALL_TEMP_PATHS+=("$1"); }

forget_temp_path() {
    local target="$1" path
    local remaining=()
    for path in ${INSTALL_TEMP_PATHS[@]+"${INSTALL_TEMP_PATHS[@]}"}; do
        [ "$path" = "$target" ] || remaining+=("$path")
    done
    INSTALL_TEMP_PATHS=("${remaining[@]}")
}

cleanup_registered_paths() {
    local path
    for path in ${INSTALL_TEMP_PATHS[@]+"${INSTALL_TEMP_PATHS[@]}"}; do
        if [ -d "$path" ] && [ ! -L "$path" ]; then
            find "$path" -depth -delete 2>/dev/null || true
        else
            rm -f -- "$path"
        fi
    done
    INSTALL_TEMP_PATHS=()
}

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

installer_exit_handler() {
    local status="$1"
    cleanup_registered_paths
    installer_exit_summary "$status"
    return "$status"
}
