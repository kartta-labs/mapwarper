#Dockerfile
#2.5
FROM ubuntu:18.04

RUN apt-get update -qq && apt-get install -y build-essential ruby-dev nodejs git libpq-dev postgresql-client ruby-mapscript zlib1g-dev liblzma-dev imagemagick gdal-bin

ENV RAILS_ROOT /app

#docker-compose build  --build-arg BUILD_ENV=development web
ARG BUILD_ENV=production
ENV SECRET_KEY_BASE dummytokenforbuild
ENV DATABASE_URL postgresql:does_not_exist

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN gem install bundler -v=1.17.3 

COPY . .


RUN if [ "$BUILD_ENV" = "production" ]; then bundle install --without development test; else bundle install; fi

RUN if [ "$BUILD_ENV" = "production" ]; then bundle exec rake assets:precompile RAILS_ENV=production; fi
