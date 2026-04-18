#!/usr/bin/env bash
set -euo pipefail

DESIGN_DOC="meta-evb/meta-common/recipes-phosphor/ip-camera/README.md"
AGENT_FILE=".github/agents/OpenBMC IP-Camera Maintainer.agent.md"

# Paths that must stay aligned with the design doc.
SCOPE_REGEX='^(meta-evb/meta-common/recipes-phosphor/ip-camera/|meta-evb/meta-common/recipes-multimedia/go2rtc/|meta-evb/meta-common/recipes-phosphor/images/obmc-phosphor-image.bbappend|meta-evb/meta-common/conf/machine/include/evb-rpi-camera-common.inc)'

get_changed_files() {
    if [[ -n "${BASE_REF:-}" ]]; then
        git fetch --no-tags --depth=1 origin "${BASE_REF}" >/dev/null 2>&1 || true
        git diff --name-only "origin/${BASE_REF}...HEAD"
        return
    fi

    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        git diff --name-only HEAD~1..HEAD
    else
        git ls-files
    fi
}

CHANGED_FILES="$(get_changed_files)"

echo "Changed files:"
echo "${CHANGED_FILES}"

if [[ -z "${CHANGED_FILES}" ]]; then
    echo "No changed files detected."
    exit 0
fi

if ! echo "${CHANGED_FILES}" | grep -Eq "${SCOPE_REGEX}"; then
    echo "No IP-camera scoped files changed. Skip design-alignment check."
    exit 0
fi

# Rule 1: Scoped changes must update design doc in same change set.
if ! echo "${CHANGED_FILES}" | grep -Fxq "${DESIGN_DOC}"; then
    echo "ERROR: IP-camera scoped files changed but ${DESIGN_DOC} was not updated."
    echo "Please update the design doc or split the change with explicit design update first."
    exit 1
fi

# Rule 2: Agent guardrail file must keep design constraints.
if [[ ! -f "${AGENT_FILE}" ]]; then
    echo "ERROR: Agent policy file missing: ${AGENT_FILE}"
    exit 1
fi

if ! grep -q "设计文档强约束" "${AGENT_FILE}"; then
    echo "ERROR: Agent policy does not contain required design constraints section."
    exit 1
fi

# Rule 3: For PR event, require alignment fields in PR body.
if [[ -n "${PR_BODY:-}" ]]; then
    if ! echo "${PR_BODY}" | grep -q "Design section(s) used in this change"; then
        echo "ERROR: PR body missing design alignment section."
        exit 1
    fi
    if ! echo "${PR_BODY}" | grep -q "Requirement -> File -> Validation command -> Result"; then
        echo "ERROR: PR body missing requirements coverage mapping section."
        exit 1
    fi
fi

echo "Design alignment check passed."
