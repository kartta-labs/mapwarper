#Dockerfile
#2.5
FROM ubuntu:18.04

RUN apt-get update -qq && apt-get install -y build-essential ruby-dev nodejs git libpq-dev postgresql-client ruby-mapscript zlib1g-dev liblzma-dev imagemagick gdal-bin

ENV RAILS_ROOT /app

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY Gemfile .

RUN gem install bundler -v=1.17.3

COPY . .

RUN bundle install 

#CMD bundle exec rails s -b '0.0.0.0'