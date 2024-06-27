# Use an official Ruby runtime as a parent image
FROM ruby:3.0-slim

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
 && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the Gemfile (and Gemfile.lock if it exists)
COPY Gemfile Gemfile.lock* ./

# Install dependencies including development and test gems
RUN bundle install --jobs 4 --retry 3

# Copy the rest of the app's source code from the host to the image filesystem.
COPY . .

# Ensure the .env file is copied if it exists
COPY .env* ./

# Run the tests
RUN bundle exec rspec

# If tests pass, set the entrypoint
ENTRYPOINT ["ruby", "pr_report.rb"]