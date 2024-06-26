# GitHub PR Report Generator

This Docker container generates a report of recent Pull Requests for a specified GitHub repository.

## Prerequisites

- Docker
- GitHub Personal Access Token

## Configuration

You can provide the GitHub token, repository, and number of days to look back in three ways (in order of priority):

1. Command line arguments
2. Environment variables
3. .env file in the same directory as the script

### Command Line Arguments

- `--token` or `-t`: GitHub Token
- `--repo` or `-r`: GitHub Repository (owner/repo)
- `--days` or `-d`: Number of days to look back

### Environment Variables

- `GITHUB_TOKEN` or `PR_REPORT_TOKEN`: GitHub Token
- `GITHUB_REPO` or `PR_REPORT_REPO`: GitHub Repository
- `DAYS_AGO`: Number of days to look back

### .env File

Create a `.env` file in the same directory as the script with the following content:

```
PR_REPORT_TOKEN=your_github_token_here
PR_REPORT_REPO=owner/repo
DAYS_AGO=7
```

## Setup

0. Install Docker:
   ```
   brew install docker --cask
   ```

1. Build the Docker image:
   ```
   docker build -t github-pr-report .
   ```

## Usage

Run the container using the provided script:

```
./run.sh
```

Or run it directly with Docker, providing arguments as needed:

```
docker run --rm -v "$(pwd)/.env:/app/.env" github-pr-report --token=your_token --repo=owner/repo --days=7
```

The report will be printed to the console.
