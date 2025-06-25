ARG RUBY_BASE_IMAGE=ruby:3.4.1-alpine
ARG GEM_CACHE_IMAGE=${RUBY_BASE_IMAGE}

# base image
FROM ${RUBY_BASE_IMAGE} AS base
RUN apk add --update sqlite-dev openssl-dev tzdata bash curl zip git
RUN apk add --update build-base
RUN gem install bundler:2.6.9

# gem cache
FROM ${GEM_CACHE_IMAGE} AS gem-cache
RUN mkdir -p /usr/local/bundle

FROM base AS gems
COPY --from=gem-cache /usr/local/bundle /usr/local/bundle
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=4 --retry=5

# Final backend image
FROM base AS deploy

RUN adduser -D app
RUN chown app:app /home/app
WORKDIR /home/app
USER app

RUN mkdir -p /tmp
COPY --from=gems --chown=app:app /usr/local/bundle /usr/local/bundle

EXPOSE 1234

CMD ["bundle", "exec", "tp2", "."]
