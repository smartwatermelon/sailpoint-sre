#!/usr/bin/env ruby
# pr_report.rb
require 'octokit'
require 'date'
require 'optparse'
require 'dotenv'

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby pr_report.rb [options]"
  opts.on('-t', '--token TOKEN', 'GitHub Token') { |v| options[:token] = v }
  opts.on('-r', '--repo REPO', 'GitHub Repository') { |v| options[:repo] = v }
  opts.on('-d', '--days DAYS', Integer, 'Number of days to look back') { |v| options[:days] = v }
end.parse!

# Load .env file if it exists
Dotenv.load('.env')

# Configuration with priority order
GITHUB_TOKEN = options[:token] || ENV['PR_REPORT_TOKEN']
REPO = options[:repo] || ENV['PR_REPORT_REPO']
DAYS_AGO = options[:days] || (ENV['PR_REPORT_DAYS_AGO'] || 7).to_i

# Validate required configuration
if GITHUB_TOKEN.nil? || REPO.nil?
  puts "Error: GitHub token and repository must be provided."
  puts "You can set them using command line options, environment variables, or a .env file."
  exit 1
end

# Initialize GitHub client
client = Octokit::Client.new(access_token: GITHUB_TOKEN)

# Get pull requests from the specified time range
start_date = (Date.today - DAYS_AGO).to_time
pulls = client.pull_requests(REPO, state: 'all')
recent_pulls = pulls.select { |pr| pr.created_at >= start_date }

# Categorize pull requests
opened = recent_pulls.select { |pr| pr.state == 'open' }
closed = recent_pulls.select { |pr| pr.state == 'closed' && pr.merged_at.nil? }
merged = recent_pulls.select { |pr| pr.merged_at }

# Generate report
report = <<~EMAIL
From: pr-report@example.com
To: manager@example.com
Subject: Pull Request Summary for #{REPO} (Last #{DAYS_AGO} Days)

Hello,

Here's a summary of pull request activity in the #{REPO} repository for the past #{DAYS_AGO} days:

Opened PRs (#{opened.count}):
#{opened.map { |pr| "- #{pr.title}" }.join("\n")}

Closed PRs (#{closed.count}):
#{closed.map { |pr| "- #{pr.title}" }.join("\n")}

Merged PRs (#{merged.count}):
#{merged.map { |pr| "- #{pr.title}" }.join("\n")}

Total PRs: #{recent_pulls.count}

Best regards,
Your GitHub Reporter
EMAIL

# Print the report
puts report