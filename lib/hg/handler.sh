hg_handler() {
  CMD=$1
  shift
  fail_if_not_hg_repo || return 1
  zsh_compat # Ensure shwordsplit is on for zsh
  # Run ruby script, store output
  cmd_output=`/usr/bin/env ruby "$scmbDir/lib/hg/${CMD}_handler.rb" $@`
  code=$?
  if [ $code -ne 0 ]; then
    # silently fall back
    hg $CMD $@
    return 1
  fi
  # Print debug information if $scmbDebug = "true"
  if [ "${scmbDebug:-}" = "true" ]; then
    printf "${CMD}_handler.rb output => \n$cmd_output\n------------------------\n"
  fi
  if [[ -z "$cmd_output" ]]; then
    # Just show regular hg command if ruby script returns nothing.
    hg $CMD $@
    echo -e "\n\033[33mThere were more than $hs_max_changes changed files. SCM Breeze has fallen back to standard \`hg status\` for performance reasons.\033[0m"
    return 1
  fi
  # Fetch list of files from last line of script output
  files="$(echo "$cmd_output" | \grep '@@filelist@@::' | sed 's%@@filelist@@::%%g')"
  if [ "${scmbDebug:-}" = "true" ]; then echo "filelist => $files"; fi
  # Export numbered env variables for each file
  IFS="|"
  local e=1
  for file in $files; do
    export $hg_env_char$e="$file"
    if [ "${scmbDebug:-}" = "true" ]; then echo "Set \$$hg_env_char$e  => $file"; fi
    let e++
  done
  IFS=$' \t\n'

  if [ "${scmbDebug:-}" = "true" ]; then echo "------------------------"; fi
  # Print status
  echo "$cmd_output" | \grep -v '@@filelist@@::'
  zsh_reset # Reset zsh environment to default
}
