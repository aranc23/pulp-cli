#!/bin/bash

# shellcheck source=tests/scripts/config.source
. "$(dirname "$(dirname "$(realpath "$0")")")"/config.source

pulp debug has-plugin --name "file" --min-version "1.10.0.dev" || exit 3

acs_remote="cli_test_file_acs_remote"
acs="cli_test_acs"

cleanup() {
  pulp file acs destroy --name $acs || true
  pulp file remote destroy --name $acs_remote || true
  pulp file repository destroy --name "cli-repo-manifest-only" || true
  pulp file remote destroy --name "cli-remote-manifest-only" || true
}
trap cleanup EXIT

cleanup

expect_succ pulp file remote create --name $acs_remote --url "$PULP_FIXTURES_URL" --policy "on_demand"

expect_succ pulp file acs create --name $acs --remote $acs_remote --path "file/PULP_MANIFEST" --path "file2/PULP_MANIFEST"
expect_succ pulp file acs list
test "$(echo "$OUTPUT" | jq -r length)" -ge 1
expect_succ pulp file acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 2

# manipulate paths
expect_succ pulp file acs path add --name $acs --path "file-invalid/PULP_MANIFEST"
expect_succ pulp file acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 3
expect_succ pulp file acs path remove --name $acs --path "file-invalid/PULP_MANIFEST"
expect_succ pulp file acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 2

# test refresh
expect_succ pulp file acs refresh --name $acs
task_group=$(echo "$ERROUTPUT" | grep -E -o "${PULP_API_ROOT}api/v3/task-groups/[-[:xdigit:]]*/")
expect_succ pulp task-group show --href "$task_group"
test "$(echo "$OUTPUT" | jq ".tasks | length")" -eq 2

# create a remote with manifest only and sync it
expect_succ pulp file remote create --name "cli-remote-manifest-only" --url "$PULP_FIXTURES_URL/file-manifest/PULP_MANIFEST"
remote_href="$(echo "$OUTPUT" | jq -r ".pulp_href")"
expect_succ pulp file repository create --name "cli-repo-manifest-only" --remote "$remote_href"
expect_succ pulp file repository sync --name "cli-repo-manifest-only"

# test refresh with bad paths
expect_succ pulp file acs path add --name $acs --path "bad-path/PULP_MANIFEST"
expect_fail pulp file acs refresh --name $acs

expect_succ pulp file acs destroy --name $acs
