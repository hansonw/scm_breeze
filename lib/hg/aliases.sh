alias hg_aliases="list_aliases hg"

# Remove any existing hg alias or function
unalias hg > /dev/null 2>&1
unset -f hg > /dev/null 2>&1

# Use the full path to hg to avoid infinite loop with hg function
export _hg_cmd="$(\which hg)"

function hg(){
  rm -f `find_in_cwd_or_parent ".hg"`/.sl_sha
  exec_scmb_expand_args "$_hg_cmd" "$@"
}

_alias "$hg_alias" "hg"

_alias "$hg_status_alias"   'hg_handler' 'status'
_alias "$hg_sl_alias"       'hg_handler' 'sl'
