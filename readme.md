# GitHub PR Report Generator

This Docker container generates a report of recent Pull Requests for a specified GitHub repository.

## Prerequisites

- Docker
- GitHub Personal Access Token

## Configuration

You can provide the GitHub token, repository, and number of days to look back in three ways (in order of priority):

1. Command line arguments
2. Environment variables
3. Config file

### Command Line Arguments

- `--token` or `-t`: GitHub Token
- `--repo` or `-r`: GitHub Repository (owner/repo)
- `--days` or `-d`: Number of days to look back (default: 7)
- `--debug`: Print various debug messages to help with token or repo issues

### Environment Variables

- `PR_REPORT_TOKEN`: GitHub Token
- `PR_REPORT_REPO`: GitHub Repository
- `PR_REPORT_DAYS_AGO`: Number of days to look back (default: 7)

### .env File

Create a `.env` file in the same directory as the script with the following content:

```
PR_REPORT_TOKEN=your_github_token_here
PR_REPORT_REPO=owner/repo
PR_REPORT_DAYS_AGO=7
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
./run.sh [--repo=REPO_NAME] [--token=TOKEN] [--days=DAYS_AGO] [--debug]
```

**The report will be printed to the console.**

## Scheduling with Cron
To schedule the report to run once every 24 hours, you can use Cron. Here's how:

1. Open your terminal and run `crontab -e` to edit your Cron table.
2. Add the following line to schedule the report:
```
5 3 * * * docker run --rm -v "$(pwd)/.env:/app/.env" github-pr-report
```
This will run the container every day at 3:05 a.m., printing the report to the console.

Note: Make sure to adjust the path to your `.env` file and the Docker image name if necessary.

That's it! Your GitHub PR Report Generator is now scheduled to run daily.

## Future Improvements
* The script can take a while to run if there are a lot of PRs to sort through. I'd like to add a progress bar so it's obvious things are still happening.
* The brief for this challenge was to output the report as if in an email, but not actually send it. I would add configuration for email parameters like To, From, and Subject.
* I'd consider integrating with Slack, to send the daily update to a team channel, for example.

## Troubleshooting

If you encounter issues while using the PR Report Generator, here are some common problems and their solutions:

### Authentication and Access Issues

1. **Invalid or Missing Token**
   - Ensure you've provided a valid GitHub token.
   - Check that the token hasn't expired.
   - Verify the token has the necessary permissions (at least `repo` or `public_repo`).

2. **Repository Not Found or Access Denied**
   - Confirm the repository name is correct and in the format `owner/repo`.
   - Ensure your token has access to the specified repository.
   - For private repositories, verify your token has the `repo` scope.

### Data and Rate Limiting Issues

3. **No PRs Within Day Limit**
   - Verify that the repository has recent PR activity.
   - Try increasing the `--days` parameter.

4. **Rate Limit Exceeded**
   - Wait for the rate limit to reset (usually 1 hour).
   - Use a personal access token instead of unauthenticated access.
   - For high-volume use, consider using a GitHub Apps token with higher rate limits.

5. **Large Repository Performance**
   - For repositories with many PRs, try reducing the time range.
   - Be patient, as processing may take longer for larger datasets.

### Network and Environment Issues

6. **Network Connectivity Problems**
   - Check your internet connection.
   - Verify any firewall or proxy settings aren't blocking access to GitHub.
   - Ensure GitHub is accessible from your network.

7. **Timezone Discrepancies**
   - The script uses your system's timezone. Ensure it's set correctly.
   - You can check your system time and timezone settings if dates seem off.

### Docker and Dependency Issues

8. **Docker Build or Run Failures**
   - Ensure Docker is installed and running correctly.
   - Try rebuilding the image: `docker build -t github-pr-report .`
   - Check Docker logs: `docker logs <container_id>`

9. **Gem Installation Problems**
   - If running outside Docker, ensure you have Ruby and Bundler installed.
   - Try updating gems: `bundle update`

### Debugging

10. **Using Debug Mode**
    - Run the script with `--debug` for more detailed output.
    - This can help identify issues with API calls or data processing.

### Staying Updated

11. **API Changes or Script Outdated**
    - Ensure you're using the latest version of the script.
    - Check for updates to the Octokit gem: `bundle update octokit`

If you continue to experience issues after trying these solutions, please open an issue on the GitHub repository with details about the problem and any error messages you've received.
