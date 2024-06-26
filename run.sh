#!/usr/bin/env bash

# Collect all environment variables starting with GITHUB_ or PR_REPORT_
env_vars=$(env | grep '^GITHUB_\|^PR_REPORT_' | awk -F= '{print "-e", $1}')

# Use command line arguments if provided, otherwise use environment variables
TOKEN_ARG=${GITHUB_TOKEN:+"--token=$GITHUB_TOKEN"}
REPO_ARG=${GITHUB_REPO:+"--repo=$GITHUB_REPO"}
DAYS_ARG=${DAYS_AGO:+"--days=$DAYS_AGO"}

# Run the Docker container, passing in the environment variables
docker run --rm $env_vars -v "$(pwd)/.env:/app/.env" github-pr-report $TOKEN_ARG $REPO_ARG $DAYS_ARG