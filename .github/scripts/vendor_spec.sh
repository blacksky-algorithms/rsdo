#!/bin/bash
#
# Vendor the DigitalOcean OpenAPI specification into spec/ at a given revision.
#
# Usage: .github/scripts/vendor_spec.sh <git-ref>
#   e.g. .github/scripts/vendor_spec.sh main
#        .github/scripts/vendor_spec.sh 7c1300c479fed9c353cda9fc21cd968619552304
#
# Downloads the upstream tree, scrubs secret-shaped example values, writes
# spec/REVISION, and updates the OPENAPI_SPEC_REF pin in build.rs.
#
# Used both by hand and by .github/workflows/spec-drift.yml, so the vendored tree
# is produced exactly the same way either way.

set -euo pipefail

REF="${1:?usage: vendor_spec.sh <git-ref>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Downloading digitalocean/openapi at ${REF}..."
curl -fsSL "https://github.com/digitalocean/openapi/archive/${REF}.tar.gz" \
  -o "$WORKDIR/openapi.tar.gz"

mkdir -p "$WORKDIR/extract"
tar xzf "$WORKDIR/openapi.tar.gz" -C "$WORKDIR/extract" --strip-components=1

if [ ! -f "$WORKDIR/extract/specification/DigitalOcean-public.v2.yaml" ]; then
    echo "❌ Extracted tree has no specification/DigitalOcean-public.v2.yaml" >&2
    exit 1
fi

# Resolve the ref to a concrete commit SHA. A branch name like "main" is a moving
# target; the whole point of vendoring is to record exactly what was used.
RESOLVED_SHA="$(curl -fsSL \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/digitalocean/openapi/commits/${REF}" \
    | sed -n 's/^  "sha": "\(.*\)",$/\1/p' | head -n 1)"

if [ -z "$RESOLVED_SHA" ]; then
    echo "❌ Could not resolve ${REF} to a commit SHA" >&2
    exit 1
fi
echo "Resolved ${REF} -> ${RESOLVED_SHA}"

rm -rf spec/specification
cp -R "$WORKDIR/extract/specification" spec/specification

# Normalize permissions. Upstream marks a number of plain YAML data files
# executable; carrying that through adds meaningless mode churn to every
# re-vendor diff and depends on how the archive was extracted.
find spec/specification -type d -exec chmod 755 {} +
find spec/specification -type f -exec chmod 644 {} +

# --- Scrub secret-shaped example values -------------------------------------
#
# Upstream's spec carries placeholder Slack webhook URLs and PEM private-key
# blocks as `example:` values. GitHub push protection rejects pushes containing
# them ("Slack Incoming Webhook URL"), which would block this repo AND make the
# unattended weekly spec-drift push fail every time it ran.
#
# These are only `example:` strings: they land in generated doc comments and
# never affect the generated API surface. Scrubbing them keeps push protection
# enabled -- which is worth more than byte-identical fidelity to upstream
# placeholders.

echo "Scrubbing secret-shaped example values..."

# Slack incoming webhook URLs
find spec/specification -type f -name '*.yml' -print0 \
  | xargs -0 perl -pi -e \
    's{https://hooks\.slack\.com/services/[A-Za-z0-9/_-]+}
      {https://hooks.slack.com/services/REDACTED/EXAMPLE/WEBHOOK}gx'

# PEM private key blocks, in both the literal and the \n-escaped single-line form
find spec/specification -type f -name '*.yml' -print0 \
  | xargs -0 perl -0777 -pi -e \
    's{-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----.*?-----END (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----}
      {-----BEGIN PRIVATE KEY-----\\nREDACTED-EXAMPLE-KEY\\n-----END PRIVATE KEY-----}gs'

# Verify the scrub actually took. A silent miss here means a push blocked by
# secret scanning -- which for the unattended drift workflow means a silent
# weekly failure, so fail loudly here instead.
#
# Note: X.509 *certificates* are deliberately left alone. They are public data,
# secret scanning does not flag them, and they are useful as realistic examples.
if grep -rho "hooks\.slack\.com/services/[A-Za-z0-9/_-]*" spec/specification \
   | grep -qv "^hooks\.slack\.com/services/REDACTED/EXAMPLE/WEBHOOK$"; then
    echo "❌ Slack webhook placeholders survived scrubbing:" >&2
    grep -rho "hooks\.slack\.com/services/[A-Za-z0-9/_-]*" spec/specification \
      | grep -v "^hooks\.slack\.com/services/REDACTED/EXAMPLE/WEBHOOK$" | sort -u >&2
    exit 1
fi

# Real key material is a PRIVATE KEY header followed by a long base64 run.
if grep -rqE "BEGIN[A-Z ]*PRIVATE KEY-----(\\\\n|[[:space:]])*[A-Za-z0-9+/]{40,}" \
     spec/specification; then
    echo "❌ PEM private key material survived scrubbing:" >&2
    grep -rlE "BEGIN[A-Z ]*PRIVATE KEY-----(\\\\n|[[:space:]])*[A-Za-z0-9+/]{40,}" \
      spec/specification >&2
    exit 1
fi

echo "$RESOLVED_SHA" > spec/REVISION

# --- Update the pin recorded in build.rs ------------------------------------
SHORT="${RESOLVED_SHA:0:8}"
COMMIT_JSON="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/digitalocean/openapi/commits/${RESOLVED_SHA}")"
SUBJECT="$(printf '%s' "$COMMIT_JSON" | sed -n 's/^    "message": "\(.*\)",$/\1/p' | head -n 1 | cut -d'\' -f1)"
DATE="$(printf '%s' "$COMMIT_JSON" | sed -n 's/^      "date": "\(.*\)"$/\1/p' | head -n 1 | cut -dT -f1)"
: "${SUBJECT:=unknown}"
: "${DATE:=unknown}"

perl -pi -e \
  "s|^const OPENAPI_SPEC_REF: &str = \".*\";|const OPENAPI_SPEC_REF: &str = \"${RESOLVED_SHA}\";|" \
  build.rs
perl -pi -e \
  "s|^/// Pinned to \`.*|/// Pinned to \`${SHORT}\` (${DATE}, \"${SUBJECT}\").|" \
  build.rs

grep -q "$RESOLVED_SHA" build.rs || { echo "❌ build.rs pin was not updated" >&2; exit 1; }

echo "✅ Vendored spec at ${RESOLVED_SHA} ($(find spec/specification -type f | wc -l | tr -d ' ') files)"
