FROM ruby:4.0-slim AS base
WORKDIR /syntropy
RUN apt-get update -qq && apt-get install -y \
    curl \
    build-essential \
    libpq-dev \
    libsqlite3-dev \
    libssl-dev \
    libyaml-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle"
COPY Gemfile Gemfile.lock ./
RUN bundle install

RUN groupadd --system --gid 1000 syntropy && \
    useradd syntropy --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

EXPOSE 1234

# Start the main process
# CMD ["bash"]
CMD ["bundle", "exec", "syntropy", "serve"]
