# Mapwarper - Kartta Labs

## This Document

This document aims to provide an overview of the mapwarper documentation with regards to Kartta Labs 

See Also:
* [Project Setup on GCP](/project_setup.md) for documentation about Google Cloud Platform 
* [Mapwarper Kubernetes](/Mapwarper_kubernetes.md) for docs about Google Kubernetes Engine and Kubernetes in general.  

## Table of Contents

* [Overview](#overview)
* [Plan](#plan)
* [Code](#code)
  * [Configuration](#configuration)
* [API Documentation](#api-documentation)
* [User Documentation](#user-documentation)
  * [Admin](#admin)
* [Development](#development)
  * [Local](#local)
  * [Docker Compose](#docker-compose)


## Overview

This is a web application to georeference and stitch together imagery. The Mapwarper application is a customized version of https://github.com/timwaters/mapwarper - the public instance of which can be visited at [Mapwarper.net](https://mapwarper.net).  It's in use at the New York Public Library, Harvard University, Leiden Archives amongst other instances. 

![Main Rectify Interface](mapwarper_warp_screenshot.png "Main Rectify Interface")

It enables a user to upload an image, a scanned map or aerial photo for example, and by placing control points on a reference map and the image, to warp it, to stretch it to fit. 

Users rectify, warp or stretch images of historical maps with a reference basemap, assigning locations on image and map that line up with each other. Often these historical maps were in big paper books, and so for the first time they can be stitched together and shown as a whole, in digital format.

Users can crop around the maps, and join or stitch them together into mosaics 

The application runs as a Ruby on Rails application using a number of open source geospatial libraries and technologies, including PostGIS, Mapserver, Geoserver, and GDAL tools.

The resulting maps can be exported as a PNG, GeoTIFF, WMS, Tiles, and KML for use in many different applications.


### Configuration

There are several configuration settings. Most of these are set in `config/application.yml` and are various API keys. See below for more explanation.

Some of the important ones include `google_storage_enabled`, `google_storage_project` and `google_storage_bucket` which are used when storing thumbnails to a google storage bucket.

The `config/initializers/application_config.rb` file also configures sending email via sendmail or Sendgrid.

We will see later how Kubernetes sets the config variables to overwrite these settings where necessary as we shouldn't keep API keys etc in the docker images. 

#### config/application.yml

Listing the configuration variables and short explanations.

    email: example_user@example.com
  Used as the "from" / sender email address 

    addthis_twitter_user: mapwarper
    addthis_user: example_user

  Addthis addthis.com adds social sharing buttons. Twitter user is the twitter account that you want the tweet to come from. Addthis_user is the addthis id of your addthis account.

    google_analytics_code:

  If you use Google Analytics, this is where to put the ID. e.g. "UA-18749303-1"

    src_maps_dir: 
    dst_maps_dir: 
    map_mask_dir: 
    tileindex_dir: 

Directories to store converted source images, warped images, masking files and tileindex files.  These directories can be empty for development as they default to "public/mapimages/" 

  
    host: "localhost:3000"

  The default host used in the application and in emails for generated links. 

    site_name: "MapWarper"
  `site_name` is used in emails and any tilejson files as the name of the site. 

    host_with_scheme: "http://localhost:3000"
Used in tilejson files and in the publish feature to reference the application as a tileserver
  
    omniauth_google_key: ""
    omniauth_google_secret: ""

This key (id) and secret is set up to allow login via OAuth into the site. Get your API key at: https://code.google.com/apis/console/ 
  
    mapbox_access_token: ""

  The API token for the mapbox satellite layer

    import_maps_sftp_path: "/home/sftpuser/maps"

  Used for admin imports of maps. The absolute path on the server which contains images to be imported.

    gdal_memory_limit: ""

  For machines with limited RAM you can limit the amount of memory that GDAL uses by setting this.  Amount in mb. See https://gdal.org/programs/gdalwarp.html#cmdoption-gdalwarp-wm

    disabled_site: false

  Set to `true` to disable logins for normal users. Only users with the administrator role or the "trusted" role can login. 

    google_storage_enabled: false

  Set to `true` to store image thumbnails on Google Cloud Storage bucket 

    google_json_key_location: ""

  Absolute path to the Service Account JSON file used for storage and other Google Cloud access

    google_storage_project: ""
    google_storage_bucket: ""

Project name and bucket for storage of thumbnails. `google_storage_project` is also used in a couple of other places, for cloud vision and google_tiles_bucket (see below) Bucket names should be globally unique

    public_shared_dir: "" 
    
  used when saving to a shared directory (e.g. shared_uploads_dir: "shared" for RAILS_ROOT/public/shared/ which can be mounted as a volume via k8s ) 
  
    debug_k8s: false

  Set to true to show pod name in the top left of the page

    google_maps_key: ""

  Used as API key for geocoding portion of the OCR job. And if set with `enable_google_satellite` will enable the google satellite layer. 

    enable_google_satellite: false
 
  Set to true to enable the satellite layer. Performance is currently poor though so I'd recommend leaving this off.

    sendgrid_api_key: ""

  API Key for sendgrid email authentication. You can alternatively use SMTP (see below). If no email configs are set, the application will try to send email via sendmail on the local machine. 

    enable_throttling: "false"

  Enables the Rack::Attack throttle middleware layer. This limits the number of requests for things like adding and deleting points. 


    throttle_limit: 30
    throttle_period: 60

Limit and period for the throttling. E.g. 30 requests in a 60 second window.


    throttle_safelist_ips: #"127.0.0.1,192.168.0.1" 

Whitelist IPs, comma separated list. So that you can put your own IP Address, or the load balancers addresses here. 

    google_tiles_bucket: ""

  Bucket name for storing published tiles to (via tilestashe).

    cdn_tiles_host:  ""  #e.g. https://tiles.example.com

  Optional domain for a configured loadbalanced endpoint for the published tiles to be served from, used in TileJSON files and displayed on the export tab for maps and layers. If set blank then the normal cloudstorage URL https://storage.googleapis.com/ will be used instead.

    smtp_address: 
    smtp_port:
    smtp_username:
    smtp_password:

  Optional SMTP settings for email to be used if Sendgrid isn't enabled

    enable_ocr_job: "false"  
    
  Set to "true" to enable the OCR and geocoding job upon map creation

    ocr_bucket: "" 
    
  Name of the bucket to store images for OCR processing, should be globablly unique


## API Documentation

The API documentation might be used as a starting point to understanding the features of the application 

[README_API.md](README_API.md)

This is also exposed at the `{url}/api/v1` url  (e.g. https://mapwarper.net/api/v1)

## User Documentation

For general user doc and tutorials, list urls of tutorials and videos in this section.

### Admin

There are a number of specific admin features and command line rake tasks for mapwarper.

#### Imports

Imports of maps can be performed by adding image files to a specified directory and uploading a CSV file with the metadata. First the import is created, then run.
Afterwards the maps of the import can be viewed. Deleted imports do not delete either the maps or the layer. All the maps within an import can be assigned to one or more layers. (Note that this process is different than importing the NYPL images and metadata, see below)

#### Bulk Points Import

A user can import a csv of points for maps they own, but an admin user can import points for multiple maps at once. The CSV should have the id of the map as a column (see api docs)

#### User Management

Admins can disable users, delete users (including maps they have uploaded), reset passwords, and change roles for a user. The admin user can also confirm a user's email where a user would normally click a link in their email.  

#### User Roles

* Super User
  * Able to change users
* Admin User
  * Most admin tasks (except changing users)
* Editor User
  * Able to change maps of other users
* Trusted User
  * Able to log in to the site if global site logins are disabled
* Developer
  * Not used

#### User Statistics

At the `/users/stats` endpoint the admin user can view simple statistics of users showing data such as number of points made, total changes etc

#### rake tasks

Rake tasks are command line scripts that run from the application route. Run `rake -T` to list them all. In particular the following are worth noting

* Set superuser (useful if using oauth / provider login)
  * Sets an existing user to have the super user and administrator roles. Run `rake warper:set_superuser EMAIL=email@example.com` where the `EMAIL`  variable is set to be the email of an already existing user. 
* Create superuser (if using email and password logins)
  * If using emails and passwords: creates a new super user, used once just after creating a new database. Run `rake warper:create_superuser` and make note of the password created. You'd then log in with `super@example.com` with that password and give other user the super user role. Ideally you would then disable this initial super user. 
* Migrate database
  * Migrates the database and deploys new migrations. Run after deploying new code which contains migrations. `rake db:migrate` With Kubernetes this is wrapped in the migration Job.
* Import NYPL
  * Imports the NYPL metadata and images. Needs paths to the metadata and images in directory. Can pass in MAX_MAPS_COUNT to limit the number of maps to be imported. GDAL_CACHE_MAX might make a difference in image performance. Takes about 50 seconds per map to import.
  Example call: `rake warper:import_nypl NYPL_METADATA_FILE=/path/to/metadata.json NYPL_MAPS_DIR=/path/to/maps MAX_MAPS_COUNT=5 GDAL_CACHE_MAX=200`  With Kubernetes this is accessed with the privileged Deployment





## Development

### Local

It's recommended to use Docker for development, but it's possible to get started with developing in a local environment on Ubuntu 16.04 or 18.04 if you are familiar with Ruby on Rails. It will be quicker to run the test suite and develop if it's running natively. Please consult the Readmes and the Dockerfile for the list of packages you'd need to install. A developer will usually want to install the Ruby version using rvm. Using 16.04 GDAL needs to be recompiled to include a fix with overviews and ruby mapscript need to be compiled to work with rubies in rvm. For 18.04 only the ruby mapscript needs to be compiled.  

#### Prerequisites
For an introduction to Ruby on Rails in general, the official documentation should be your go to source: https://guides.rubyonrails.org/v4.2/getting_started.html

There may also be a pre-requisite to be familiar with some basic GIS terminology at least, and basic introductory familiarity with spatial databases like PostGIS, basic familiarity with some of the GDAL utilities and basics of web mapping technologies. Additionally using and configuring Docker and Docker Compose for local developer could be a good idea.   

#### Compile Mapscript

If using rvm, the ruby mapserver library needs to be compiled and copied or linked. This doesn't take long to compile.

First enable sources for apt

```
deb http://archive.ubuntu.com/ubuntu/ xenial universe
deb-src http://archive.ubuntu.com/ubuntu/ xenial universe
```

Next update and install the dependencies for compiling the library

```
sudo apt-get update
sudo apt-get build-dep libmapserver2
```

Next install the ruby version and make sure it's enabled so that the rvm Ruby version will be used at compile time

```
rvm install 2.4.0 --enable-shared 
source ~/.rvm/scripts/rvm
rvm use 2.4.0
```

Next get the mapserver source and compile 

```
mkdir ~/mapserver_install
git clone https://github.com/timwaters/mapserver.git
cd mapserver
git checkout tags/rel-7-0-0
mkdir build
cd build

cmake .. -DWITH_THREAD_SAFETY=1 -DWITH_FCGI=0 -DWITH_RUBY=1 -DCMAKE_INSTALL_PREFIX=~/mapserver_install -DWITH_GIF=0
make
```
Then copy the `mapscript.so` file to the rvm library path. 

```
cp mapscript/ruby/mapscript.so  ~/.rvm/rubies/ruby-2.4.0/lib/ruby/vendor_ruby/2.4.0/x86_64-linux/
```


#### GDAL
Not necessary for 18.04. Only for 16.04 compile the GDAL utilities:

```
mkdir ~/gdal_install
git clone https://github.com/OSGeo/gdal.git
cd gdal
git checkout tags/2.2.2
cd gdal
./configure --prefix=~/gdal_install --disable-shared --enable-static --with-libtiff --with-geotiff --with-jpeg --with-geos --without-pg --without-mysql --without-netcdf --without-pcidsk --without-python --without-php --without-java --without-sde --without-spatialite 
make install
cd ~/gdal_install
./bin/gdalinfo --version
```
You can then move the binaries as you like. Copy the path to the binaries and use in the  `gdal_path` configuration variable in `application.yml` 


### Docker Compose

Its probably going to be much easier to get started with local development using Docker and Docker Compose. Looking in the `docker-compose.yml` file you can see three services, db, redis and web. The db image is the PostGIS database image, the redis image is for the redis cache and the web image is for the main mapwarper Rails application.  

The commented out SYS_ADMIN capability and privileged mode is for local dev of mounting a Google Storage bucket via gcsfuse, and can be uncommented for development on this feature locally using docker compose. 

First, set up and configure the `config/application.yml`, `config/secrets.yml` and `config/database.yml` files as necessary. To get started you can just copy them across from their .example files. There is also a script in `lib/cloudbuild/copy_configs.sh` to do this for you. 

If you are going to run tests, you will need to manually edit the `config/database.yml` file to ensure the test section is as follows:

```
test:
  adapter: postgis
  database: mapwarper_test
  host: localhost
  username: postgres
  password:
```

Docker-compose uses the .env file for environment variables, So we can change the .env file to be used in development mode. Copy `.env.example`  to  `.env ` and edit as appropriate.
```
RAILS_ENV=development
RACK_ENV=development
SECRET_KEY_BASE=youshouldsetthis
REDIS_URL=redis://redis:6379/0
BUNDLE_APP_CONFIG: /app/.bundle
DATABASE_URL=postgis://db/mapwarper_development?pool=5
```

If you are running docker-compose in production you should change the value of `MAGICK_MEMORY_LIMIT` and `MAGICK_MAP_LIMIT` to fit your resources. These limit the available RAM to the imagemagick processes. Imagemagick tries to process the image in memory. If it exceeds these limits the imagemagick process will cache to disk and so the process will take longer but will not take up RAM. Imagemagick processes uploaded images into thumbnails, and (if the feature is enabled) converts the image to a suitable format for the OCR Job. You ca also limit the gdal_warp process. The gdalwarp process rectifies the map image and you can limit the amount of RAM for this process by setting the `gdal_memory_limit` value in the application.yml file. Set the number as mb e.g. `gdal_memory_limit: 1000` 

Build the image: docker-compose is set up for production but you can use it in development by passing in the build arg and setting the correct environment variables.  If you look in the `Dockerfile` you will see that the default BUILD_ENV of production installs gems without the development and test gems and also precompile the assets. 

```
docker-compose build  --build-arg BUILD_ENV=development web
```

In the docker-compose.yml file notice the `secrets` entry. This is for a Google Cloud Service Account, and it's necessary for authentication for storage things in cloud storage and calling the vision API. See the [Project Setup](/project_setup.md) doc for more details. To get started you can just use a blank file 
```
touch ../uploads-bucket-service-account.json
```

And to run:  `docker-compose up`

Note that the BUNDLE_APP_CONFIG environment variable installs gems to /app/.bundle which would be the .bundle directory. If you are having trouble with docker up, try deleting this directory and try again.

When you make a change to the code locally, the code on the server should reflect your changes, although you might need to restart if you make a change to the configuration.

#### Initial Run Once Tasks 



* Connect to the container. First get the container ID from `docker ps`, the exec in

```
docker exec -it CONTAINER_ID bash
```

* Create Database

```
rake db:create
```

* Run Database Migrations
```
rake db:migrate
```

* Create Superuser

Run
```
rake warper:create_superuser
```

Make a note of the email and password in the output. You can use this to login.

* Browse to localhost:3000


####  Running test suite

This assumes the basic prerequisite of understanding how a Ruby on Rails application works, and how to run tests. For more information on testing with this framework see https://guides.rubyonrails.org/v4.2/testing.html

* Connect to the container `docker exec -it CONTAINER_ID bash`
* Set environment variables for tests
```
export DATABASE_URL=postgis://db/mapwarper_test?pool=5
export RAILS_ENV=test
```
* Create test database
```
rake db:create
```

* Migrate test database

```
rake db:migrate
```

* Run test suite

```
rake test
```

To run a group of tests, `rake test:models` or `rake test:controllers` and `rake test:integration`. 

To run just one test: `rake test TEST=test/controllers/maps_controller_test.rb`  

`rake test:integration` is the Selenium tests which spawns a headless firefox browser in the container to run tests against. To run an integration test against a remote URL you should uncomment and edit the following in the `setup` block: 

```
Capybara.app_host = "http://test.example.com/"
Capybara.run_server = false
```


Tests will run a bit slow compared with running it natively, and you'd probably want tests to run quickly. so you can configure the docker-compose file with resources to fit your system: See https://docs.docker.com/compose/compose-file/#resources