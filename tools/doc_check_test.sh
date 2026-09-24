#!/usr/bin/env bash
# Fixture test for tools/doc_check.lua. A doc checker that silently passes
# everything makes .doc-check-baseline a lie, so its rules are locked down here:
# one fixture where every public function conforms, one where each violates a
# single rule, plus the baseline's suppress/stale behavior.
#
# Usage: bash tools/doc_check_test.sh
set -euo pipefail

cd "$(dirname "$0")/.."

CHECKER=tools/doc_check.lua
FIXTURES=tools/doc_check_fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

pass() {
  printf 'ok: %s\n' "$1"
}

# Runs the checker, capturing output and exit status without tripping set -e.
run_checker() {
  set +e
  lua "$CHECKER" "$@" >"$TMP/out" 2>&1
  status=$?
  set -e
}

# --- the conforming fixture is accepted ---------------------------------------

run_checker "$FIXTURES/good.lua"
if [ "$status" -eq 0 ] && [ ! -s "$TMP/out" ]; then
  pass "good.lua passes with no output"
else
  fail "good.lua should pass silently, got status $status:"
  cat "$TMP/out" >&2
fi

# --- each violation is reported exactly once ----------------------------------

run_checker "$FIXTURES/bad.lua"
if [ "$status" -eq 1 ]; then
  pass "bad.lua exits 1"
else
  fail "bad.lua should exit 1, got $status"
fi

expect_line() {
  if grep -qF "$1" "$TMP/out"; then
    pass "reported: $1"
  else
    fail "not reported: $1"
    cat "$TMP/out" >&2
  fi
}

expect_line "Bad.undocumented: missing doc comment"
expect_line "Bad.plain_comment: doc comment must start with \`---\`, not \`--\`"
expect_line "Bad.no_summary: doc comment must open with a one-line summary"
expect_line "Bad.wrong_params: @param list is (value, missing), declared (value, size)"
expect_line "Bad.swapped_params: @param list is (size, value), declared (value, size)"
expect_line "Bad.silent_return: returns a value but has no @return"

count=$(grep -c ': Bad\.' "$TMP/out" || true)
if [ "$count" -eq 6 ]; then
  pass "bad.lua reports 6 problems, one per function"
else
  fail "bad.lua should report 6 problems, got $count"
  cat "$TMP/out" >&2
fi

# --- a baseline suppresses listed functions -----------------------------------

sed -n 's/^\(tools\/doc_check_fixtures\/bad\.lua\):[0-9]*: \(Bad\.[a-z_]*\):.*/\1:\2/p' "$TMP/out" \
  | sort -u >"$TMP/baseline"

run_checker --baseline "$TMP/baseline" "$FIXTURES/bad.lua"
if [ "$status" -eq 0 ] && [ ! -s "$TMP/out" ]; then
  pass "a full baseline suppresses every violation"
else
  fail "a full baseline should suppress every violation, got status $status:"
  cat "$TMP/out" >&2
fi

# --- a stale entry for a now-conforming function is reported -------------------

printf '%s\n' "$FIXTURES/good.lua:Good.round_up" >"$TMP/stale"
run_checker --baseline "$TMP/stale" "$FIXTURES/good.lua"
if [ "$status" -eq 1 ] && grep -q "Good.round_up: documented now" "$TMP/out"; then
  pass "a conforming function listed in the baseline is reported"
else
  fail "a conforming function listed in the baseline should be reported, got status $status:"
  cat "$TMP/out" >&2
fi

# --- a stale entry for a function that no longer exists is reported ------------

printf '%s\n' "$FIXTURES/good.lua:Good.deleted" >"$TMP/gone"
run_checker --baseline "$TMP/gone" "$FIXTURES/good.lua"
if [ "$status" -eq 1 ] && grep -q "Good.deleted: no such function" "$TMP/out"; then
  pass "a baseline entry with no matching function is reported"
else
  fail "a baseline entry with no matching function should be reported, got status $status:"
  cat "$TMP/out" >&2
fi

# --- --write-baseline lists exactly the violating functions --------------------

run_checker --write-baseline "$FIXTURES/bad.lua" "$FIXTURES/good.lua"
entries=$(grep -vc '^#' "$TMP/out" || true)
if [ "$status" -eq 0 ] && [ "$entries" -eq 6 ] && ! grep -q 'good\.lua' "$TMP/out"; then
  pass "--write-baseline lists the 6 violating functions and nothing from good.lua"
else
  fail "--write-baseline output unexpected, got status $status:"
  cat "$TMP/out" >&2
fi

if [ "$failures" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$failures" >&2
  exit 1
fi

printf '\nall checks passed\n'
