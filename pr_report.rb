#!/usr/bin/env ruby
# pr_report.rb
require 'octokit'
require 'date'
require 'optparse'
require 'dotenv'
require 'io/console'

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

# Validate and prompt for required configuration
if GITHUB_TOKEN.nil?
  print "GitHub token not found. Please enter your GitHub token: "
  GITHUB_TOKEN = STDIN.noecho(&:gets).chomp
  puts # Add a newline after hidden input
end

if REPO.nil?
  print "GitHub repository not specified. Please enter the repository (owner/repo): "
  REPO = gets.chomp
end

# Validate the input
if GITHUB_TOKEN.empty? || REPO.empty?
  puts "Error: GitHub token and repository must be provided."
  exit 1
end

# Validate repository format
unless REPO.include?('/')
  puts "Error: Repository must be in the format 'owner/repo'."
  exit 1
end

# Initialize GitHub client
client = Octokit::Client.new(access_token: GITHUB_TOKEN)

# Verify the token and repository
begin
  client.repository(REPO)
rescue Octokit::Unauthorized
  puts "Error: The provided GitHub token is invalid or lacks necessary permissions."
  exit 1
rescue Octokit::NotFound
  puts "Error: The specified repository '#{REPO}' was not found or is not accessible with the provided token."
  exit 1
end

puts "Authentication successful. Generating report for #{REPO}..."

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