require_relative '../pr_report'
require 'webmock/rspec'

RSpec.describe 'PR Report' do
  before do
    # Stub environment variables
    ENV['PR_REPORT_TOKEN'] = 'fake_token'
    ENV['PR_REPORT_REPO'] = 'fake_owner/fake_repo'
    ENV['PR_REPORT_DAYS_AGO'] = '7'

    # Stub GitHub API calls
    stub_request(:get, "https://api.github.com/repos/fake_owner/fake_repo")
      .to_return(status: 200, body: '{"full_name": "fake_owner/fake_repo"}', headers: {'Content-Type' => 'application/json'})

    stub_request(:get, "https://api.github.com/repos/fake_owner/fake_repo/pulls?state=all")
      .to_return(status: 200, body: [
        {
          "state": "open",
          "title": "Open PR",
          "created_at": (Date.today - 3).iso8601
        },
        {
          "state": "closed",
          "title": "Closed PR",
          "created_at": (Date.today - 5).iso8601,
          "merged_at": nil
        },
        {
          "state": "closed",
          "title": "Merged PR",
          "created_at": (Date.today - 4).iso8601,
          "merged_at": (Date.today - 3).iso8601
        }
      ].to_json, headers: {'Content-Type' => 'application/json'})
  end

  it 'generates a report with correct PR counts' do
    report = generate_report

    expect(report).to include("Opened PRs (1):")
    expect(report).to include("Closed PRs (1):")
    expect(report).to include("Merged PRs (1):")
    expect(report).to include("Total PRs: 3")
  end

  it 'handles rate limiting' do
    allow_any_instance_of(Octokit::Client).to receive(:rate_limit).and_return(
      double(remaining: 0, reset: Time.now.to_i + 60)
    )

    expect { generate_report }.to output(/Rate limit exceeded/).to_stdout
  end

  it 'handles authentication errors' do
    stub_request(:get, "https://api.github.com/repos/fake_owner/fake_repo")
      .to_return(status: 401)

    expect { generate_report }.to raise_error(SystemExit)
      .and output(/Error: The provided GitHub token is invalid or has expired./).to_stdout
  end

  it 'handles repository not found errors' do
    stub_request(:get, "https://api.github.com/repos/fake_owner/fake_repo")
      .to_return(status: 404)

    expect { generate_report }.to raise_error(SystemExit)
      .and output(/Error: The specified repository 'fake_owner\/fake_repo' was not found./).to_stdout
  end
end

def generate_report
  # Capture stdout to a string
  original_stdout = $stdout
  $stdout = StringIO.new
  load 'pr_report.rb'
  output = $stdout.string
  $stdout = original_stdout
  output
end