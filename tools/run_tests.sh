#!/usr/bin/env bash
# Runs the headless test suites in parallel.
#   tools/run_tests.sh                  every suite (test_touch needs a flag and is skipped)
#   tools/run_tests.sh -j 3             number of parallel Godot processes (default: cores - 1, at least 1)
#   tools/run_tests.sh --changed [REF]  only suites that mention a script changed since REF (default origin/main), plus any changed suite
#   tools/run_tests.sh test_belts test_phase5   only these suites
# Every job gets its own user:// directory (XDG_DATA_HOME), so suites that save and load cannot trample each other.
# Env: GODOT=/path/to/godot (default: godot on PATH).  Exit status is non-zero if any suite failed, errored or printed no RESULT.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
JOBS=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))
CHANGED=""
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -j) JOBS="$2"; shift 2;;
    --changed) CHANGED="origin/main"; if [ $# -gt 1 ] && [[ "$2" != -* ]] && [[ "$2" != test_* ]]; then CHANGED="$2"; shift; fi; shift;;
    *) NAMES+=("${1%.gd}"); shift;;
  esac
done

if [ ${#NAMES[@]} -eq 0 ]; then
  if [ -n "$CHANGED" ]; then
    mapfile -t files < <(git diff --name-only "$CHANGED"...HEAD; git diff --name-only; git ls-files --others --exclude-standard)
    declare -A pick=()
    for f in "${files[@]}"; do
      case "$f" in
        tests/test_*.gd) pick["$(basename "$f" .gd)"]=1;;
        scripts/*.gd|scripts/*/*.gd)
          base="$(basename "$f" .gd)"
          # a suite mentions the script by file name, or by its class name (class_name line)
          cls="$(grep -m1 '^class_name ' "$f" | awk '{print $2}')"
          pat="$base"; [ -n "$cls" ] && pat="$base|$cls"
          while IFS= read -r t; do pick["$(basename "$t" .gd)"]=1; done < <(grep -lE "$pat" tests/test_*.gd 2>/dev/null);;
        data/*|project.godot) while IFS= read -r t; do pick["$(basename "$t" .gd)"]=1; done < <(ls tests/test_*.gd);;
      esac
    done
    # main.gd / business / state are touched by nearly everything: when they change, the whole suite is the honest answer
    for f in "${files[@]}"; do
      case "$f" in scripts/main.gd|scripts/state.gd|scripts/business.gd|scripts/progression.gd) while IFS= read -r t; do pick["$(basename "$t" .gd)"]=1; done < <(ls tests/test_*.gd);; esac
    done
    NAMES=("${!pick[@]}")
  else
    mapfile -t NAMES < <(ls tests/test_*.gd | xargs -n1 basename | sed 's/\.gd$//')
  fi
fi
NAMES=($(printf '%s\n' "${NAMES[@]}" | grep -v '^test_touch$' | sort -u))
[ ${#NAMES[@]} -eq 0 ] && { echo "no suites selected"; exit 0; }

OUT="$(mktemp -d)"
export GODOT OUT
run_one() {
  t="$1"
  dir="$OUT/$t"; mkdir -p "$dir/data"
  start=$(date +%s)
  XDG_DATA_HOME="$dir/data" timeout 900 "$GODOT" --headless --fixed-fps 60 -s "tests/$t.gd" > "$dir/log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  res=$(grep -a "^RESULT" "$dir/log" | tail -1)
  errs=$(grep -ac "SCRIPT ERROR" "$dir/log")
  fails=$(grep -ac "^FAIL" "$dir/log")
  if [ -z "$res" ] || [ "$errs" -gt 0 ] || [ "$fails" -gt 0 ]; then status="FAIL"; else status="ok  "; fi
  printf '%s %-34s %4ss  %s  script_errors=%s\n' "$status" "$t" "$secs" "${res:-NO RESULT (exit $code)}" "$errs"
  [ "$status" = "FAIL" ] && grep -a "^FAIL\|SCRIPT ERROR" "$dir/log" | head -5 | sed 's/^/       /'
}
export -f run_one
echo "running ${#NAMES[@]} suites, $JOBS at a time (logs in $OUT)"
start_all=$(date +%s)
printf '%s\n' "${NAMES[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one {}' | tee "$OUT/summary"
bad=$(grep -c '^FAIL' "$OUT/summary")
echo "done in $(( $(date +%s) - start_all ))s: $(( ${#NAMES[@]} - bad )) ok, $bad failed"
[ "$bad" -eq 0 ]
