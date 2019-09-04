# Mapwarper Deployment on GCP - Kartta Labs

## This Document

This document aims to give details about setting up a Google Cloud Platform Project and deploying the mapwarper application to Google Kubernetes Engine. Much of the Kubernetes documentation should also be useful for local development such as using minikube and microk8s.

See Also
* [Mapwarper Kubernetes](/Mapwarper_kubernetes.md) for docs about Google Kubernetes Engine and Kubernetes in general. 

## Table of Contents

* [Google Cloud Platform](#gcp)
  * [Setup Project](#setup-project)
  * [Enable APIs](#enable-apis)
  * [Service Accounts](#service-accounts)
  * [Create GKE Cluster](#create-gke-cluster)
  * [Cloud SQL](#sql)
  * [Cloud Storage](#storage)
  * [Cloud Vision](#vision)
  * [MemoryStore for Redis](#memorystore)
  * [FileStore](#filestore)
  * [Tiles CDN](#tiles-cdn)
  * [Cloud Build](#cloud-build)
* [Kubernetes](/Mapwarper_kubernetes.md) (Mapwarper_kubernetes.md)


## GCP
Details about setting up mapwarper to work on the Google Cloud Platform. Includes docs about IAM, APIs, setting up buckets etc. For Kubernetes and Google Kubernetes Engine, please see the following document [Mapwarper Kubernetes](/Mapwarper_kubernetes.md).

### Setup Project

Using gcloud in your terminal locally or in the Google Cloud Console.

Create a project and make sure billing is enabled. Make a note of the name of the project, this will be PROJECT_ID in these docs.

Auth / Login

`gcloud auth login`

Set the active project

`gcloud config set project PROJECT_ID`

Set the compute zone for the cluster

`gcloud config set compute/zone ZONE`	


### Enable APIs
Note,  `gcloud services list --enabled`  will show there are already some default APIs enabled with a new project. 


Enable the following APIS. 

* storage-api.googleapis.com                            Google Cloud Storage JSON API
* storage-component.googleapis.com                      Cloud Storage
* sql-component.googleapis.com                          Cloud SQL
* sqladmin.googleapis.com                               Cloud SQL Admin API
* redis.googleapis.com                                  Google Cloud Memorystore for Redis API
* file.googleapis.com                                   Cloud Filestore API
* servicenetworking.googleapis.com                      Service Networking API
* vision.googleapis.com                                 Cloud Vision API

You can do one at a time:

```
~$ gcloud services enable container.googleapis.com
Operation "operations/foo.bar finished successfully
```

Or a few at once
```
gcloud services enable container.googleapis.com storage-component.googleapis.com sql-component.googleapis.com storage-api.googleapis.com sqladmin.googleapis.com redis.googleapis.com file.googleapis.com servicenetworking.googleapis.com vision.googleapis.com
...
Operation "operations/foo.bar" finished successfully
```

Make sure things were enabled properly:
```

~$ gcloud services list --enabled
NAME                               TITLE
bigquery-json.googleapis.com       BigQuery API
cloudapis.googleapis.com           Google Cloud APIs
clouddebugger.googleapis.com       Stackdriver Debugger API
cloudtrace.googleapis.com          Stackdriver Trace API
compute.googleapis.com             Compute Engine API
container.googleapis.com           Kubernetes Engine API
containerregistry.googleapis.com   Container Registry API
datastore.googleapis.com           Cloud Datastore API
deploymentmanager.googleapis.com   Cloud Deployment Manager V2 API
file.googleapis.com                Cloud Filestore API
iam.googleapis.com                 Identity and Access Management (IAM) API
iamcredentials.googleapis.com      IAM Service Account Credentials API
logging.googleapis.com             Stackdriver Logging API
monitoring.googleapis.com          Stackdriver Monitoring API
oslogin.googleapis.com             Cloud OS Login API
pubsub.googleapis.com              Cloud Pub/Sub API
redis.googleapis.com               Google Cloud Memorystore for Redis API
replicapool.googleapis.com         Compute Engine Instance Group Manager API
replicapoolupdater.googleapis.com  Compute Engine Instance Group Updater API
resourceviews.googleapis.com       Compute Engine Instance Groups API
servicemanagement.googleapis.com   Service Management API
servicenetworking.googleapis.com   Service Networking API
serviceusage.googleapis.com        Service Usage API
sql-component.googleapis.com       Cloud SQL
sqladmin.googleapis.com            Cloud SQL Admin API
storage-api.googleapis.com         Google Cloud Storage JSON API
storage-component.googleapis.com   Cloud Storage
cloudbuild.googleapis.com          Cloud Build

```



### Service Accounts

Service Accounts are used for: Connecting to Google Storage and Cloud SQL using the Cloud SQL Proxy.  You can create one Service Account to be used for both or two Service Accounts to be used for the two resources. 

#### Create a service account

`gcloud iam service-accounts create [SA-NAME]  --display-name "[SA-DISPLAY-NAME]"`

e.g.
```
gcloud iam service-accounts create mapwarper-dev-sa --display-name "Access for storage and cloud sql" 
Created service account [mapwarper-dev-sa].
```

Get the service account ID. See the email of the service account which is in the format SA-NAME@PROJECT_ID.iam.gserviceaccount.com

```
gcloud iam service-accounts list

NAME                                    EMAIL
Compute Engine default service account  **********
Access for storage and cloud sql        mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com
```

#### Assign roles to Service Account

We need to assign roles to this service account so that it can access SQL and Storage

`roles/cloudsql.admin`, `roles/cloudsql.client` and `roles/cloudsql.editor`

`gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:SERIVCE_ACCOUNT_EMAIL" --role="ROLE"`

e.g
```
gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudsql.admin" 

gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudsql.client" 

gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudsql.editor" 
```

check to make sure the service Account is listed in the list: 

```
gcloud projects get-iam-policy PROJECT_ID

bindings:
- members:
  - serviceAccount:SERIVCE_ACCOUNT_EMAIL
  role: roles/cloudsql.admin
- members:
  - serviceAccount:SERIVCE_ACCOUNT_EMAIL
  role: roles/cloudsql.client
- members:
  - serviceAccount:SERIVCE_ACCOUNT_EMAIL
  role: roles/cloudsql.editor
```

(NOTE: for bucket IAM, we grant permission at the bucket level to this service account, rather than grant the service account permission at the project level. See below)


#### Get Service Account Key
From the docs https://cloud.google.com/iam/docs/creating-managing-service-account-keys#iam-service-account-keys-create-gcloud

 `gcloud iam service-accounts keys create ~/key.json   --iam-account [SA-NAME]@[PROJECT-ID].iam.gserviceaccount.com`

e.g.

`gcloud iam service-accounts keys create ~/mapwarper-service-account.json   --iam-account mapwarper-dev-sa@[PROJECT-ID].iam.gserviceaccount.com`

and the make sure you keep a note of the location of this json service account key and the files name for use in the kubernetes deployment section

### Create GKE Cluster

Set the compute zone for the cluster

`gcloud config set compute/zone ZONE`

Create the cluster (e.g with a CLUSTER_NAME of mapwarper-project) with ip aliases enabled

`gcloud container clusters create CLUSTER_NAME --enable-ip-alias`

Get the credentials for the cluster so that Kubectl (the command line Kubernetes program) will be able to talk to that cluster. 

`gcloud container clusters get-credentials CLUSTER_NAME`

Check the cluster is up and running.

`gcloud compute instances list`

Check to see if there are the IP aliases / Secondary subnets set up

```
gcloud container clusters describe CLUSTER_NAME

clusterIpv4Cidr: 10.x.x.x/14
servicesIpv4Cidr: 10.x.x.x/20
```

### SQL

#### Create instance.


First, ensure you have a default VPC network present if there is you can skip to creating the database instance. For more information, https://cloud.google.com/sql/docs/postgres/configure-private-ip Please ensure the database and kubneretes cluster (and other resources you set up) are in the same region or zone - the closer things are to each other the better but also they need to be in the same region for the subnet on the VPC network with private IP to work.

To list VPC networks:

```
 gcloud compute addresses list --global --filter="purpose=VPC_PEERING"
 ```


It's more likely that you would need to create the network, and then the vpc peering

```
gcloud compute addresses create google-managed-services-default \
    --description='Peering range reserved for Google' --global \
    --network=default --purpose=VPC_PEERING --prefix-length=16

gcloud services vpc-peerings connect --network=default     --ranges=google-managed-services-default --service=servicenetworking.googleapis.com
```

```
gcloud compute addresses list --global --filter="purpose=VPC_PEERING"

NAME                             ADDRESS/RANGE   TYPE      PURPOSE      NETWORK  REGION  SUBNET  STATUS
google-managed-services-default  XX.XX.XX.XX    INTERNAL  VPC_PEERING  default                  RESERVE
```

From the docs: https://cloud.google.com/sql/docs/postgres/create-instance

```
gcloud sql instances create [INSTANCE_NAME] --database-version=POSTGRES_9_6 \
       --cpu=[NUMBER_CPUS] --memory=[MEMORY_SIZE]  	--region=[REGION]  --zone=[ZONE] --network=VPC_NETWORK
```

Create a basic instance with the "mapwarper-db-instance" as the INSTANCE_NAME using `gcloud beta`

 `gcloud beta sql instances create mapwarper-db-instance --cpu=1 --memory=3840MiB --database-version=POSTGRES_9_6 --zone=us-east4-a --storage-type=SSD --network=default`

This might take a few minutes to create and print out:

```
Creating Cloud SQL instance...done.                                                                                    
Created [https://www.googleapis.com/sql/v1beta4/projects/PROJECT_ID/instances/mapwarper-db-instance].
NAME                    DATABASE_VERSION  LOCATION    TIER              PRIMARY_ADDRESS  PRIVATE_ADDRESS  STATUS
mapwarper-db-instance  POSTGRES_9_6      us-east4-a  db-custom-1-3840  XXX.XXX.XXX.XXX    XX.XX.XX.XX  RUNNABLE
```
The private address would be the address used for connecting to the instance from the application.

If you have an existing instance without a network you can assign it this way

`gcloud beta sql instances patch mapwarper-db-instance --network=default --no-assign-ip`


Take a note of the PRIVATE_ADDRESS as you will use that when configuring the application later. 

#### Create postgres user

You would also need to make a note of the password

` gcloud sql users set-password postgres --instance=[INSTANCE_NAME]  --password=[PASSWORD]  `

Example using the database we just created and a password of "dontusethispassword"
```
gcloud sql users set-password postgres  --instance=mapwarper-db-instance  --password=dontusethispassword 

Updating Cloud SQL user...done.
```

#### Create Database

`gcloud sql databases create DATABASE_NAME --instance=INSTANCE_NAME`

example, creates a database called "mapwarper-production"

```
gcloud sql databases create mapwarper-production --instance=mapwarper-db-instance

Creating Cloud SQL database...done.                                                                                                            
Created database [mapwarper-production].
instance: mapwarper-db-instance
name: production
project: PROJECT_ID
```

#### Connect to database

The easiest way to connect to the database instance is to connect via gcloud 

`gcloud sql connect mapwarper-db-instance --user=postgres --quiet`


Connecting via local psql and the Cloud SQL Proxy.

Follow the documentation here to install the proxy: https://cloud.google.com/sql/docs/postgres/connect-admin-proxy#install

in one terminal run the proxy (note the 5434 port in case you have a local pg database running on the usual port)
```
./cloud_sql_proxy -instances=PROJECT_ID:us-east4:mapwarper-db-instance1=tcp:5434 -credential_file=~/mapwarper-service-account.json
```
then in another local terminal
```
psql "host=127.0.0.1 port=5434 sslmode=disable dbname=postgres user=postgres"
```

#### Enable Postgis Extension

For the new database we need to enable the postgis extension

Connect to the database we just created mapwarper-production 

via gcloud sql connect, we connect into the postgres database first, so we connect to the database.

```
gcloud sql connect mapwarper-db-instance --user=postgres --quiet

postgres=> \c mapwarper-production
Password for user postgres: 

mapwarper-production=> create extension postgis;
CREATE EXTENSION
```

or, using the sql proxy, connect to the database directly:

```
psql "host=127.0.0.1 port=5434 sslmode=disable dbname=mapwarper-production user=postgres"

mapwarper-production=> create extension postgis;
CREATE EXTENSION
```


### Storage

Mapwarper uses Storage (buckets) to store uploaded thumbnails of maps and public published seeded tiles. The two buckets should be accessed with the same Service Account. 

#### Uploads & Thumbnails

Create new bucket. Make sure the BUCKET_NAME is a unique as each bucket name is unique across all of the projects on GCP and bucket names themselves are publicly visible.

Using gsutil command

`gsutil mb -p PROJECT_ID   gs://[BUCKET_NAME]/ `

e.g. creating a bucket with name "mapwarper-bucket" in the "mapwarper-project" project

```
gsutil mb -p mapwarper-project   gs://mapwarper-bucket/ 

>Creating gs://mapwarper-bucket/...

gsutil ls
>gs://mapwarper-bucket/
```

Add IAM permission for the Service Account to the bucket

`gsutil iam ch [MEMBER_TYPE]:[MEMBER_NAME]:[ROLE] gs://[BUCKET_NAME]`


`gsutil iam ch serviceAccount:SERVICE_ACCOUNT_EMAIL:objectAdmin,objectCreator,objectViewer gs://BUCKET_NAME`

e.g.
```
gsutil iam ch serviceAccount:mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com:objectAdmin,objectCreator,objectViewer gs://mapwarper-bucket
```

View the Permissions for the bucket:

`gsutil iam get gs://mapwarper-bucket/`




#### Vision 

When maps are added they are OCR'd using Google Cloud Vision API. Ensure the API is enabled and the API will use the Service Account that can access the buckets. The OCR routine can optionally use a bucket to store images (see above for configuration). Using a bucket enables the size of the images to increase and possibly increase accuracy. 

#### OCR Bucket

Optional.

You can create a bucket to store processed images for passing to the Cloud Vision API for OCR. Make sure the bucket name is globally unique.  Use the same Service Account for access. 

Create the bucket

```
gsutil mb -p PROJECT_ID   gs://[BUCKET_NAME]/

gsutil mb -p mapwarper-project   gs://ocr-bucket/ 
```

Add IAM permission for the Service Account to the bucket

```
gsutil iam ch [MEMBER_TYPE]:[MEMBER_NAME]:[ROLE] gs://[BUCKET_NAME]


gsutil iam ch serviceAccount:SERVICE_ACCOUNT_EMAIL:objectAdmin,objectCreator,objectViewer gs://BUCKET_NAME
```

#### Public Seeded Tiles

Create a new bucket. This bucket is used to place tiles generated using [tilestache](http://tilestache.org/) when an admin user "publishes" a map or layer. A copy of the tilestache code lives in the lib directory. This is accessed via the tiles CDN (see below). Use the name for this bucket in the `google_tiles_bucket` application config or override the Kubernetes environment variable `MW_GOOGLE_TILES_BUCKET`.

Again make sure the bucket name is globally unique and that the name is okay being publicly visible. 

`gsutil mb -p PROJECT_ID   gs://[BUCKET_NAME]/ `

e.g. creating a bucket with name "mapwarper-tiles-bucket" in the "mapwarper-project" project

```
gsutil mb -p mapwarper-project   gs://mapwarper-tiles-bucket/ 

```
Add IAM permission for the Service Account to the bucket

```
gsutil iam ch serviceAccount:mapwarper-dev-sa@PROJECT_ID.iam.gserviceaccount.com:objectAdmin,objectCreator,objectViewer gs://mapwarper-tiles-bucket
```

### MemoryStore

Create a Cloud Memory Store For Redis service. Redis is used for caching tiles and map requests. You can add more memory which should improve performance of tiles.  Make sure this is on the same region or zone as the other resources.

Size is size in Gb.Values start from 1Gb to 300! In this example we create a small 2Gb basic instance in the us-east4-a zone and give it a name "mapwarper-redis-instance".

We should also configure it with the maxmemory policy of "allkeys-lru". This option makes Redis remove the least used keys when full. 


```
gcloud beta redis instances create mapwarper-redis-instance --size=2 --region=us-east4 --zone=us-east4-a --redis-version=redis_4_0  --redis-config maxmemory-policy=allkeys-lru
```

View instance and IP address on default internal network. First, find the instance, passing in the specified region:

```
gcloud redis instances list --region=us-east4

INSTANCE_NAME             REGION    TIER   SIZE_GB  HOST      PORT  NETWORK  RESERVED_IP  STATUS  CREATE_TIME
mapwarper-redis-instance  us-east4  BASIC  2        xx.xx.xx.xx  6379  default   xx.xx.xx.xx/xx READY   2019-03-21T13:02:59
```

 Note the HOST IP address for use in the mapwarper config REDIS_URL later


### FileStore

Mapwarper uses Filestore to store the converted raw images and georectified geotiffs to make them accessible from all the application servers.  https://cloud.google.com/filestore/docs/ Cloud Filestore is a managed file storage service for applications.  The filestore needs to be in the same GCP Project and within the same region to work on the subnet for the VPC network. 

More commonly mentioned with Kubernetes is the use of Persistent Disks. However with GKE, only pods on the same node can read and write to that disk. So using a persistent disk would be okay where all your mapwarper pods run on one node in a small cluster. It might also be possible to use Storage buckets for this role - performance might need to be evaluated. 

The minimum starting capactity is 1TB (about $204 / month)

From the docs: 
```
gcloud filestore instances create [INSTANCE_ID] \
    --project=[PROJECT_ID] \
    --zone=[ZONE] \
    --tier=[TIER] \
    --file-share=name="[FILESHARE_NAME]",capacity=2TB \
    --network=name="default"
```

Example using a zone of `us-east4-a` an instance name of "mapwarper-fs-instance" a file-share-name of "mapfileshare" and the Standard tier on our example project "mapwarper-dev". It's important that you use the same zone or at least the same region to keep latencies low. 

```
gcloud filestore instances create mapwarper-fs-instance --project=mapwarper-dev --zone=us-east4-a --tier=STANDARD --file-share=name=mapfileshare,capacity=1TB --network=name="default"

Waiting for [operation-1a1..a2c] to finish...done.
```

Make a note of the file share name, and get the internal IP Address by listing the instance.

You would use this IP Address and FILE_SHARE_NAME in the [mapwarper storage kubernetes setup](/Mapwarper_kubernetes.md#mapwarper-storage) section later on 

```
gcloud filestore instances list
INSTANCE_NAME              ZONE        TIER      CAPACITY_GB  FILE_SHARE_NAME  IP_ADDRESS     STATE  CREATE_TIME
mapwarper-fs-instance  us-east4-a  STANDARD  1024         mapfileshare         XX.XX.XX.XX   READY  2019-04-10T12:34:09
```


### Tiles CDN

The Tiles CDN is the cache of seeded tiles for "published" maps and layers. When an admin publishes a map or layer, on the server, a tilestache process is started which requests tiles from mapwarper and stores them in a bucket. This bucket is then the backend for a loadbalancer and CDN. External applications can requests tiles from the CDN to have very fast tiles and also reduce load on mapwarper. 

Using the Public Seeded Tiles bucket we created above.

Alternatively if you do not have a domain for the tiles, you can avoid this setup (while probably saving some money) and just use the direct google storage bucket link: e.g. 
 https://storage.googleapis.com/BUCKET_NAME/6/6spec.json

#### 1. create a backend bucket

`gcloud compute backend-buckets create [BACKEND_BUCKET_NAME] --enable-cdn --gcs-bucket-name=[BUCKET_NAME]`

e.g.

```
gcloud compute backend-buckets create tiles-backend-bucket --enable-cdn --gcs-bucket-name=mapwarper-tiles-bucket
```


####  2. Create url map

`gcloud compute url-maps create URL_MAP  --default-service BACKEND_SERVICE  [--description DESCRIPTION]`

e.g

```
gcloud compute url-maps create mapwarper-tiles-url-map --default-backend-bucket=tiles-backend-bucket

NAME                     DEFAULT_SERVICE
mapwarper-tiles-url-map  backendBuckets/tiles-backend-bucket
```


#### 3. Add path matcher to url map
`gcloud compute url-maps add-path-matcher URL_MAP  --default-backend-bucket BACKEND_BUCKET--path-matcher-name PATH_MATCHER [--backend-bucket-path-rules=PATH=BUCKET_NAME,[...]] ` 

```
gcloud compute url-maps add-path-matcher mapwarper-tiles-url-map  --default-backend-bucket tiles-backend-bucket  \
--path-matcher-name mapwarper-tiles-bucket-matcher   --backend-bucket-path-rules="/*=tiles-backend-bucket"
```


#### 4. Create a target HTTP proxy to route requests to your URL map.

`gcloud compute target-http-proxies create NAME --url-map=URL_MAP [--description=DESCRIPTION] [GCLOUD_WIDE_FLAG …]`

```
gcloud compute target-http-proxies create http-tiles-lb-proxy --url-map mapwarper-tiles-url-map
```

#### 5. create ip address

```
gcloud compute addresses create tiles-ip --global
```


#### 6. List IP address
```
gcloud compute addresses list tiles-ip

NAME             ADDRESS/RANGE  TYPE      PURPOSE  NETWORK  REGION  SUBNET  STATUS
tiles-ip         XX.XX.XX.XX   EXTERNAL                                    RESERVED
```

#### 7. Create forwarding rules to route incoming requests to the proxy.

```
gcloud compute forwarding-rules create RULE_NAME \
    --address [LB_IP_ADDRESS|ADDRESS_NAME] \
    --global \
    --target-http-proxy PROXY_NAME \
    --ports 80
```

The address option can be either the name of the address (in our example 'tiles-ip') or the IP Address that has just been created.

```
gcloud compute forwarding-rules create tiles-http-forwarding-rule \
    --address=tiles-ip --global \
    --target-http-proxy http-tiles-lb-proxy --ports=80
```


After creating the global forwarding rule, it can take several minutes for your configuration to propagate!


#### 8. Test to see if it works after 10 or so minutes at the IP address.

http://XX.XX.XX.XX/

you should see a XML error!

If you put an object (e.g. image.jpg) to the bucket and make it public (edit permissions, add user 'allUsers' with read permission) you can browse to that (e.g. http://XX.XX.XX.XX/image.jpg)


##### Keep a note of the IP Address and/or domain for later 

Keep a note of the ip address or domain with scheme for use in mapwarper configuration (e.g. cd_tiles_host: "http://XX.XX.XX.XX")


### Cloud Build

Optional. 

This is an optional step, you can build and deploy images manually, however in order to take advantage of Google Cloud Build, you can follow these steps.

####  Enable the Cloud Build API 

Unless it is not already enabled

```
gcloud services enable cloudbuild.googleapis.com
```

#### Create logs storage bucket

create storage bucket (remember to choose a globally unique name) e.g. `mapwarper-cloudbuild-logs` . This step is not strictly necessary if the project owner is the same one as the user submitting the build but it doesn't hurt and is needed if another user is doing the builds. 

```
gsutil mb -p PROJECT_ID   gs://[BUCKET_NAME]/ 
```

#### Give Service Account access to logs bucket

Assign the cloud build service account access to the bucket (example using mapwarper-cloudbuild-logs as the bucket). This is the default service account set up when enabling the cloud build API which needs to be able to create and write to the log.

Get the PROJECT_NUMBER from `gcloud projects list | grep $GOOGLE_CLOUD_PROJECT` if within the cloud console

```
gsutil iam ch serviceAccount:PROJECT_NUMBER@cloudbuild.gserviceaccount.com:objectCreator gs://mapwarper-cloudbuild-logs
```

Additional steps relating to setting up the code and submitting the build are covered in the Mapwarper_Kubernetes document.



