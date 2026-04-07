#!/usr/bin/env bash
# =============================================================================
# EMA — Engineering Manager / Software Engineer Assistant
# Onboarding script — safe to run multiple times
#
# Usage:
#   ./install.sh                         # global install + SE repo setup
#   ./install.sh --role em               # global install + EM repo setup
#   ./install.sh --role both             # global install + both EM + SE skills
#   ./install.sh --global                # global install only, skip repo setup
#   ./install.sh --skills "press-release,pr-review"  # cherry-pick specific skills
#   ./install.sh --update                # pull latest EMA + reinstall deps
#
# Options:
#   --role em|se|both   Which skill set to copy into the repo (default: se)
#   --global            Install globally only, skip repo setup
#   --skills "a,b,c"    Comma-separated list of specific skills to copy
#   --update            Force-pull latest EMA even if already installed
#   --ema-dir <path>    Override EMA install location (default: ~/.ema)
#   --no-color          Disable colour output
#   --help              Show this message
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
if [[ "${NO_COLOR:-}" == "1" ]] || [[ ! -t 1 ]]; then
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
else
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
fi

info()    { echo -e "${BLUE}▸${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}── $* ──${RESET}"; }
die()     { error "$*"; exit 1; }

# ── Defaults ─────────────────────────────────────────────────────────────────
ROLE="se"
GLOBAL_ONLY=false
FORCE_UPDATE=false
SPECIFIC_SKILLS=""
EMA_DIR="${HOME}/.ema"
EMA_REPO="https://github.com/your-org/ema"   # ← set your actual repo URL
REPO_DIR="$(pwd)"
UNFILLED=()

# ── Arg parsing ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --role)     ROLE="$2"; shift 2 ;;
    --global)   GLOBAL_ONLY=true; shift ;;
    --update)   FORCE_UPDATE=true; shift ;;
    --skills)   SPECIFIC_SKILLS="$2"; shift 2 ;;
    --ema-dir)  EMA_DIR="$2"; shift 2 ;;
    --no-color) shift ;;
    --help|-h)
      sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

[[ "$ROLE" =~ ^(em|se|both)$ ]] || die "--role must be em, se, or both"

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}EMA — Engineering Manager Assistant${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-14s %s\n" "Role:"    "${ROLE^^}"
printf "  %-14s %s\n" "EMA dir:" "$EMA_DIR"
[[ -n "$SPECIFIC_SKILLS" ]] && printf "  %-14s %s\n" "Skills:" "$SPECIFIC_SKILLS"
[[ "$GLOBAL_ONLY" == false ]] && printf "  %-14s %s\n" "Repo:" "$REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
# STEP 1 — Claude Code
# =============================================================================
header "Step 1 — Claude Code"

if command -v claude &>/dev/null; then
  CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "version unknown")
  success "Claude Code already installed ($CLAUDE_VER)"
else
  info "Installing Claude Code via npm..."
  command -v npm &>/dev/null || die "npm not found. Install Node.js 18+ from https://nodejs.org"
  npm install -g @anthropic-ai/claude-code
  success "Claude Code installed"
fi

# =============================================================================
# STEP 2 — Clone / update EMA
# =============================================================================
header "Step 2 — EMA repository"

if [[ -d "$EMA_DIR/.git" ]]; then
  if [[ "$FORCE_UPDATE" == true ]]; then
    info "Pulling latest EMA..."
    git -C "$EMA_DIR" pull --quiet
    success "EMA updated to latest"
  else
    success "EMA already installed at $EMA_DIR"
    info "Run with --update to pull the latest version"
  fi
else
  info "Cloning EMA into $EMA_DIR..."
  git clone "$EMA_REPO" "$EMA_DIR" \
    || die "Failed to clone EMA. Check your network or the repo URL in this script."
  success "EMA cloned"
fi

# =============================================================================
# STEP 3 — Python venv + dependencies
# =============================================================================
header "Step 3 — Python dependencies"

command -v python3 &>/dev/null || die "python3 not found. Install Python 3.10+ first."

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
if [[ "$PYTHON_MAJOR" -lt 3 ]] || { [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -lt 10 ]]; }; then
  die "Python 3.10+ required (found $PYTHON_VERSION)"
fi

VENV_DIR="$EMA_DIR/.venv"
PYTHON_BIN="$VENV_DIR/bin/python"
PIP_BIN="$VENV_DIR/bin/pip"

if [[ ! -d "$VENV_DIR" ]]; then
  info "Creating virtual environment (Python $PYTHON_VERSION)..."
  python3 -m venv "$VENV_DIR"
fi

info "Installing/updating dependencies..."
"$PIP_BIN" install --quiet --upgrade pip
"$PIP_BIN" install --quiet -r "$EMA_DIR/mcp/requirements.txt"
success "Dependencies ready"

# =============================================================================
# STEP 4 — .env file
# =============================================================================
header "Step 4 — Environment variables"

