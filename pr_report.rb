#!/usr/bin/env ruby
require 'octokit'
require 'date'
require 'optparse'
require 'faraday'

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
  opts.on('--debug', 'Enable debug output') { |v| options[:debug] = true }
end.parse!

DEBUG = options[:debug]

# Load config file if specified
config_file = options[:config] || '.env'
file_config = load_config(config_file)

puts "Loaded config from file: #{config_file}" if DEBUG
puts "File config: #{file_config}" if DEBUG

# Configuration with priority order: command line > environment variables > config file
GITHUB_TOKEN = options[:token] || ENV['PR_REPORT_TOKEN'] || file_config['PR_REPORT_TOKEN']
REPO = options[:repo] || ENV['PR_REPORT_REPO'] || file_config['PR_REPORT_REPO']
DAYS_AGO = (options[:days] || ENV['PR_REPORT_DAYS_AGO'] || file_config['PR_REPORT_DAYS_AGO'] || 7).to_i

if DEBUG
  puts "Configuration sources:"
  puts "  Command line options: #{options}"
  puts "  Environment variables: PR_REPORT_TOKEN=#{ENV['PR_REPORT_TOKEN'] ? '[REDACTED]' : 'Not set'}, PR_REPORT_REPO=#{ENV['PR_REPORT_REPO']}, PR_REPORT_DAYS_AGO=#{ENV['PR_REPORT_DAYS_AGO']}"
  puts "  File config: #{file_config}"
  puts "\nFinal configuration:"
  puts "  GITHUB_TOKEN: #{GITHUB_TOKEN ? '[REDACTED]' : 'Not set'}"
  puts "  REPO: #{REPO || 'Not set'}"
  puts "  DAYS_AGO: #{DAYS_AGO}"
end

# Validate required configuration
errors = []
errors << "GitHub token is missing. Please provide it via --token option, PR_REPORT_TOKEN env var, or in config file." if GITHUB_TOKEN.nil?
errors << "GitHub repository is missing. Please provide it via --repo option, PR_REPORT_REPO env var, or in config file." if REPO.nil?
errors << "Repository must be in the format 'owner/repo'." if REPO && !REPO.include?('/')

if errors.any?
  puts "Error(s) in configuration:"
  errors.each { |error| puts "- #{error}" }
  exit 1
end

# Initialize GitHub client with retry logic
client = Octokit::Client.new(access_token: GITHUB_TOKEN, connection_options: {request: {open_timeout: 1, timeout: 1}})
client.auto_paginate = true  # Ensure we get all results

def handle_rate_limit(client)
  rate_limit = client.rate_limit
  if rate_limit.remaining == 0
    reset_time = Time.at(rate_limit.reset)
    sleep_time = [rate_limit.reset - Time.now.to_i, 0].max
    puts "Rate limit exceeded. Waiting for #{sleep_time} seconds until #{reset_time}."
    sleep(sleep_time)
  end
end

begin
  # Verify the token and repository
  repo_info = client.repository(REPO)
  puts "Successfully connected to repository: #{repo_info.full_name}" if DEBUG

  # Get pull requests from the specified time range
  start_date = (Date.today - DAYS_AGO).to_time
  pulls = []
  
  begin
    handle_rate_limit(client)
    pulls = client.pull_requests(REPO, state: 'all')
  rescue Octokit::TooManyRequests
    handle_rate_limit(client)
    retry
  end

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

rescue Octokit::Unauthorized
  puts "Error: The provided GitHub token is invalid or lacks necessary permissions."
  exit 1
rescue Octokit::NotFound
  puts "Error: The specified repository '#{REPO}' was not found or is not accessible with the provided token."
  exit 1
rescue Octokit::TooManyRequests
  puts "Error: GitHub API rate limit exceeded. Please wait and try again later."
  exit 1
rescue Octokit::Error => e
  puts "An error occurred while interacting with the GitHub API: #{e.message}"
  exit 1
rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
  puts "Network error: Unable to connect to GitHub. Please check your internet connection and try again."
  puts "Error details: #{e.message}"
  exit 1
rescue JSON::ParserError => e
  puts "Error: Received invalid data from GitHub API. The response couldn't be parsed."
  puts "Error details: #{e.message}"
  exit 1
rescue StandardError => e
  puts "An unexpected error occurred: #{e.message}"
  puts e.backtrace if DEBUG
  exit 1
end
