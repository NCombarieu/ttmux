#!/usr/bin/env bash
# Suite de tests ttmux — sans dépendance externe (bash + tmux).
#
# Chaque test tourne contre un serveur tmux jetable (TMUX_TMPDIR dédié) et un
# répertoire de profils dédié (TTMUX_PROFILE_DIR), donc rien ne touche aux
# sessions ni à la config de l'utilisateur.
#
# Usage : tests/run.sh [motif]   (motif = sous-chaîne du nom des tests à jouer)

set -uo pipefail

TTMUX=${TTMUX:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ttmux"}

# Le socket tmux est un socket UNIX : chemin court obligatoire (~108 octets).
TMPROOT=$(mktemp -d /tmp/ttmux-test.XXXXXX)
export TMUX_TMPDIR="$TMPROOT/sock"
export TTMUX_PROFILE_DIR="$TMPROOT/profiles"
# HOME isolé : le ~/.tmux.conf de l'utilisateur ne doit pas influencer les
# tests, et la taille des sessions détachées doit être connue pour vérifier
# les splits en pourcentage.
export HOME="$TMPROOT/home"
mkdir -p "$TMUX_TMPDIR" "$TTMUX_PROFILE_DIR" "$HOME"
printf 'set -g default-size 200x50\n' > "$HOME/.tmux.conf"
# ttmux ne doit jamais croire qu'il tourne dans un tmux.
unset TMUX

pass=0; fail=0; filter=${1:-}
declare -a FAILURES=()

cleanup() {
  tmux kill-server 2>/dev/null
  rm -rf "$TMPROOT"
}
trap cleanup EXIT

# --- Helpers ------------------------------------------------------------------

# Réinitialise serveur tmux et profils entre deux tests. On attend la mort
# effective du serveur : le recréer trop tôt donne des « server exited
# unexpectedly » intermittents.
reset_env() {
  local i
  tmux kill-server 2>/dev/null
  for (( i = 0; i < 50; i++ )); do
    tmux has-session 2>/dev/null || break
    sleep 0.02
  done
  rm -rf "$TTMUX_PROFILE_DIR"
  mkdir -p "$TTMUX_PROFILE_DIR"
}

# Lance ttmux ; renseigne OUT (stdout), ERR (stderr) et RC.
run() {
  OUT=$("$TTMUX" "$@" 2>"$TMPROOT/err"); RC=$?
  ERR=$(cat "$TMPROOT/err")
  return 0
}

profile() { # profile <nom> <<'EOF' ... EOF
  cat > "$TTMUX_PROFILE_DIR/$1"
}

check() { # check <description> <condition-humaine> <valeur attendue> <valeur obtenue>
  if [[ "$3" == "$4" ]]; then
    return 0
  fi
  FAILURES+=("$CURRENT_TEST — $1
    attendu : $(printf '%q' "$3")
    obtenu  : $(printf '%q' "$4")")
  return 1
}

check_contains() {
  if [[ "$4" == *"$3"* ]]; then
    return 0
  fi
  FAILURES+=("$CURRENT_TEST — $1
    doit contenir : $(printf '%q' "$3")
    obtenu        : $(printf '%q' "$4")")
  return 1
}

panes()   { tmux list-panes   -t "=$1" -F '#{pane_index}' 2>/dev/null | wc -l; }
windows() { tmux list-windows -t "=$1" -F '#{window_name}' 2>/dev/null | tr '\n' ',' ; }

COMPLETION="$(dirname "$TTMUX")/completions/ttmux.bash"

# Joue la complétion bash sur une ligne de commande donnée ; le dernier
# argument est le mot en cours de frappe (éventuellement vide).
comp() {
  bash -c '
    set -u
    # shellcheck source=/dev/null
    source "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 ))
    COMP_LINE="${COMP_WORDS[*]}"; COMP_POINT=${#COMP_LINE}
    _ttmux
    printf "%s\n" ${COMPREPLY[@]+"${COMPREPLY[@]}"}
  ' _ "$COMPLETION" "$@"
}

# --- Déclaration et exécution des tests ---------------------------------------
TESTS=()
test_case() { TESTS+=("$1"); }

# ============================ Tests ===========================================

test_case t_version
t_version() {
  run --version
  check "code retour" rc 0 "$RC"
  check_contains "affiche la version" x "ttmux 1." "$OUT"
  # La version du script doit rester alignée sur le packaging. Ces deux
  # fichiers ne sont pas dans le tarball : on saute la vérif s'ils manquent.
  local root mk spec
  root=$(dirname "$TTMUX")
  if [[ -f $root/Makefile ]]; then
    mk=$(sed -n 's/^VERSION *:= *//p' "$root/Makefile")
    check "version alignée avec le Makefile" v "ttmux $mk" "$OUT"
  fi
  if [[ -f $root/ttmux.spec ]]; then
    spec=$(sed -n 's/^Version: *//p' "$root/ttmux.spec" | tr -d ' ')
    check "version alignée avec le .spec" v "ttmux $spec" "$OUT"
  fi
}

test_case t_help
t_help() {
  run --help
  check "code retour" rc 0 "$RC"
  check_contains "affiche l'usage" x "Usage: ttmux" "$OUT"
}

test_case t_unknown_flag
t_unknown_flag() {
  run -Z
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "flag inconnu" "$ERR"
}

test_case t_missing_arg
t_missing_arg() {
  run dev -c
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "-c attend une commande" "$ERR"
}

test_case t_invalid_session_name
t_invalid_session_name() {
  run "a.b" -d
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "nom de session invalide" "$ERR"
}

test_case t_create_and_attach_detached
t_create_and_attach_detached() {
  run dev -N -d
  check "code retour" rc 0 "$RC"
  check "session créée" n 1 "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
  check "un seul pane" n 1 "$(panes dev)"
}

test_case t_layout_splits
t_layout_splits() {
  run dev -N -d -c 'echo un' -h -c 'echo deux' -v -c 'echo trois'
  check "code retour" rc 0 "$RC"
  check "trois panes" n 3 "$(panes dev)"
}

test_case t_split_percentage
t_split_percentage() {
  run dev -N -d -h25
  check "code retour" rc 0 "$RC"
  check "deux panes" n 2 "$(panes dev)"
  # default-size vaut 200x50 (cf. le .tmux.conf du HOME isolé) : le pane de
  # droite doit faire ~25 % de 200 colonnes, séparateur compris.
  local width
  width=$(tmux list-panes -t '=dev' -F '#{pane_width}' | tail -n1)
  if (( width < 45 || width > 55 )); then
    check "largeur du pane de droite (~50 colonnes)" w "45..55" "$width"
  fi
}

test_case t_split_percentage_invalid
t_split_percentage_invalid() {
  run dev -N -d -h250
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "taille de split invalide" "$ERR"
  check "aucune session créée" n 0 "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_window
t_window() {
  run dev -N -d -w logs
  check "code retour" rc 0 "$RC"
  check_contains "fenêtre nommée créée" x "logs," "$(windows dev)"
}

test_case t_cwd
t_cwd() {
  mkdir -p "$TMPROOT/proj"
  run dev -N -d -C "$TMPROOT/proj"
  check "code retour" rc 0 "$RC"
  check "cwd de la session" p "$(realpath "$TMPROOT/proj")" \
        "$(realpath "$(tmux list-panes -t '=dev' -F '#{pane_current_path}' | head -n1)")"
}

test_case t_cwd_missing
t_cwd_missing() {
  run dev -N -d -C "$TMPROOT/nexistepas"
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "répertoire introuvable" "$ERR"
  check "aucune session créée" n 0 "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_end_of_options
t_end_of_options() {
  run -N -d -- -scratch
  check "code retour" rc 0 "$RC"
  check "session au nom en tiret créée" n 1 \
        "$(tmux has-session -t '=-scratch' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_existing_session_warns
t_existing_session_warns() {
  run dev -N -d -c 'echo un' -h
  check "deux panes après création" n 2 "$(panes dev)"
  run dev -d -c 'echo deux' -v
  check "code retour" rc 0 "$RC"
  check_contains "avertissement" x "existe déjà" "$ERR"
  check "layout inchangé" n 2 "$(panes dev)"
}

test_case t_routing_single_session
t_routing_single_session() {
  tmux new-session -d -s solo
  run -d
  check "code retour" rc 0 "$RC"
  check "pas de session créée en plus" n 1 "$(tmux ls 2>/dev/null | wc -l)"
}

test_case t_routing_two_sessions_lists
t_routing_two_sessions_lists() {
  tmux new-session -d -s a
  tmux new-session -d -s b
  run
  check "code retour" rc 0 "$RC"
  check_contains "liste a" x "a:" "$OUT"
  check_contains "liste b" x "b:" "$OUT"
}

test_case t_routing_default_name
t_routing_default_name() {
  run -N -d
  check "code retour" rc 0 "$RC"
  check "session main créée" n 1 \
        "$(tmux has-session -t '=main' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_list_no_server
t_list_no_server() {
  run list
  check "code retour" rc 0 "$RC"
  check_contains "message clair, pas l'erreur brute de tmux" x "aucune session tmux" "$ERR"
}

test_case t_list_exclusive
t_list_exclusive() {
  tmux new-session -d -s a
  run -l dev -N
  check "code retour" rc 0 "$RC"
  check_contains "avertissement d'exclusivité" x "exclusif" "$ERR"
  check_contains "liste affichée" x "a:" "$OUT"
}

test_case t_profile_default_base
t_profile_default_base() {
  profile base <<'EOF'
-c 'echo base'
-h
EOF
  run dev -d --dry-run
  check "code retour" rc 0 "$RC"
  check_contains "commande du profil" x "send-keys -t '<pane0>' 'echo base'" "$OUT"
  check_contains "split du profil" x "split-window -h" "$OUT"
}

test_case t_profile_no_config
t_profile_no_config() {
  profile base <<'EOF'
-c 'echo base'
EOF
  run dev -N -d --dry-run
  check "code retour" rc 0 "$RC"
  check "aucun send-keys" n "" "$(grep -c 'send-keys' <<<"$OUT" | grep -v '^0$')"
}

test_case t_profile_order_before_cli
t_profile_order_before_cli() {
  profile base <<'EOF'
-c 'echo profil'
EOF
  run dev -d --dry-run -c 'echo cli'
  local order
  order=$(grep -o "echo profil\|echo cli" <<<"$OUT" | tr '\n' ' ')
  check "profil appliqué avant la CLI" o "echo profil echo cli " "$order"
}

test_case t_profile_include
t_profile_include() {
  profile common <<'EOF'
-c 'echo commun'
EOF
  profile base <<'EOF'
include common
-c 'echo base'
EOF
  run dev -d --dry-run
  check "code retour" rc 0 "$RC"
  check_contains "ligne incluse" x "echo commun" "$OUT"
  check_contains "ligne locale" x "echo base" "$OUT"
}

test_case t_profile_include_cycle
t_profile_include_cycle() {
  profile a <<'EOF'
include b
-c 'echo a'
EOF
  profile b <<'EOF'
include a
-c 'echo b'
EOF
  run dev -p a -d --dry-run
  check "code retour (cycle ignoré, pas de boucle)" rc 0 "$RC"
  check_contains "ligne de a" x "echo a" "$OUT"
  check_contains "ligne de b" x "echo b" "$OUT"
}

test_case t_profile_include_missing_fails
t_profile_include_missing_fails() {
  profile base <<'EOF'
include absent
-c 'echo base'
EOF
  run dev -d
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "profil introuvable" "$ERR"
  check "aucune session créée" n 0 \
        "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_profile_missing_fails
t_profile_missing_fails() {
  run dev -p absent -d
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "profil introuvable" "$ERR"
}

test_case t_profile_bad_flag_fails_before_create
t_profile_bad_flag_fails_before_create() {
  profile base <<'EOF'
-Z
EOF
  run dev -d
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "flag de setup inconnu" "$ERR"
  check "aucune session à moitié créée" n 0 \
        "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
}

test_case t_profile_unbalanced_quotes
t_profile_unbalanced_quotes() {
  profile base <<'EOF'
-c 'echo oups
EOF
  run dev -d
  check "code retour" rc 1 "$RC"
  check_contains "message d'erreur" x "ligne de profil invalide" "$ERR"
}

test_case t_profile_cwd
t_profile_cwd() {
  mkdir -p "$TMPROOT/fromprofile"
  profile base <<EOF
-C $TMPROOT/fromprofile
EOF
  run dev -d
  check "code retour" rc 0 "$RC"
  check "cwd issu du profil" p "$(realpath "$TMPROOT/fromprofile")" \
        "$(realpath "$(tmux list-panes -t '=dev' -F '#{pane_current_path}' | head -n1)")"
}

test_case t_cli_cwd_overrides_profile
t_cli_cwd_overrides_profile() {
  mkdir -p "$TMPROOT/fromprofile" "$TMPROOT/fromcli"
  profile base <<EOF
-C $TMPROOT/fromprofile
EOF
  run dev -d -C "$TMPROOT/fromcli"
  check "cwd de la CLI prioritaire" p "$(realpath "$TMPROOT/fromcli")" \
        "$(realpath "$(tmux list-panes -t '=dev' -F '#{pane_current_path}' | head -n1)")"
}

test_case t_dry_run_creates_nothing
t_dry_run_creates_nothing() {
  run dev -N --dry-run -c 'echo salut' -h
  check "code retour" rc 0 "$RC"
  check "aucune session créée" n 0 \
        "$(tmux has-session -t '=dev' 2>/dev/null && echo 1 || echo 0)"
  check_contains "new-session affichée" x "tmux new-session -d -s dev" "$OUT"
  check_contains "attach affichée" x "tmux attach-session -t =dev" "$OUT"
}

test_case t_completion_flags
t_completion_flags() {
  local out
  out=$(comp ttmux -)
  check_contains "propose --dry-run" x "--dry-run" "$out"
  check_contains "propose -C" x "-C" "$out"
  check_contains "propose --version" x "--version" "$out"
}

test_case t_completion_sessions
t_completion_sessions() {
  tmux new-session -d -s alpha
  tmux new-session -d -s beta
  local out
  out=$(comp ttmux "")
  check_contains "propose une session existante" x "alpha" "$out"
  check_contains "propose la sous-commande list" x "list" "$out"
}

test_case t_completion_profiles
t_completion_profiles() {
  profile web </dev/null
  profile api </dev/null
  local out
  out=$(comp ttmux -p "")
  check_contains "propose un profil" x "web" "$out"
  check_contains "propose l'autre profil" x "api" "$out"
}

test_case t_completion_exclusive_modes
t_completion_exclusive_modes() {
  tmux new-session -d -s alpha
  check "rien après --help" c "" "$(comp ttmux --help "")"
  check "rien après --version" c "" "$(comp ttmux --version "")"
}

test_case t_completion_after_dashdash
t_completion_after_dashdash() {
  tmux new-session -d -s alpha
  local out
  out=$(comp ttmux -- "")
  check_contains "propose encore les sessions après --" x "alpha" "$out"
  check "n'\''enchaîne pas sur des flags" c "" "$(comp ttmux -- - | grep -- '--dry-run')"
}

# ============================ Runner ==========================================
for t in "${TESTS[@]}"; do
  [[ -n "$filter" && "$t" != *"$filter"* ]] && continue
  CURRENT_TEST="${t#t_}"
  reset_env
  before=${#FAILURES[@]}
  "$t"
  if [[ ${#FAILURES[@]} -eq $before ]]; then
    printf '  \033[32mok\033[0m   %s\n' "$CURRENT_TEST"
    (( ++pass ))
  else
    printf '  \033[31mFAIL\033[0m %s\n' "$CURRENT_TEST"
    (( ++fail ))
  fi
done

if [[ $fail -gt 0 ]]; then
  printf '\n'
  for f in "${FAILURES[@]}"; do printf '%s\n\n' "$f"; done
fi
printf '\n%d réussis, %d échoués\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
