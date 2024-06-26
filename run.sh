#!/usr/bin/env bash -ex

# Initialize variables
TOKEN=""
REPO=""
DAYS=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --token=*)
      TOKEN="${1#*=}"
      shift
      ;;
    --repo=*)
      REPO="${1#*=}"
      shift
      ;;
    --days=*)
      DAYS="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Set arguments based on priority: command line > environment variables
TOKEN_ARG=${TOKEN:+"--token=$TOKEN"}
TOKEN_ARG=${TOKEN_ARG:-${PR_REPORT_TOKEN:+"--token=$PR_REPORT_TOKEN"}}

REPO_ARG=${REPO:+"--repo=$REPO"}
REPO_ARG=${REPO_ARG:-${PR_REPORT_REPO:+"--repo=$PR_REPORT_REPO"}}

DAYS_ARG=${DAYS:+"--days=$DAYS"}
DAYS_ARG=${DAYS_ARG:-${PR_REPORT_DAYS_AGO:+"--days=$PR_REPORT_DAYS_AGO"}}

# Run the Docker container
docker run --rm -e PR_REPORT_TOKEN -e PR_REPORT_REPO -e PR_REPORT_DAYS_AGO -v "$(pwd)/.env:/app/.env" github-pr-report $TOKEN_ARG $REPO_ARG $DAYS_ARG