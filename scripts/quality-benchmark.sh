#!/bin/bash
# Pimeleon Quality Benchmark Script
# Performs static analysis and fails if quality thresholds are exceeded

set -euo pipefail

# Colors for report
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quality Thresholds
MAX_SHELLCHECK_WARNINGS=5
MAX_SEMGREP_ISSUES=0

# Core scripts to scan
mapfile -t SCRIPTS < <(find scripts packages -name "*.sh" -not -path "*/cache/*")

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       PIMELEON CODE QUALITY BENCHMARK          ${NC}"
echo -e "${BLUE}==================================================${NC}"

# 1. ShellCheck
echo -e "\n${BLUE}[1/2] Running ShellCheck...${NC}"
SC_OUTPUT=$(shellcheck -f json "${SCRIPTS[@]}" 2>/dev/null || true)
SC_ERRORS=$(echo "$SC_OUTPUT" | jq '[.[] | select(.level == "error")] | length' 2>/dev/null || echo 0)
SC_WARNINGS=$(echo "$SC_OUTPUT" | jq '[.[] | select(.level == "warning")] | length' 2>/dev/null || echo 0)
SC_DETAILS=""

if [ "$SC_ERRORS" -gt 0 ]; then
    SC_DETAILS=$(shellcheck "${SCRIPTS[@]}" 2>&1 || true)
    echo -e "${RED}✘ Failed: $SC_ERRORS ShellCheck errors found.${NC}"
    echo "$SC_DETAILS"
elif [ "$SC_WARNINGS" -gt "$MAX_SHELLCHECK_WARNINGS" ]; then
    SC_DETAILS=$(shellcheck "${SCRIPTS[@]}" 2>&1 || true)
    echo -e "${RED}✘ Failed: $SC_WARNINGS ShellCheck warnings (Threshold: $MAX_SHELLCHECK_WARNINGS).${NC}"
    echo "$SC_DETAILS"
else
    echo -e "${GREEN}✔ Passed: $SC_ERRORS errors, $SC_WARNINGS warnings.${NC}"
fi

# 2. Semgrep
echo -e "\n${BLUE}[2/2] Running Semgrep...${NC}"
SEMGREP_OUTPUT=$(semgrep --config r/bash --exclude "patch-sources.sh" --json "${SCRIPTS[@]}" 2>/dev/null || true)
SEMGREP_CONFIG_ERRORS=$(echo "$SEMGREP_OUTPUT" | jq '[.errors[] | select(.message | test("Failed to download|invalid configuration"))] | length' 2>/dev/null || echo 0)
SEMGREP_PARSE_ERRORS=$(echo "$SEMGREP_OUTPUT" | jq '[.errors[] | select(.message | test("Syntax error|Parse error"))] | length' 2>/dev/null || echo 0)
SEMGREP_ISSUES=$(echo "$SEMGREP_OUTPUT" | jq '.results | length' 2>/dev/null || echo 0)
SEMGREP_DETAILS=""

if [ "$SEMGREP_CONFIG_ERRORS" -gt 0 ]; then
    echo -e "${RED}✘ Semgrep configuration error — scan did not run:${NC}"
    echo "$SEMGREP_OUTPUT" | jq -r '.errors[] | select(.message | test("Failed to download|invalid configuration")) | .message' 2>/dev/null || true
elif [ "$SEMGREP_PARSE_ERRORS" -gt 0 ]; then
    echo -e "${BLUE}⚠ $SEMGREP_PARSE_ERRORS file(s) skipped (unsupported syntax). Results from parseable files:${NC}"
    echo "$SEMGREP_OUTPUT" | jq -r '.errors[] | select(.message | test("Syntax error|Parse error")) | .message | split("\n")[0]' 2>/dev/null || true
fi
if [ "$SEMGREP_CONFIG_ERRORS" -eq 0 ] && [ "$SEMGREP_ISSUES" -gt "$MAX_SEMGREP_ISSUES" ]; then
    SEMGREP_DETAILS=$(semgrep --config r/bash --exclude "patch-sources.sh" "${SCRIPTS[@]}" 2>&1 || true)
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
if [ "$SEMGREP_CONFIG_ERRORS" -gt 0 ]; then
    printf "%-25s | %-10s | %-10s\n" "Semgrep Issues" "CONFIG ERR" "$MAX_SEMGREP_ISSUES"
else
    printf "%-25s | %-10s | %-10s\n" "Semgrep Issues" "$SEMGREP_ISSUES" "$MAX_SEMGREP_ISSUES"
fi
echo "--------------------------------------------------"

# Final Verdict
if [ "$SC_ERRORS" -gt 0 ] || \
   [ "$SC_WARNINGS" -gt "$MAX_SHELLCHECK_WARNINGS" ] || \
   [ "$SEMGREP_CONFIG_ERRORS" -gt 0 ] || \
   [ "$SEMGREP_ISSUES" -gt "$MAX_SEMGREP_ISSUES" ]; then
    echo -e "${RED}RESULT: QUALITY BENCHMARK FAILED${NC}"
    echo -e "\n${RED}=== VALIDATION ERRORS ===${NC}"
    if [ -n "$SC_DETAILS" ]; then
        echo -e "\n${RED}--- ShellCheck ---${NC}"
        echo "$SC_DETAILS"
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
