#!/usr/bin/env bash
# rename-pdfs.sh - rename PDFs to match the title inside the PDF.
# Usage:
#   ./rename-pdfs.sh [-n] [file.pdf | folder] ...
#   -n   dry run: show what would be renamed, change nothing
set -u

DRY_RUN=0
MAXLEN=120

while getopts "n" opt; do
  case $opt in
  n) DRY_RUN=1 ;;
  *)
    echo "Usage: $0 [-n] [file.pdf | folder] ..."
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

if ! command -v pdfinfo >/dev/null 2>&1 || ! command -v pdftotext >/dev/null 2>&1; then
  echo "Missing pdfinfo/pdftotext. Install poppler-utils first."
  exit 1
fi

[ $# -eq 0 ] && set -- .

get_title() {
  local f="$1" t lc
  t=$(pdfinfo "$f" 2>/dev/null | sed -n 's/^Title:[[:space:]]*//p' | head -n1)
  lc=$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')

  if [ -z "$t" ] ||
    [[ "$lc" == microsoft\ word* ]] ||
    [[ "$lc" == untitled* ]] ||
    [[ "$lc" == powerpoint* ]] ||
    [[ "$lc" =~ \.(docx?|pptx?|indd|tex|qxd|rtf|txt)$ ]]; then
    t=$(pdftotext -l 1 "$f" - 2>/dev/null |
      sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
      grep -m1 -E '.{8,}')
  fi
  printf '%s' "$t"
}

sanitize() {
  local s
  s=$(printf '%s' "$1" |
    tr '\n\r\t' '   ' |
    sed 's#[/\\:*?"<>|]#-#g; s/[[:space:]][[:space:]]*/ /g; s/^[ .]*//; s/[ .]*$//')
  printf '%s' "${s:0:$MAXLEN}"
}

process() {
  local f="$1" dir title target n
  dir=$(dirname "$f")
  title=$(sanitize "$(get_title "$f")")

  if [ -z "$title" ]; then
    echo "SKIP (no title found): $f"
    return
  fi

  target="$dir/$title.pdf"
  if [ "$f" = "$target" ]; then
    echo "OK (already named):    $f"
    return
  fi

  n=1
  while [ -e "$target" ]; do
    n=$((n + 1))
    target="$dir/$title ($n).pdf"
  done

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "WOULD RENAME: $f"
    echo "          TO: $target"
  else
    mv -n -- "$f" "$target" && echo "RENAMED: $f -> $target"
  fi
}

for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r -d '' f; do
      process "$f"
    done < <(find "$arg" -maxdepth 1 -type f -iname '*.pdf' -print0)
  elif [ -f "$arg" ]; then
    process "$arg"
  else
    echo "Not found: $arg"
  fi
done
