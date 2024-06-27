#!/usr/bin/env ruby
require 'octokit'
require 'date'
require 'optparse'
require 'dotenv'

# Load environment variables from .env file
Dotenv.load

class PRReport
  attr_reader :client, :repo, :days_ago

  def initialize(token, repo, days_ago)
    @client = Octokit::Client.new(access_token: token, connection_options: {request: {open_timeout: 5, timeout: 5}})
    @repo = repo
    @days_ago = days_ago.to_i
    @client.auto_paginate = true
    validate_repo
  end

  def generate_report
    verify_repository
    pulls = fetch_pull_requests
    show_progress("Fetching pull requests", pulls.count)
    recent_pulls = filter_recent_pulls(pulls)
    categorized_pulls = categorize_pulls(recent_pulls)
    format_email_report(categorized_pulls)
  end

  private

  def validate_repo
    raise ArgumentError, "Repository must be in the format 'owner/repo'" unless @repo && @repo.include?('/')
  end

  def verify_repository
    show_progress("Verifying repository")
    @client.repository(@repo)
  rescue Octokit::Error => e
    raise "Error verifying repository: #{e.message}"
  end

  def fetch_pull_requests
    show_progress("Fetching pull requests")
    @client.pull_requests(@repo, state: 'all', per_page: 100)
  rescue Octokit::Error => e
    raise "Error fetching pull requests: #{e.message}"
  end

  def filter_recent_pulls(pulls)
    show_progress("Filtering recent pull requests")
    start_date = (Date.today - @days_ago).to_time
    pulls.select { |pr| pr.created_at >= start_date }
  end

  def categorize_pulls(pulls)
    show_progress("Categorizing pull requests")
    {
      opened: pulls.select { |pr| pr.state == 'open' },
      closed: pulls.select { |pr| pr.state == 'closed' && pr.merged_at.nil? },
      merged: pulls.select { |pr| pr.merged_at }
    }
  end

  def format_email_report(categorized_pulls)
    show_progress("Generating report")
    "From: your-email@example.com\n" +
    "To: manager@example.com\n" +
    "Subject: Weekly Pull Request Summary\n" +
    "Date: #{Time.now.strftime('%a, %d %b %Y %H:%M:%S %z')}\n\n" +
    format_report_body(categorized_pulls)
  end

  def format_report_body(categorized_pulls)
    report = "Pull Request Summary for #{@repo} (Last #{@days_ago} #{@days_ago == 1 ? 'day' : 'days'}):\n\n"

    %i[opened closed merged].each do |category|
      prs = categorized_pulls[category]
      report += "#{category.to_s.capitalize} PRs (#{prs.count}):\n"
      prs.each do |pr|
        report += format_pr_details(pr, category)
      end
      report += "\n"
    end

    report += "Total PRs: #{categorized_pulls.values.sum(&:count)}\n"
    report
  end

  def format_pr_details(pr, category)
    submitted_at = pr.created_at.strftime("%Y-%m-%d %H:%M:%S UTC")
    status = case category
             when :opened then "Opened"
             when :closed then "Closed"
             when :merged then "Merged"
             end
    status_date = case category
                  when :opened then submitted_at
                  when :closed then pr.closed_at&.strftime("%Y-%m-%d %H:%M:%S UTC")
                  when :merged then pr.merged_at&.strftime("%Y-%m-%d %H:%M:%S UTC")
                  end
    details = <<~DETAILS
      - Title: #{pr.title}
        Number: ##{pr.number}
        URL: #{pr.html_url}
        Submitter: #{pr.user.name || pr.user.login} (#{pr.user.email || 'Email not available'})
        Submitted at: #{submitted_at}
        Status: #{status} at #{status_date}
    DETAILS
    details += "        Labels: #{pr.labels.map(&:name).join(', ')}\n" if pr.labels.any?
    details += "\n"
    details
  end

  def show_progress(message, count = nil)
    print "#{message}... "
    print "(#{count} found) " if count
    puts "Done!"
  end
end

if __FILE__ == $0
  # Parse command line options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby pr_report.rb [options]"
    opts.on('-t', '--token TOKEN', 'GitHub Token') { |v| options[:token] = v }
    opts.on('-r', '--repo REPO', 'GitHub Repository') { |v| options[:repo] = v }
    opts.on('-d', '--days DAYS', Integer, 'Number of days to look back') { |v| options[:days] = v }
    opts.on('--debug', 'Enable debug output') { |v| options[:debug] = true }
  end.parse!

  # Set configuration values
  token = options[:token] || ENV['PR_REPORT_TOKEN']
  repo = options[:repo] || ENV['PR_REPORT_REPO']
  days_ago = options[:days] || ENV['PR_REPORT_DAYS_AGO'] || 7
  debug = options[:debug]

  # Print debug information if enabled
  if debug
    puts "Debug: Token = #{token ? '[REDACTED]' : 'Not set'}"
    puts "Debug: Repo = #{repo || 'Not set'}"
    puts "Debug: Days ago = #{days_ago}"
  end

  begin
    # Validate inputs
    raise ArgumentError, "GitHub token is required. Set it with --token or in .env file." if token.nil? || token.empty?
    raise ArgumentError, "Repository is required. Set it with --repo or in .env file." if repo.nil? || repo.empty?

    # Generate and print the report
    report = PRReport.new(token, repo, days_ago).generate_report
    puts report

  # Handle various error cases
  rescue Octokit::Unauthorized
    puts "Error: The provided GitHub token is invalid or has expired."
    puts "Please check your token and ensure it has the necessary permissions."
    puts "You can create a new token at: https://github.com/settings/tokens"
    exit 1
  rescue Octokit::NotFound
    puts "Error: The specified repository '#{repo}' was not found."
    puts "Please check the repository name and ensure it's in the format 'owner/repo'."
    puts "Also, verify that your token has access to this repository."
    exit 1
  rescue Octokit::Forbidden
    puts "Error: Access to the repository '#{repo}' is forbidden."
    puts "Please check that your token has the necessary permissions to access this repository."
    puts "For public repositories, you need at least 'public_repo' scope."
    exit 1
  rescue Octokit::TooManyRequests
    puts "Error: GitHub API rate limit exceeded."
    puts "Please wait for a while before trying again, or use a token with higher rate limits."
    exit 1
  rescue Octokit::Error => e
    puts "An error occurred while interacting with the GitHub API: #{e.message}"
    puts "If this persists, please check your token permissions and the repository settings."
    exit 1
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    puts "Network error: Unable to connect to GitHub."
    puts "Please check your internet connection and try again."
    puts "If the problem persists, GitHub may be experiencing issues."
    exit 1
  rescue JSON::ParserError => e
    puts "Error: Received invalid data from GitHub API."
    puts "This could be due to a temporary issue with GitHub's servers."
    puts "Please try again later. If the problem persists, contact GitHub support."
    exit 1
  rescue StandardError => e
    puts "An unexpected error occurred: #{e.message}"
    puts "Please try again. If the problem persists, contact the script maintainer."
    puts e.backtrace if debug
    exit 1
  end
end