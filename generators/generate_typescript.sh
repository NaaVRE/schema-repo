#!/usr/bin/env bash
# generate_typescript.sh
# Generates TypeScript types from JSON schemas using json-schema-to-typescript.
#
# Requirements:
#   npm install -g json-schema-to-typescript
#
# Usage:
#   ./generators/generate_typescript.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/packages/typescript-types/src"
SCHEMAS_DIR="${REPO_ROOT}/schemas"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] Would generate TypeScript types into: ${OUTPUT_DIR}"
fi

if [[ "${DRY_RUN}" == "false" ]] && ! command -v json2ts &>/dev/null; then
  echo "Error: json2ts not found. Install it with: npm install -g json-schema-to-typescript" >&2
  exit 1
fi

echo "Generating TypeScript types from schemas in: ${SCHEMAS_DIR}"
echo "Output directory: ${OUTPUT_DIR}"

if [[ "${DRY_RUN}" == "false" ]]; then
  mkdir -p "${OUTPUT_DIR}"

  # Generate types for each schema file
  find "${SCHEMAS_DIR}" -name "*.json" | sort | while read -r schema_file; do
    relative_path="${schema_file#"${SCHEMAS_DIR}/"}"
    ts_file="${OUTPUT_DIR}/${relative_path%.json}.ts"
    ts_dir="$(dirname "${ts_file}")"

    mkdir -p "${ts_dir}"
    echo "  Generating ${ts_file} ..."
    json2ts \
      --input "${schema_file}" \
      --output "${ts_file}" \
      --bannerComment "" \
      --unreachableDefinitions
  done

  # Write barrel index.ts
  index_file="${OUTPUT_DIR}/index.ts"
  {
    echo "// Auto-generated — do not edit manually."
    find "${OUTPUT_DIR}" -name "*.ts" ! -name "index.ts" | sort | while read -r ts_file; do
      rel="${ts_file#"${OUTPUT_DIR}/"}"
      module_path="./${rel%.ts}"
      echo "export * from '${module_path}';"
    done
  } > "${index_file}"

  echo "Done. Types written to ${OUTPUT_DIR}"
else
  echo "[dry-run] No files written."
fi
