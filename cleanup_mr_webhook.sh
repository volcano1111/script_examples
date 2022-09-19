#!/bin/bash

GIT_TOKEN=$( cat .git_token )

get_commit_title() {
  COMMIT_TITLE=$( curl -sH "PRIVATE-TOKEN: $GIT_TOKEN" \
                  "$CI_API_V4_URL/projects/395/repository/commits/$MERGE_COMMIT_SHA" | \
                  jq -r .title )
  COMMIT_SOURCE_BRANCH=$( echo "$COMMIT_TITLE" | cut -d "'" -f 2 )
  COMMIT_TARGET_BRANCH=$( echo "$COMMIT_TITLE" | cut -d "'" -f 4 )
}

run_delete_pipeline() {
  curl -sH "PRIVATE-TOKEN: $GIT_TOKEN" \
       -H "Content-Type: application/json" \
       -d '{ "ref": "testing", "variables": [ {"key": "MR_SOURCE_BRANCH", "value": "'"$MR_SOURCE_BRANCH"'"} ] }' \
       "$CI_API_V4_URL/projects/395/pipeline"
}

if [[ "$REMOVE_SOURCE_BRANCH" = "1" ]]; then
  echo "Source branch is already set for removal so no need to continue running this script. Exiting..."
  exit 1
fi

if [[ "$MERGE_COMMIT_SHA" != "<nil>" ]]; then
  echo "Merge commit is not empty so this MR is merged. Getting commit title..."
  get_commit_title
  if [[ "$MR_SOURCE_BRANCH" = "$COMMIT_SOURCE_BRANCH" && "$MR_TARGET_BRANCH" = "$COMMIT_TARGET_BRANCH" ]]; then
    echo "Source and target branches are matched. Running image delete pipeline for branch $MR_SOURCE_BRANCH"
    run_delete_pipeline
  else
    echo "Source and target branches are not matched. Bye now."
    exit 1
  fi
else
  echo "Merge commit is empty so this MR is closed or deleted. Running image delete pipeline for branch $MR_SOURCE_BRANCH"
  run_delete_pipeline
fi