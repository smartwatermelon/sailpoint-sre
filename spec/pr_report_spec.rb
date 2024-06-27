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

  describe '#initialize' do
    it 'raises an error if the repository format is invalid' do
      expect { PRReport.new(token, 'invalid_repo', days_ago) }.to raise_error(ArgumentError)
    end
  end

  describe '#generate_report' do
    it 'generates a report with correct PR counts' do
      report = pr_report.generate_report
      expect(report[:opened].count).to eq(1)
      expect(report[:closed].count).to eq(1)
      expect(report[:merged].count).to eq(1)
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