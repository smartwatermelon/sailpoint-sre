#!/usr/bin/env bash

# Use command line arguments if provided, otherwise use environment variables
TOKEN_ARG=${GITHUB_TOKEN:+"--token=$GITHUB_TOKEN"}
REPO_ARG=${GITHUB_REPO:+"--repo=$GITHUB_REPO"}
DAYS_ARG=${DAYS_AGO:+"--days=$DAYS_AGO"}

docker run --rm -v "$(pwd)/.env:/app/.env" github-pr-report $TOKEN_ARG $REPO_ARG $DAYS_ARG