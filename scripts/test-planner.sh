#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for main in Tests/*/main.swift; do
    suite=${main%/main.swift}
    suite=${suite##*/}
    sources=(SortedEnhance/Core/*.swift)
    case "$suite" in
        Core) ;;
        Calendar) sources+=(SortedEnhance/Calendar/EventAnnotation.swift) ;;
        Capture) sources+=(SortedEnhance/Capture/{QuickEntry,PlannerNotifications}.swift) ;;
        Integrations) sources=(SortedEnhance/Integrations/PlannerLink.swift) ;;
        Organization) sources+=(SortedEnhance/Organization/TaskMerge.swift) ;;
        Recurrence) sources+=(SortedEnhance/Recurrence/PlannerRepetition.swift) ;;
        Recovery) sources+=(SortedEnhance/Recovery/{SyncDocument,RecoveryFiles}.swift) ;;
        Schedule) sources+=(SortedEnhance/Schedule/DayPlanner.swift) ;;
        Widgets) sources+=(SortedEnhance/Recurrence/PlannerRepetition.swift SortedEnhance/Widgets/{WidgetSnapshot,WidgetExport}.swift) ;;
        *) echo "Unknown test suite: $suite" >&2; exit 1 ;;
    esac

    echo "Testing $suite"
    xcrun swiftc -swift-version 6 -module-cache-path "$work/modules" \
        "${sources[@]}" "$main" -o "$work/$suite"
    "$work/$suite"
done
