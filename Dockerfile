# Use an official Ruby runtime as a parent image
FROM ruby:3.0-slim

# Set the working directory in the container
WORKDIR /app

# Copy the Gemfile and Gemfile.lock (if it exists)
COPY Gemfile Gemfile.lock* ./

# Install any needed packages specified in Gemfile
RUN bundle install

# Copy the rest of the app's source code from your host to the image filesystem.
COPY pr_report.rb .env* ./

# Run the script when the container launches
ENTRYPOINT ["ruby", "pr_report.rb"]