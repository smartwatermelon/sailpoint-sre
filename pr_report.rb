#!/usr/bin/env ruby
require 'octokit'
require 'date'
require 'optparse'

def load_config(file_path)
  config = {}
  if File.exist?(file_path)
    File.foreach(file_path) do |line|
      line.strip!
      next if line.empty? || line.start_with?('#')
      key, value = line.split('=', 2)
      config[key.strip] = value.strip
    end
  end
  config
end

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby pr_report.rb [options]"
  opts.on('-t', '--token TOKEN', 'GitHub Token') { |v| options[:token] = v }
  opts.on('-r', '--repo REPO', 'GitHub Repository') { |v| options[:repo] = v }
  opts.on('-d', '--days DAYS', Integer, 'Number of days to look back') { |v| options[:days] = v }
  opts.on('-c', '--config FILE', 'Config file path') { |v| options[:config] = v }
end.parse!

# Load config file if specified
config_file = options[:config] || '.env'
file_config = load_config(config_file)

# Configuration with priority order: command line > environment variables > config file
GITHUB_TOKEN = options[:token] || ENV['PR_REPORT_TOKEN'] || file_config['PR_REPORT_TOKEN']
REPO = options[:repo] || ENV['PR_REPORT_REPO'] || file_config['PR_REPORT_REPO']
DAYS_AGO = (options[:days] || ENV['PR_REPORT_DAYS_AGO'] || file_config['PR_REPORT_DAYS_AGO'] || 7).to_i

# Validate required configuration
errors = []
errors << "GitHub token is missing. Please provide it via -t option, PR_REPORT_TOKEN env var, or in config file." if GITHUB_TOKEN.nil?
errors << "GitHub repository is missing. Please provide it via -r option, PR_REPORT_REPO env var, or in config file." if REPO.nil?
errors << "Repository must be in the format 'owner/repo'." if REPO && !REPO.include?('/')

if errors.any?
  puts "Error(s) in configuration:"
  errors.each { |error| puts "- #{error}" }
  exit 1
end

puts "Token: #{GITHUB_TOKEN ? '[REDACTED]' : 'Not set'}"
puts "Repo: #{REPO || 'Not set'}"
puts "Days Ago: #{DAYS_AGO}"

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

puts "Authentication successful. Generating report for #{REPO} for the last #{DAYS_AGO} days..."

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