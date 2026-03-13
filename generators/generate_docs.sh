#!/usr/bin/env bash
# generate_docs.sh
# Generates HTML documentation from OpenAPI specs using redoc-cli or @redocly/cli.
#
# Requirements:
#   npm install -g @redocly/cli
#
# Usage:
#   ./generators/generate_docs.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/docs"
OPENAPI_DIR="${REPO_ROOT}/openapi"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] Would generate docs into: ${OUTPUT_DIR}"
fi

if [[ "${DRY_RUN}" == "false" ]] && ! command -v redocly &>/dev/null; then
  echo "Error: redocly CLI not found. Install it with: npm install -g @redocly/cli" >&2
  exit 1
fi

echo "Generating API documentation from OpenAPI specs in: ${OPENAPI_DIR}"
echo "Output directory: ${OUTPUT_DIR}"

if [[ "${DRY_RUN}" == "false" ]]; then
  mkdir -p "${OUTPUT_DIR}"

  # Generate docs for each OpenAPI spec file
  find "${OPENAPI_DIR}" -name "*.yaml" -o -name "*.yml" | sort | while read -r spec_file; do
    relative_path="${spec_file#"${OPENAPI_DIR}/"}"
    html_file="${OUTPUT_DIR}/${relative_path%.*}.html"
    html_dir="$(dirname "${html_file}")"

    mkdir -p "${html_dir}"
    echo "  Generating ${html_file} ..."
    redocly build-docs "${spec_file}" \
      --output "${html_file}" \
      --title "$(basename "${spec_file%.*}" | sed 's/[-_.]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')"
  done

  # Write an index page linking all generated docs
  index_file="${OUTPUT_DIR}/index.html"
  cat > "${index_file}" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>API Documentation</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; }
    h1 { color: #333; }
    ul { list-style: none; padding: 0; }
    li { margin: 0.5rem 0; }
    a { color: #0070f3; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>API Documentation</h1>
  <ul id="spec-list"></ul>
  <script>
    // Populated by the build script at generation time
    const specs = SPEC_LIST_PLACEHOLDER;
    const list = document.getElementById('spec-list');
    specs.forEach(({ title, href }) => {
      const li = document.createElement('li');
      const a = document.createElement('a');
      a.href = href;
      a.textContent = title;
      li.appendChild(a);
      list.appendChild(li);
    });
  </script>
</body>
</html>
HTML

  # Replace placeholder with actual spec list
  spec_json="["
  first=true
  find "${OUTPUT_DIR}" -name "*.html" ! -name "index.html" | sort | while read -r html_file; do
    rel="${html_file#"${OUTPUT_DIR}/"}"
    title="$(basename "${html_file%.html}" | sed 's/[-_.]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')"
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      spec_json+=","
    fi
    spec_json+="{\"title\":\"${title}\",\"href\":\"${rel}\"}"
  done
  spec_json+="]"

  # Portable in-place substitution (works on both GNU sed and BSD sed/macOS)
  sed -i.bak "s|SPEC_LIST_PLACEHOLDER|${spec_json}|" "${index_file}" && rm -f "${index_file}.bak"

  echo "Done. Documentation written to ${OUTPUT_DIR}"
else
  echo "[dry-run] No files written."
fi
