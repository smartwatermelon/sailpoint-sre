FROM ruby:3.0-slim

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY pr_report.rb .env ./

ENTRYPOINT ["ruby", "pr_report.rb"]