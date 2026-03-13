#!/usr/bin/env bash
# generate_python.sh
# Generates Python Pydantic models from JSON schemas using datamodel-code-generator.
#
# Requirements:
#   pip install datamodel-code-generator
#
# Usage:
#   ./generators/generate_python.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/packages/python-models/src/models"
SCHEMAS_DIR="${REPO_ROOT}/schemas"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] Would generate Python models into: ${OUTPUT_DIR}"
fi

if [[ "${DRY_RUN}" == "false" ]] && ! command -v datamodel-codegen &>/dev/null; then
  echo "Error: datamodel-codegen not found. Install it with: pip install datamodel-code-generator" >&2
  exit 1
fi

echo "Generating Python models from schemas in: ${SCHEMAS_DIR}"
echo "Output directory: ${OUTPUT_DIR}"

if [[ "${DRY_RUN}" == "false" ]]; then
  mkdir -p "${OUTPUT_DIR}"

  # Generate models for each schema subdirectory
  for schema_dir in "${SCHEMAS_DIR}"/*/; do
    namespace=$(basename "${schema_dir}")
    out_file="${OUTPUT_DIR}/${namespace}.py"

    echo "  Generating ${out_file} ..."
    datamodel-codegen \
      --input "${schema_dir}" \
      --input-file-type jsonschema \
      --output "${out_file}" \
      --output-model-type pydantic_v2.BaseModel \
      --use-standard-collections \
      --use-annotated \
      --field-constraints
  done

  # Write package __init__.py
  init_file="${OUTPUT_DIR}/__init__.py"
  {
    echo "# Auto-generated — do not edit manually."
    for schema_dir in "${SCHEMAS_DIR}"/*/; do
      namespace=$(basename "${schema_dir}")
      echo "from .${namespace} import *  # noqa: F401, F403"
    done
  } > "${init_file}"

  echo "Done. Models written to ${OUTPUT_DIR}"
else
  echo "[dry-run] No files written."
fi
