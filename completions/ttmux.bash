# bash completion for ttmux(1)                             -*- shell-script -*-

_ttmux_profiles() {
  local dir="$HOME/.ttmux" f
  [[ -d $dir ]] || return 0
  for f in "$dir"/*; do
    [[ -f $f ]] && printf '%s\n' "${f##*/}"
  done
}

_ttmux_sessions() {
  tmux ls -F '#{session_name}' 2>/dev/null
}

# tmux autorise les espaces dans les noms de session : sans échappement, le
# candidat inséré serait relu comme deux arguments.
_ttmux_escape_reply() {
  local i
  for i in "${!COMPREPLY[@]}"; do
    COMPREPLY[i]=${COMPREPLY[i]// /\\ }
  done
}

_ttmux_complete_profile() {
  local cur=$1
  # Un argument contenant "/" (ou un ~) est un chemin, pas un nom de profil.
  if [[ $cur == */* || $cur == '~'* ]]; then
    if declare -F _filedir >/dev/null 2>&1; then
      _filedir
    else
      local IFS=$'\n'
      COMPREPLY=( $(compgen -f -- "$cur") )
    fi
  else
    local IFS=$'\n'
    COMPREPLY=( $(compgen -W "$(_ttmux_profiles)" -- "$cur") )
    _ttmux_escape_reply
  fi
}

_ttmux() {
  local cur prev words cword
  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -n : || return
  else
    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  # 1. Valeur attendue par le flag précédent.
  case $prev in
    -p|--profile)
      _ttmux_complete_profile "$cur"
      return 0
      ;;
    -c)
      local IFS=$'\n'
      COMPREPLY=( $(compgen -c -- "$cur" | sort -u) )
      return 0
      ;;
  esac

  # 2. Ce qui a déjà été saisi : session positionnelle, mode exclusif.
  local i w skip=0 seen_session=0 exclusive=0
  for (( i = 1; i < cword; i++ )); do
    w=${words[i]}
    if (( skip )); then skip=0; continue; fi
    case $w in
      -c|-p|--profile)  skip=1 ;;
      -l|--list|--help) exclusive=1 ;;
      -*)               ;;
      list)             if (( i == 1 )); then exclusive=1; else seen_session=1; fi ;;
      *)                seen_session=1 ;;
    esac
  done
  (( exclusive )) && return 0

  # 3. Flags.
  if [[ $cur == -* ]]; then
    COMPREPLY=( $(compgen -W '-c -h -v -p --profile -N --no-config -l --list --help' -- "$cur") )
    return 0
  fi

  # 4. Nom de session (une seule position ; "list" seulement en premier).
  (( seen_session )) && return 0
  local candidates
  candidates=$(_ttmux_sessions)
  (( cword == 1 )) && candidates=$'list\n'$candidates
  local IFS=$'\n'
  COMPREPLY=( $(compgen -W "$candidates" -- "$cur") )
  _ttmux_escape_reply
}

complete -F _ttmux ttmux
