# Detect shell
if [ -n "${ZSH_VERSION:-}" ]; then shell="zsh"; else shell="bash"; fi
# Detect whether zsh 'shwordsplit' option is on by default.
if [ $shell = "zsh" ]; then zsh_shwordsplit=$( (setopt | grep -q shwordsplit) && echo "true" ); fi
# Switch on/off shwordsplit for functions that require it.
zsh_compat(){ if [ $shell = "zsh" ] && [ -z $zsh_shwordsplit ]; then setopt shwordsplit; fi; }
zsh_reset(){  if [ $shell = "zsh" ] && [ -z $zsh_shwordsplit ]; then unsetopt shwordsplit; fi; }
# Enable/disable nullglob for zsh or bash
enable_nullglob()  { if [ $shell = "zsh" ]; then setopt NULL_GLOB;   else shopt -s nullglob; fi; }
disable_nullglob() { if [ $shell = "zsh" ]; then unsetopt NULL_GLOB; else shopt -u nullglob; fi; }

# Alias wrapper that ignores errors if alias is not defined.
_safe_alias(){ alias "$@" 2> /dev/null; }
_alias() {
  if [ -n "$1" ]; then
    local alias_str="$1"; shift; local cmd="$*"
    _safe_alias $alias_str="$cmd"
  fi
}

find_binary(){
  if [ $shell = "zsh" ]; then
    builtin type -p "$1" | sed "s/$1 is //" | head -1
  else
    builtin type -P "$1"
  fi
}

export GIT_BINARY=$(find_binary git)

function find_in_cwd_or_parent() {
  local slashes=${PWD//[^\/]/}; local directory=$PWD;
  for (( n=${#slashes}; n>0; --n )); do
    test -e "$directory/$1" && echo "$directory/$1" && return 0
    directory="$directory/.."
  done
  return 1
}

function fail_if_not_git_repo() {
  if ! find_in_cwd_or_parent ".git" > /dev/null; then
    echo -e "\033[31mNot a git repository (or any of the parent directories)\033[0m"
    return 1
  fi
  return 0
}

function fail_if_not_hg_repo() {
  if ! find_in_cwd_or_parent ".hg" > /dev/null; then
    echo -e "\033[31mNot a hg repository (or any of the parent directories)\033[0m"
    return 1
  fi
  return 0
}

_print_path() {
  if [ "$1" = 1 ]; then
    eval printf '%s' "\"\$$2\"" | sed -e "s%$(pwd)/%%" | awk '{printf("%s", $0)}'
  else
    eval printf '%s' "\"\$$2\""
  fi
}

# Allows expansion of numbered shortcuts, ranges of shortcuts, or standard paths.
# Numbered shortcut variables are produced by various commands, such as:
# * git_status_shortcuts()  - git status implementation
# * git_show_affected_files() - shows files affected by a given SHA1, etc.
# * hg status / sl
scmb_expand_args() {
  # Check for --relative param
  if [ "$1" = "--relative" ]; then
    local relative=1
    shift
  fi

  first=1
  regex='^[0-9]{0,4}(\^|~[0-9]+)*$'
  OLDIFS="$IFS"; IFS=" " # We need to split on spaces to loop over expanded range
  for arg in "$@"; do
    if [[ "$arg" =~ $regex ]] ; then      # Substitute $e{*} variables for any integers
      if [ "$first" -eq 1 ]; then first=0; else printf '\t'; fi
      if [ -e "$arg" ]; then
        # Don't expand files or directories with numeric names
        printf '%s' "$arg"
      else
        _print_path "$relative" "$git_env_char$arg"
      fi
    elif [[ "$arg" =~ ^[0-9]+-[0-9]+$ ]]; then           # Expand ranges into $e{*} variables

      for i in $(eval echo {${arg/-/..}}); do
        if [ "$first" -eq 1 ]; then first=0; else printf '\t'; fi
        _print_path "$relative" "$git_env_char$i"
      done
    else   # Otherwise, treat $arg as a normal string.
      if [ "$first" -eq 1 ]; then first=0; else printf '\t'; fi
      printf '%s' "$arg"
    fi
  done
  IFS="$OLDIFS"
}

# Execute a command with expanded args, e.g. Delete files 6 to 12: $ ge rm 6-12
# Fails if command is a number or range (probably not worth fixing)
exec_scmb_expand_args() {
  eval "$(scmb_expand_args "$@" | sed -e "s/\([][()<>^ \"']\)/"'\\\1/g')"
}

# Updates SCM Breeze from GitHub.
update_scm_breeze() {
  currDir=$PWD
  cd "$scmbDir"
  oldHEAD=$(git rev-parse HEAD 2> /dev/null)
  git pull origin master
  # Reload latest version of '_create_or_patch_scmbrc' function
  source "$scmbDir/lib/scm_breeze.sh"
  _create_or_patch_scmbrc $oldHEAD
  # Reload SCM Breeze
  source "$scmbDir/scm_breeze.sh"
  cd "$currDir"
}

# Create '~/.*.scmbrc' files, or attempt to patch them if passed a previous revision
_create_or_patch_scmbrc() {
  patchfile=$(mktemp -t tmp.XXXXXXXXXX)
  # Process '~/.scmbrc' and '~/.*.scmbrc'
  for prefix in "" "git." "hg."; do
    # Create file from example if it doesn't already exist
    if ! [ -e "$HOME/.$prefix""scmbrc" ]; then
      cp "$scmbDir/$prefix""scmbrc.example" "$HOME/.$prefix""scmbrc"
      printf "== '~/.$prefix""scmbrc' has been created. Please edit this file to change SCM Breeze settings.\n"
    # If file exists, attempt to update it with any new settings
    elif [ -n "$1" ]; then
      # Create diff of example file, substituting example file for user's config.
      git diff $1 "$prefix""scmbrc.example" | sed "s/$prefix""scmbrc.example/.$prefix""scmbrc/g" >| $patchfile
      if [ -s $patchfile ]; then  # If patchfile is not empty
        cd "$HOME"
        # If the patch cannot be applied cleanly, show the updates and tell user to update file manually.
        if ! patch -f "$HOME/.$prefix""scmbrc" $patchfile; then
          printf "== \033[0;31mUpdates could not be applied to '\033[1m~/.$prefix""scmbrc\033[0;31m'.\033[0m\n"
          printf "== Please look at the following changes and manually update '~/.$prefix""scmbrc', if necessary.\n\n"
          cat "$HOME/.$prefix""scmbrc.rej"
        fi
        cd "$scmbDir"
      fi
    fi
  done
}

# Update ~/.scmbrc, ~/.git.scmbrc, etc. from latest commit
alias update_scmbrc_from_latest_commit="_create_or_patch_scmbrc HEAD~"
