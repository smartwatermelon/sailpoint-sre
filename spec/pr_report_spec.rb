require_relative '../pr_report'
require 'webmock/rspec'

RSpec.describe PRReport do
  let(:token) { 'fake_token' }
  let(:repo) { 'fake_owner/fake_repo' }
  let(:days_ago) { 7 }
  let(:pr_report) { PRReport.new(token, repo, days_ago) }

  before do
    stub_request(:get, "https://api.github.com/repos/#{repo}")
      .to_return(status: 200, body: '{"full_name": "fake_owner/fake_repo"}', headers: {'Content-Type' => 'application/json'})

    stub_request(:get, "https://api.github.com/repos/#{repo}/pulls?per_page=100&state=all")
      .to_return(status: 200, body: [
        {
          "number": 1,
          "state": "open",
          "title": "Open PR",
          "html_url": "https://github.com/fake_owner/fake_repo/pull/1",
          "user": {
            "login": "user1",
            "name": "User One",
            "email": "user1@example.com"
          },
          "created_at": (Date.today - 3).iso8601,
          "updated_at": (Date.today - 2).iso8601,
          "closed_at": nil,
          "merged_at": nil,
          "labels": [{"name": "enhancement"}]
        },
        {
          "number": 2,
          "state": "closed",
          "title": "Closed PR",
          "html_url": "https://github.com/fake_owner/fake_repo/pull/2",
          "user": {
            "login": "user2",
            "name": "User Two",
            "email": "user2@example.com"
          },
          "created_at": (Date.today - 5).iso8601,
          "updated_at": (Date.today - 1).iso8601,
          "closed_at": (Date.today - 1).iso8601,
          "merged_at": nil,
          "labels": []
        },
        {
          "number": 3,
          "state": "closed",
          "title": "Merged PR",
          "html_url": "https://github.com/fake_owner/fake_repo/pull/3",
          "user": {
            "login": "user3",
            "name": "User Three",
            "email": "user3@example.com"
          },
          "created_at": (Date.today - 4).iso8601,
          "updated_at": (Date.today - 1).iso8601,
          "closed_at": (Date.today - 1).iso8601,
          "merged_at": (Date.today - 1).iso8601,
          "labels": [{"name": "bug"}, {"name": "priority"}]
        }
      ].to_json, headers: {'Content-Type' => 'application/json'})
  end

  describe '#initialize' do
    it 'raises an error if the repository format is invalid' do
      expect { PRReport.new(token, 'invalid_repo', days_ago) }.to raise_error(ArgumentError)
    end
  end

  describe '#generate_report' do
    let(:report) { pr_report.generate_report }

    it 'generates a report with correct PR counts' do
      expect(report).to include("Opened PRs (1):")
      expect(report).to include("Closed PRs (1):")
      expect(report).to include("Merged PRs (1):")
      expect(report).to include("Total PRs: 3")
    end

    it 'includes detailed information for each PR' do
      expect(report).to include("Title: Open PR")
      expect(report).to include("Number: #1")
      expect(report).to include("URL: https://github.com/fake_owner/fake_repo/pull/1")
      expect(report).to include("Submitter: User One (user1@example.com)")
      expect(report).to include("Status: Opened")
      expect(report).to include("Labels: enhancement")
    end

    it 'shows correct status for closed and merged PRs' do
      expect(report).to include("Status: Closed")
      expect(report).to include("Status: Merged")
    end

  end

  context 'when rate limited' do
    before do
      stub_request(:get, "https://api.github.com/repos/#{repo}")
        .to_return(
          {status: 403, body: '{"message": "API rate limit exceeded"}', headers: {'Content-Type' => 'application/json'}},
          {status: 200, body: '{"full_name": "fake_owner/fake_repo"}', headers: {'Content-Type' => 'application/json'}}
        )
    end

    it 'handles rate limiting' do
      expect { pr_report.generate_report }.to raise_error(RuntimeError, /Error verifying repository/)
    end
  end

  context 'when authentication fails' do
    before do
      stub_request(:get, "https://api.github.com/repos/#{repo}")
        .to_return(status: 401, body: '{"message": "Bad credentials"}', headers: {'Content-Type' => 'application/json'})
    end

    it 'handles authentication errors' do
      expect { pr_report.generate_report }.to raise_error(RuntimeError, /Error verifying repository/)
    end
  end

  context 'when repository is not found' do
    before do
      stub_request(:get, "https://api.github.com/repos/#{repo}")
        .to_return(status: 404, body: '{"message": "Not Found"}', headers: {'Content-Type' => 'application/json'})
    end

    it 'handles repository not found errors' do
      expect { pr_report.generate_report }.to raise_error(RuntimeError, /Error verifying repository/)
    end
  end
end