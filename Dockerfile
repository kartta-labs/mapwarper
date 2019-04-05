#Dockerfile
#2.5
FROM ubuntu:18.04


RUN apt-get update -qq && apt-get install -y build-essential ruby-dev nodejs git libpq-dev postgresql-client ruby-mapscript zlib1g-dev liblzma-dev imagemagick gdal-bin curl gnupg

RUN echo "deb http://packages.cloud.google.com/apt gcsfuse-bionic main" | tee /etc/apt/sources.list.d/gcsfuse.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update -qq && apt-get install -y gcsfuse

#for 18.04 we need to loosen up the imagemagick policy limits
COPY config/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

ENV LISTEN_PORT 3000
EXPOSE 3000

ENV RAILS_ROOT /app

#docker-compose build  --build-arg BUILD_ENV=development web
ARG BUILD_ENV=production
ENV SECRET_KEY_BASE dummytokenforbuild
ENV DB_USER = postgres
ENV DB_PASSWORD = password
ENV DB_NAME = foo
ENV DB_HOST = foo
#ENV DATABASE_URL postgresql:does_not_exist

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY Gemfile  Gemfile
COPY Gemfile.lock Gemfile.lock

RUN gem install bundler -v=1.17.3 


RUN if [ "$BUILD_ENV" = "production" ]; then bundle install --without development test; else bundle install; fi


COPY . .


RUN if [ "$BUILD_ENV" = "production" ]; then bundle exec rake assets:precompile RAILS_ENV=production; fi
