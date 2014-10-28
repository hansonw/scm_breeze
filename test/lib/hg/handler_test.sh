#!/bin/bash
# Unit tests for hg shell scripts

export scmbDir="$( cd -P "$( dirname "$0" )" && pwd )/../../.."

# Zsh compatibility
if [ -n "${ZSH_VERSION:-}" ]; then shell="zsh"; SHUNIT_PARENT=$0; setopt shwordsplit; fi

# Load test helpers
source "$scmbDir/test/support/test_helper.sh"

# Load functions to test
source "$scmbDir/lib/scm_breeze.sh"
source "$scmbDir/lib/hg/handler.sh"


# Setup and tear down
#-----------------------------------------------------------------------------
oneTimeSetUp() {
  # Test Config
  export hg_env_char="e"
  export hs_max_changes="20"

  testRepo=$(mktemp -d -t scm_breeze.XXXXXXXXXX)
}

oneTimeTearDown() {
  rm -rf "${testRepo}"
}

setupTestRepo() {
  rm -rf "${testRepo}"
  mkdir -p "$testRepo"
  cd "$testRepo"
  hg init > /dev/null
}


#-----------------------------------------------------------------------------
# Unit tests
#-----------------------------------------------------------------------------

test_hg_status_handler() {
  setupTestRepo

  silentHgCommands

  # Set up some modifications
  touch deleted_file
  hg add deleted_file
  hg commit -m "Test commit"
  touch new_file
  touch untracked_file
  hg add new_file
  echo "changed" > new_file
  rm deleted_file

  verboseHgCommands

  # Run command in shell, load output from temp file into variable
  # (This is needed so that env variables are exported in the current shell)
  temp_file=$(mktemp -t scm_breeze.XXXXXXXXXX)
  hg_handler status > $temp_file
  hg_status=$(<$temp_file strip_colors)

  assertIncludes "$hg_status"  "\[1\] A new_file"        || return
  assertIncludes "$hg_status"  "\[2\] ! deleted_file"    || return
  assertIncludes "$hg_status"  "\[3\] \? untracked_file" || return

  # Test that shortcut env variables are set with full path
  local error="Env variable was not set"
  assertEquals "$error" "$testRepo/new_file" "$e1"       || return
  assertEquals "$error" "$testRepo/deleted_file" "$e2"   || return
  assertEquals "$error" "$testRepo/untracked_file" "$e3" || return
}

test_hg_sl_handler() {
  if ! hg help sl > /dev/null 2>&1 ; then
    return
  fi

  setupTestRepo

  silentHgCommands

  # Set up some modifications
  touch a
  hg add a
  hg commit -m "initial commit"
  echo "1" >> a
  hg commit -m "commit 1"
  echo "x" >> a
  hg commit -m "commit 2"
  hg up .^
  echo "y" >> a
  hg commit -m "commit 3"

  verboseHgCommands

  # The output is pretty hard to check; let's just make sure
  # the env variables got matched correctly.
  temp_file=$(mktemp -t scm_breeze.XXXXXXXXXX)
  hg_handler sl > $temp_file

  source "$scmbDir/lib/hg/aliases.sh"
  assertEquals "$(hg log -r 1 -T '{desc}')"   "commit 3"
  assertEquals "$(hg log -r 2 -T '{desc}')"   "commit 2"
  assertEquals "$(hg log -r 3 -T '{desc}')"   "commit 1"
  assertEquals "$(hg log -r 1^ -T '{desc}')"  "commit 1"
  assertEquals "$(hg log -r 1~2 -T '{desc}')" "initial commit"
}


# load and run shUnit2
source "$scmbDir/test/support/shunit2"