ENV_FILE="$EMA_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  success ".env found at $ENV_FILE"

  # Check for unfilled placeholder values
  for var in GITHUB_TOKEN GITHUB_ORG JIRA_URL JIRA_EMAIL JIRA_TOKEN JIRA_PROJECT; do
    val=$(grep "^${var}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$val" ]] || [[ "$val" == *"your-"* ]] || [[ "$val" == *"<"* ]]; then
      UNFILLED+=("$var")
    fi
  done

  if [[ ${#UNFILLED[@]} -gt 0 ]]; then
    warn "These tokens still need filling in: ${UNFILLED[*]}"
    warn "Edit: $ENV_FILE"
  else
    success "All required tokens are set"
  fi
else
  cp "$EMA_DIR/.env.example" "$ENV_FILE"
  warn ".env created — fill in your tokens before using EMA"
  echo ""
  printf "    ${BOLD}%-22s${RESET} %s\n" "GITHUB_TOKEN"  "https://github.com/settings/tokens  (scope: repo read)"
  printf "    ${BOLD}%-22s${RESET} %s\n" "GITHUB_ORG"    "your GitHub organisation name"
  printf "    ${BOLD}%-22s${RESET} %s\n" "JIRA_URL"      "https://your-org.atlassian.net"
  printf "    ${BOLD}%-22s${RESET} %s\n" "JIRA_EMAIL"    "your Atlassian login email"
  printf "    ${BOLD}%-22s${RESET} %s\n" "JIRA_TOKEN"    "https://id.atlassian.com/manage-profile/security/api-tokens"
  printf "    ${BOLD}%-22s${RESET} %s\n" "JIRA_PROJECT"  "Jira project key, e.g. PAY"
  echo ""

  EDITOR_CMD="${EDITOR:-}"
  if [[ -z "$EDITOR_CMD" ]]; then
    for e in nano vim vi code; do
      command -v "$e" &>/dev/null && { EDITOR_CMD="$e"; break; }
    done
  fi

  if [[ -n "$EDITOR_CMD" ]]; then
    read -r -p "  Open .env in $EDITOR_CMD now? [Y/n] " answer </dev/tty || true
    if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
      "$EDITOR_CMD" "$ENV_FILE"
    fi
  fi
fi

# Load env for sed substitutions later
set -a
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" 2>/dev/null || true
set +a

# =============================================================================
# STEP 5 — Register MCP server globally
# =============================================================================
header "Step 5 — MCP server"

MCP_SERVER="$EMA_DIR/mcp/server.py"
[[ -f "$MCP_SERVER" ]] || die "MCP server not found at $MCP_SERVER — is the EMA clone complete?"

if claude mcp list 2>/dev/null | grep -q "^ema"; then
  success "EMA MCP server already registered"
  if [[ "$FORCE_UPDATE" == true ]]; then
    info "Re-registering MCP server (--update)..."
    claude mcp remove ema 2>/dev/null || true
    claude mcp add ema --command "$PYTHON_BIN" --args "$MCP_SERVER"
    success "MCP server re-registered"
  fi
else
  info "Registering EMA MCP server globally..."
  claude mcp add ema --command "$PYTHON_BIN" --args "$MCP_SERVER"
  claude mcp list 2>/dev/null | grep -q "^ema" \
    && success "EMA MCP server registered" \
    || warn "Registration may not have taken effect — run 'claude mcp list' to verify"
fi

# =============================================================================
# STEP 6 — Per-repo setup
# =============================================================================
if [[ "$GLOBAL_ONLY" == true ]]; then
  echo ""
  success "Global install complete."
  echo ""
  echo "  To set up a specific repo, cd into it and run:"
  echo "    bash $EMA_DIR/install.sh --role se"
  echo "    bash $EMA_DIR/install.sh --role em"
  echo ""
  exit 0
fi

header "Step 6 — Repo setup (${ROLE^^})"

git -C "$REPO_DIR" rev-parse --git-dir &>/dev/null \
  || die "$REPO_DIR is not a git repository. cd into your repo first."

REPO_NAME=$(basename "$REPO_DIR")
SKILLS_DST="$REPO_DIR/skills"
mkdir -p "$SKILLS_DST"

# ── Helper: copy one skill ────────────────────────────────────────────────────
copy_skill() {
  local name="$1"
  local src_dir="$2"
  local src="$src_dir/$name"
  local dst="$SKILLS_DST/$name"

  if [[ ! -d "$src" ]]; then
    warn "Skill '$name' not found at $src — skipping"
    return
  fi
  if [[ -d "$dst" ]]; then
    info "Skill '$name' already in repo — skipping (delete $dst to reinstall)"
  else
    cp -r "$src" "$dst"
    success "Installed skill: $name"
  fi
}

# ── Copy skills ───────────────────────────────────────────────────────────────
if [[ -n "$SPECIFIC_SKILLS" ]]; then
  info "Cherry-picking skills: $SPECIFIC_SKILLS"
  IFS=',' read -ra SKILL_LIST <<< "$SPECIFIC_SKILLS"
  for skill in "${SKILL_LIST[@]}"; do
    skill=$(echo "$skill" | tr -d ' ')
    found=false
    for dir in em se shared; do
      if [[ -d "$EMA_DIR/skills/$dir/$skill" ]]; then
        copy_skill "$skill" "$EMA_DIR/skills/$dir"
        found=true
        break
      fi
    done
    [[ "$found" == false ]] && warn "Skill '$skill' not found in em/, se/, or shared/"
  done
else
  ROLE_DIRS=()
  [[ "$ROLE" == "em"   || "$ROLE" == "both" ]] && ROLE_DIRS+=("em")
  [[ "$ROLE" == "se"   || "$ROLE" == "both" ]] && ROLE_DIRS+=("se")

  for role_dir in "${ROLE_DIRS[@]}"; do
    SRC="$EMA_DIR/skills/$role_dir"
    if [[ -d "$SRC" ]]; then
      info "Copying ${role_dir^^} skills..."
      for skill_path in "$SRC"/*/; do
        [[ -d "$skill_path" ]] && copy_skill "$(basename "$skill_path")" "$SRC"
      done
    else
      warn "No skills directory at $SRC"
    fi
  done

  SHARED="$EMA_DIR/skills/shared"
  if [[ -d "$SHARED" ]]; then
    info "Copying shared skills..."
    for skill_path in "$SHARED"/*/; do
      [[ -d "$skill_path" ]] && copy_skill "$(basename "$skill_path")" "$SHARED"
    done
  fi
fi

# ── CLAUDE.md ────────────────────────────────────────────────────────────────
CLAUDE_MD="$REPO_DIR/CLAUDE.md"
TMPL_ROLE="$ROLE"; [[ "$ROLE" == "both" ]] && TMPL_ROLE="em"
TEMPLATE="$EMA_DIR/templates/CLAUDE.${TMPL_ROLE}.md"

if [[ -f "$CLAUDE_MD" ]]; then
  warn "CLAUDE.md already exists — leaving it unchanged"
  info "Reference template: $TEMPLATE"
else
  if [[ -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$CLAUDE_MD"
    GITHUB_REPO_VAL="${GITHUB_ORG:-your-org}/$REPO_NAME"
    sed -i.bak "s|your-org/your-repo|$GITHUB_REPO_VAL|g"                      "$CLAUDE_MD" 2>/dev/null || true
    sed -i.bak "s|GITHUB_ORG=your-org|GITHUB_ORG=${GITHUB_ORG:-your-org}|g"   "$CLAUDE_MD" 2>/dev/null || true
    sed -i.bak "s|JIRA_PROJECT=YOUR_KEY|JIRA_PROJECT=${JIRA_PROJECT:-YOUR_KEY}|g" "$CLAUDE_MD" 2>/dev/null || true
    rm -f "$CLAUDE_MD.bak"
    success "CLAUDE.md created"
    warn "Edit CLAUDE.md: set product name, team context, and CTO name"
  else
    warn "Template not found at $TEMPLATE — create CLAUDE.md manually"
  fi
fi

# ── .gitignore ────────────────────────────────────────────────────────────────
GITIGNORE="$REPO_DIR/.gitignore"
for entry in ".env" ".env.local"; do
  if [[ -f "$GITIGNORE" ]]; then
    grep -qxF "$entry" "$GITIGNORE" || { echo "$entry" >> "$GITIGNORE"; success "Added $entry to .gitignore"; }
  else
    echo "$entry" > "$GITIGNORE"
    success "Created .gitignore"
  fi
done

# =============================================================================
# DONE
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}${BOLD}  EMA is ready!${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${#UNFILLED[@]} -gt 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}Action required:${RESET}"
  echo    "    nano $ENV_FILE"
  echo    "    (Fill in: ${UNFILLED[*]})"
  echo ""
fi

echo -e "  ${BOLD}Then customise your repo context:${RESET}"
echo    "    nano $CLAUDE_MD"
echo ""
echo -e "  ${BOLD}Then start:${RESET}"
echo    "    cd $REPO_DIR && claude"
echo ""
echo -e "  ${BOLD}Example prompts (${ROLE^^}):${RESET}"
if [[ "$ROLE" == "em" || "$ROLE" == "both" ]]; then
  echo '    "write the press release for v4.2.0"'
  echo '    "review this PR: https://github.com/org/repo/pull/42"'
  echo '    "run the retro for this sprint"'
  echo '    "prep my 1-on-1 with Alice"'
fi
if [[ "$ROLE" == "se" || "$ROLE" == "both" ]]; then
  echo '    "debug the failing PaymentProcessorTest"'
  echo '    "generate unit tests for RefundService"'
  echo '    "run RCA on the payment failure spike"'
  echo '    "review my changes before I push"'
fi
echo ""
echo "  Skills: $SKILLS_DST"
echo "  EMA:    $EMA_DIR"
echo ""