#!/bin/bash
# Pimeleon Quality Benchmark Script
# Performs static analysis and fails if quality thresholds are exceeded

set -uo pipefail

# Colors for report
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quality Thresholds
MAX_SHELLCHECK_WARNINGS=5
MAX_BASHATE_ERRORS=0
MAX_SEMGREP_ISSUES=0

# Core scripts to scan
SCRIPTS=$(find scripts packages -name "*.sh" -not -path "*/cache/*")

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       PIMELEON CODE QUALITY BENCHMARK          ${NC}"
echo -e "${BLUE}==================================================${NC}"

# 1. ShellCheck
echo -e "\n${BLUE}[1/3] Running ShellCheck...${NC}"
SC_OUTPUT=$(shellcheck -f json $SCRIPTS 2>/dev/null || true)
SC_ERRORS=$(echo "$SC_OUTPUT" | jq '[.[] | select(.level == "error")] | length' 2>/dev/null || echo 0)
SC_WARNINGS=$(echo "$SC_OUTPUT" | jq '[.[] | select(.level == "warning")] | length' 2>/dev/null || echo 0)
SC_DETAILS=""

if [ "$SC_ERRORS" -gt 0 ]; then
    SC_DETAILS=$(shellcheck $SCRIPTS 2>&1 || true)
    echo -e "${RED}✘ Failed: $SC_ERRORS ShellCheck errors found.${NC}"
    echo "$SC_DETAILS"
elif [ "$SC_WARNINGS" -gt "$MAX_SHELLCHECK_WARNINGS" ]; then
    SC_DETAILS=$(shellcheck $SCRIPTS 2>&1 || true)
    echo -e "${RED}✘ Failed: $SC_WARNINGS ShellCheck warnings (Threshold: $MAX_SHELLCHECK_WARNINGS).${NC}"
    echo "$SC_DETAILS"
else
    echo -e "${GREEN}✔ Passed: $SC_ERRORS errors, $SC_WARNINGS warnings.${NC}"
fi

# 2. Bashate
echo -e "\n${BLUE}[2/3] Running Bashate...${NC}"
BASHATE_OUTPUT=$(bashate --ignore E006 $SCRIPTS 2>&1 || true)
BASHATE_DETAILS=$(echo "$BASHATE_OUTPUT" | grep "E[0-9]" || true)
BASHATE_ERRORS=$(echo "$BASHATE_DETAILS" | grep -c "E[0-9]" || true)

if [ "$BASHATE_ERRORS" -gt "$MAX_BASHATE_ERRORS" ]; then
    echo -e "${RED}✘ Failed: $BASHATE_ERRORS style errors found.${NC}"
    echo "$BASHATE_DETAILS"
else
    echo -e "${GREEN}✔ Passed: No style errors.${NC}"
    BASHATE_DETAILS=""
fi

# 3. Semgrep
echo -e "\n${BLUE}[3/3] Running Semgrep...${NC}"
SEMGREP_OUTPUT=$(semgrep --config p/shell --json $SCRIPTS 2>/dev/null || true)
SEMGREP_ISSUES=$(echo "$SEMGREP_OUTPUT" | jq '.results | length' 2>/dev/null || echo 0)
SEMGREP_DETAILS=""

if [ "$SEMGREP_ISSUES" -gt "$MAX_SEMGREP_ISSUES" ]; then
    SEMGREP_DETAILS=$(semgrep --config p/shell $SCRIPTS 2>&1 || true)
    echo -e "${RED}✘ Failed: $SEMGREP_ISSUES security/pattern issues found.${NC}"
    echo "$SEMGREP_DETAILS"
else
    echo -e "${GREEN}✔ Passed: No critical patterns found.${NC}"
fi

# Summary Report
echo -e "\n${BLUE}==================================================${NC}"
echo -e "                SUMMARY REPORT                    "
echo -e "${BLUE}==================================================${NC}"
printf "%-25s | %-10s | %-10s\n" "Metric" "Found" "Threshold"
echo "--------------------------------------------------"
printf "%-25s | %-10s | %-10s\n" "ShellCheck Errors" "$SC_ERRORS" "0"
printf "%-25s | %-10s | %-10s\n" "ShellCheck Warnings" "$SC_WARNINGS" "$MAX_SHELLCHECK_WARNINGS"
printf "%-25s | %-10s | %-10s\n" "Bashate Errors" "$BASHATE_ERRORS" "$MAX_BASHATE_ERRORS"
printf "%-25s | %-10s | %-10s\n" "Semgrep Issues" "$SEMGREP_ISSUES" "$MAX_SEMGREP_ISSUES"
echo "--------------------------------------------------"

# Final Verdict
if [ "$SC_ERRORS" -gt 0 ] || \
   [ "$SC_WARNINGS" -gt "$MAX_SHELLCHECK_WARNINGS" ] || \
   [ "$BASHATE_ERRORS" -gt "$MAX_BASHATE_ERRORS" ] || \
   [ "$SEMGREP_ISSUES" -gt "$MAX_SEMGREP_ISSUES" ]; then
    echo -e "${RED}RESULT: QUALITY BENCHMARK FAILED${NC}"
    echo -e "\n${RED}=== VALIDATION ERRORS ===${NC}"
    if [ -n "$SC_DETAILS" ]; then
        echo -e "\n${RED}--- ShellCheck ---${NC}"
        echo "$SC_DETAILS"
    fi
    if [ -n "$BASHATE_DETAILS" ]; then
        echo -e "\n${RED}--- Bashate ---${NC}"
        echo "$BASHATE_DETAILS"
    fi
    if [ -n "$SEMGREP_DETAILS" ]; then
        echo -e "\n${RED}--- Semgrep ---${NC}"
        echo "$SEMGREP_DETAILS"
    fi
    exit 1
else
    echo -e "${GREEN}RESULT: QUALITY BENCHMARK PASSED${NC}"
    exit 0
fi
