#!/usr/bin/env bash

# Collect all environment variables starting with PR_REPORT_
env_vars=$(env | grep '^PR_REPORT_' | awk -F= '{print "-e", $1}')

# Use command line arguments if provided, otherwise use environment variables
TOKEN_ARG=${PR_REPORT_DAYS_AGO:+"--token=$PR_REPORT_DAYS_AGO"}
REPO_ARG=${PR_REPORT_REPO:+"--repo=$PR_REPORT_REPO"}
DAYS_ARG=${PR_REPORT_DAYS_AGO:+"--days=$PR_REPORT_DAYS_AGO"}

# Run the Docker container, passing in the environment variables
docker run --rm $env_vars -v "$(pwd)/.env:/app/.env" github-pr-report $TOKEN_ARG $REPO_ARG $DAYS_ARG