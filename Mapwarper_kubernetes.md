# Mapwarper Kubernetes - Kartta Labs

## This Document

This document aims to give details about deploying the mapwarper application to Google Kubernetes Engine. Much of the Kubernetes documentation should also be useful for local development such as using minikube and microk8s.  

See Also
* [Project Setup on GCP](/project_setup.md) for docs about setting up GCP project to work with mapwarper. 

## Table of Contents

* [Docker Build & Push](#docker-Build-&-push)
* [Kubernetes](#kubernetes)
  * [Configuration Files Templating](#configuration-files-templating)
  * [Mapwarper App Config](#mapwarper-app-config)
  * [Secret Key Base](#secret-key-base)
  * [Database Secrets](#database-secrets)
  * [Cloud SQL Credentials (optional)](#cloud-sql-credentials)
  * [Cloud Storage Credentials](#cloud-storage-credentials)
  * [Review Configs](#review-configs)
  * [Deploy Redis (optional)](#deploy-redis)
  * [Mapwarper Storage](#mapwarper-storage)
  * [Initial Run Once Tasks](#initial-run-once-tasks)
  * [Deployment](#deployment)
  * [Load Balancer](#load-balancer)
  * [Scaling](#scaling)
  * [Auto Scaler](#auto-scaler)
  * [Rolling Deploy](#rolling-deploy)



## Docker Build & Push

First check out the code and set up the following files `config/application.yml`, `config/secrets.yml`,  `config/database.yml`  from their example counterparts in the config directory.

You can run the included script to do this for you

```
sh lib/cloudbuild/copy_configs.sh
```

or you can do it manually. 

e.g. 

```
cp config/database.example.yml config/database.yml
cp config/application.example.yml config/application.yml
cp config/secrets.yml.example config/secrets.yml
```

You have the option to edit these files and set the config variables and they will be included in the image. Mapwarper can also set configuration variables via Environment variables and we are using Kubernetes which can configure environment variables (see below). It also might be wise not to include some more sensitive values in the image depending on who has access to the image. 


Example docker build and push to remote (gcr.io) or local registry

e.g `gcr.io/mapwarper-project/mapwarper-dev:v1`
```
docker build . -t gcr.io/PROJECT_ID/IMAGE_NAME:VERSION
docker push gcr.io/PROJECT_ID/IMAGE_NAME:VERSION
```

Using microk8s with the registry plugin and docker, enabled using the "latest" tag

```
docker build . -t localhost:32000/IMAGE_NAME:latest
docker push localhost:32000/IMAGE_NAME:latest
```

e.g.  `docker build . -t localhost:32000/mapwarper-dev:latest`

### Using Google Cloud Build

Prerequisites: Follow the Cloud Build steps in the [Project Setup on GCP](/project_setup.md) document


1) Checkout the code locally. You don't need to copy the config files as that is within a cloud build step. 

2) In the root there is the `cloudbuild.yaml` config file.  Edit the value for the logsBucket entry to point to the logs storage bucket you created in the steps within the [Project Setup on GCP](/project_setup.md) document

3) Submit build job

 Run: 

```
gcloud builds submit --substitutions=SHORT_SHA="$(git rev-parse --short HEAD)" --config cloudbuild.yaml .
```

This will build an image and push it to the gcr.io repository using the first 7 characters of the last commit on the repo as the version

As the build progresses you should see the progress log in the terminal. Additionally you can view the progress on the console: https://console.cloud.google.com/cloud-build/builds



## Kubernetes

Most files will be in the k8s directory. Additionally keep separate from this the secrets and service account json files (in e.g. /path/to/)

First ensure that the image is built and pushed to the gcr.io repo. If built using cloud build the image should be in the Container Repository. If manually built you should be able to see the image: 
```
docker images
gcr.io/PROJECT_ID/IMAGE_NAME    latest              1234505c12        18 minutes ago      1.1GB
```

__Creating the cluster__ on GCP with GKE is documented in [Project Setup on GCP](/project_setup.md) file.

__Microk8s__ 
For local development using microk8s you will need to `--allow-privileged=true` on the cluster.

Add `--allow-privileged=true` to the end of `/var/snap/microk8s/current/args/kubelet` and to the end of `/var/snap/microk8s/current/args/kube-apiserver`. Make sure you restart microk8s afterwards.


### Mapwarper App Config

For a more detail about all the mapwarper configuration variables see the [Mapwarper Configuration](/Mapwarper.md#Configuration) documentation.

Ensure that the database is created (see GCP set up) and the config .yaml files are updated
e.g. copy mapwarper-app-config.example.yaml to mapwarper-app-config.yaml and update the values. 

In particular:

* REDIS_URL: redis://10.xx.xx.xx:6379/0/cache
* MW_GOOGLE_STORAGE_PROJECT
* MW_GOOGLE_STORAGE_BUCKET
* DB_HOST: 10.xx.xx.xx
* MW_SENDGRID_API_KEY: 
* MW_HOST: 35.xx.xx.xx

The MW_HOST value is the domain name or an external IP created by a load balancer, so if there is no domain name associated with the load balancer, it won't be available initially. It's used where a full URL is required in account activation emails for example.

Once you have this value, you can update this value later on via `kubectl apply -f mapwarper-app-config.yaml`

Note that environment variables beginning with "MW_" will get passed into the mapwarper application APP_CONFIG. For example `MW_EMAIL=example@example.com` in the Kubernetes config will overwrite the `APP_CONFIG['email']` value in the application.

Depending on your cluster size and configuration, you may want to limit the amount of RAM to both the gdalwarp process and imagemagick processes. You can change the value of `MAGICK_MEMORY_LIMIT` and `MAGICK_MAP_LIMIT` environment variables to fit your resources. You can give units in bytes or "1GB" or "512MiB" for example. These limit the available RAM to the imagemagick processes. Imagemagick first tries to process the image in memory. If it exceeds these limits then imagemagick process will cache to disk and so the process will take longer but will not take up RAM. There's a chance if not set that the imagemagick process will cause the pod it is running on to be reaped with an out of memory error. Originally without setting this the majority of images were fine but a rare huge image (in dimensions and size) caused the pod (running on a default GKE cluster) to run out of memory depending on what else was running at the same time on the pod.  Imagemagick processes uploaded images into thumbnails, and (if the feature is enabled) converts the image to a suitable format for the OCR Job. The gdalwarp process rectifies the map image, you can limit the amount of RAM for this process by setting the `MW_GDAL_MEMORY_LIMIT` app config variable, set the value as mb without units e.g. `MW_GDAL_MEMORY_LIMIT: 1000`.

Create this config to the cluster:

`kubectl create -f mapwarper-app-config.yaml`

Note also that you can also edit the file and add more values via the GKE console.

### Secret Env Vars

Secret environment variables are loaded into Kubernetes with the mapwarper-secrets.yaml file.

First copy the `mapwarper-secrets.example.yaml` to `mapwarper-secrets.yaml` and add in the values, see below:

#### Secret Key Base

This secret is used in the application

Generate a long string for the secret key e.g. 
`openssl rand -hex 68` 

copy this string and use it as the value for the `secret-key-base` key in the mapwarper-secrets.yaml file


#### Database Secrets 

Storing the configuration for the database as secrets. Using the database name, instance, username and password when you created the database.  The keys are dbinstance, dbname, dbusername, dbpassword. dbinstance is something like `mapwarper-project:europe-west2:mapwarper-dev`  which you can get from the "instance connection name" in the Console.

#### Loading the secret yaml

```
kubectl create -f mapwarper-secrets.yaml
```

### Cloud SQL Service Account

(OPTIONAL - if using the Cloud SQL Proxy)

You would use the proxy if connecting from a local k8s cluster or if the system hasn't got private IP Aliases set up. 

Storing the service account json if using the cloud sql proxy (commented out in the mapwarper deployment)

`kubectl create secret generic cloudsql-instance-credentials --from-file=/path/to/mapwarper-service-account.json`


### Cloud Storage / Cloud Vision Credentials

Service Account json for connecting to the Google Cloud Storage service and for accessing the Cloud Vision service.

`kubectl create secret generic bucket-credentials --from-file=/path/to/mapwarper-service-account.json`

### Review Configs

https://console.cloud.google.com/kubernetes/config?project=PROJECT_ID&config_list_tablesize=50



### Configuration Files Templating 

Some of the kubernetes configuration files (`mapwarper_development.yaml`, `privileged_mapwarper_deployment.yaml`, `db-migrate-job.yaml` and `mapwarper-filestore-storage.yaml`) have environment variables such as ${IMAGE} in them. You can manually edit them or you can use `envsubst` to substitute environment variables with these to make new files, or pipe directly into kubectl. This documentation assumes you have manually changed the existing files, but may sometimes specify when a file is to be edited.

There are only a few variables used:

* ${IMAGE} - The image (e.g. localhost:32000/mapwarper_web:latest) 
* ${FS_NAME} - Filestore fileshare name (e.g /mapfileshare) 
* ${FS_PATH} - Filestore Internal IP Address (e.g. 10.0.0.23)

__Examples Using envsubst__

```
# 1. Making new file and applying 

FS_PATH=/mapfileshare FS_SERVER=10.01.01.01 envsubst < mapwarper-filestore-storage.yaml > mapwarper-filestore-storage.prod.yaml
kubectl apply -f mapwarper-filestore-storage.prod.yaml

# 2. Overwriting the file 

FS_PATH=/mapfileshare FS_SERVER=10.01.01.01 envsubst < mapwarper-filestore-storage.yaml > k8s.tmp && mv k8s.tmp mapwarper-filestore-storage.yaml
kubectl apply -f mapwarper-filestore-storage.yaml

# 3. Using it directly with kubectl

cat mapwarper-filestore-storage.yaml | FS_PATH=/mapfileshare FS_SERVER=10.01.01.01 envsubst | kubectl apply -f - 
``` 




### Deploy Redis 

(OPTIONAL)

With GCP we are using the Cloud Memory Store for Redis and so we will skip this but if you are using a local cluster and want to set up Redis, this is useful. Mapwarper doesn't need to use redis for local development but it does improve performance in production. 

`
kubectl create -f redis-deployment.yaml 
kubectl create -f redis-service.yaml 
`

check services on console or dashboard https://console.cloud.google.com/kubernetes/discovery?project=PROJECT_ID&service_list_tablesize=50
or:

```
kubectl get services
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   10.xx.xx.xx     <none>        443/TCP    20m
redis        ClusterIP   10.xx.xx.xx     <none>        6379/TCP   48s
```

Make a note of the internal IP and set up the REDIS_URL 

### Mapwarper Storage

Kubernetes will use the Filestore set up earlier as an NFS. For local development without NFS see below. 

Change the path (manually or via envsubst) to match the fileshare name of the Filestore and the internal IP to fit `server: 10.xx.xx.xx` within the yaml file.
See the [GCP Filestore Docs](/project_setup.md#Filestore) for more information 

e.g 
```
  nfs:
    path: /mapfileshare
    server: 10.xx.xx.xx
```

Create the Persistent Volume and the Persistent Volume Claim in the same file:

`kubectl create -f mapwarper-filestore-storage.yaml` 

This storage is where processed images and geotiffs are stored. All nodes in the cluster can access this filesystem.

Note: More commonly mentioned with k8s is the use of Persistent Disks. However with GKE, only pods on the same node can read and write to the this type of PV. PVs on Persistent Disk can be set up so that other nodes can read-only but there's not much use with mapwarper for that. 

Show the Persistent Volume and Persistent Volume Claim
```
kubectl get pv
NAME                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                STORAGECLASS   REASON   AGE
mapwarper-fileserver   1T         RWX            Retain           Bound    default/mapwarper-fileserver-claim                           6d

kubectl get pvc
NAME                         STATUS   VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mapwarper-fileserver-claim   Bound    mapwarper-fileserver   1T         RWX                           6d
```
__Local Dev (Optional)__

For local development without an NFS server you can instead use the mapwarper-dev-storage.yaml file to create the Persistent Volume Claim with the default storage of your local cluster.

e.g. using microk8s:

```
microk8s.kubectl create -f mapwarper-dev-storage.yaml 

microk8s.kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                STORAGECLASS        REASON   AGE
pvc-ed8380af-690f-11e9-a421-704d7b894873   3G         RWO            Delete           Bound    default/mapwarper-fileserver-claim   microk8s-hostpath            14m

microk8s.kubectl get pvc
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
mapwarper-fileserver-claim   Bound    pvc-ed8380af-690f-11e9-a421-704d7b894873   3G         RWO            microk8s-hostpath   14m
```


### Initial Run Once Tasks

There are some tasks that need to be done once when initially creating everything on a cluster.

`kubectl create -f privileged_mapwarper_deployment.yaml`

using envsubst to substitute the IMAGE variable, with an example image name:

`
cat privileged_mapwarper_deployment.yaml | IMAGE=localhost:32000/mapwarper_web:abcs envsubst | kubectl apply -f -
`

Find the pod name

```
 kubectl get pods
NAME                              READY     STATUS    RESTARTS   AGE
mapwarper-priv-779d8c8bfd-6hpcr   1/1       Running   0          1h
```
e.g. POD_NAME is mapwarper-priv-779d8c8bfd-6hpc in the above example.

Exec into the pod

`kubectl exec -it POD_NAME bash`

Now you can run the database migration and create the super user

__Database Migration__

run 
 `rake db:migrate`


__Create Super User__

run 
 `rake warper:create_superuser`

make a note of the created password and use for logging into

__Make Paths__

e.g. These paths should be the same as specified in the config. i.e. src_maps_dir in application.yml which is MW_SRC_MAPS_DIR in the mapwarper-app-config.yaml which would be pointing to the networked volume, `mapwarper-filestore-volume`

```
mkdir /mnt/mapwarper/maps/dst
mkdir /mnt/mapwarper/maps/src
mkdir /mnt/mapwarper/maps/masks
mkdir /mnt/mapwarper/maps/tileindex
```


__Clean Up__
`kubectl delete deployment mapwarper-priv`


### Deployment

`kubectl create -f mapwarper_deployment.yaml`

and watch the pods being created

`watch kubectl get all -n default`

```
get pods

NAME                                READY   STATUS              RESTARTS   AGE
pod/mapwarper-web-f89f87578-fb2k2   0/1    ContainerCreating   0          6s
```


### Load Balancer

Add a HTTP(S) Load Balancer via a NodePort Service and Ingress


```
kubectl create -f mapwarper-np-ingress-service.yaml                                                                                                                                                                               
service/mapwarper-np created
ingress.extensions/mapwarper-ingress created
```

View the created service and ingress

```
kubectl get service mapwarper-np
NAME           TYPE       CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
mapwarper-np   NodePort   XX.XX.XX.XX   <none>        3000:30123/TCP   3m

kubectl get ingress mapwarper-ingress
NAME                HOSTS     ADDRESS         PORTS     AGE
mapwarper-ingress   *         XX.XX.XX.XX    80        49s
```

 Wait for propagation - may take a few minutes. Set up your DNS if you want to use a domain name
 
Optional: Convert the ephemeral IP to a static one. 

Convert it here: https://console.cloud.google.com/networking/addresses/list
See: https://cloud.google.com/compute/docs/ip-addresses/#ephemeraladdress 

### HTTPS Loadbalancer

For more general docs: https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs

#### Create static IP

To create a https load balancer with a Google Managed certificate.

First make sure you have a static IP address. If you have one already convert the ephemeral IP to a static one. 

In the Console: https://console.cloud.google.com/networking/addresses/list find the ephemeral ip address for the loadbalancer and select it to static

In the dialog window that appears give it a name and make a note of this (e.g. mapwarper-k8s-static-ip) and an optional description, and continue

#### Create ManagedCertificate

Using `example.com` as your domain, this will create a certificate with the name `mapwarper-certificate`

```
DOMAIN=example.com envsubst  < mapwarper-certificate.yaml > k8s.tmp && mv k8s.tmp mapwarper-certificate.yaml
kubectl apply -f mapwarper-certificate.yaml
```


#### Apply Ingress using Certificate

First if you have a regular http ingress you might have to delete it:

```
kubectl delete ingress mapwarper-ingress
```

Using the name of the static IP that you created above

```
STATIC_IP=mapwarper-k8s-static-ip envsubst  < mapwarper-https-ingress.yaml > k8s.tmp && mv k8s.tmp mapwarper-https-ingress.yaml

kubectl apply -f mapwarper-https-ingress.yaml
```

You will need to wait up to 15 minutes for the certificate to provision. You can check on this via

```
kubectl describe managedcertificate
```

Once a certificate is successfully provisioned, the value of the Status.CertificateStatus field will be Active


Note: if you want to distable http at this level, add this annotation 
`kubernetes.io/ingress.allow-http: "true"` 

#### Update Host with Scheme application config

Change the mapwarper app config variable:

MW_HOST_WITH_SCHEME from http to  https:// 

`kubectl apply -f mapwarper-app-config.yaml`  or edit it on the console



#### Increase loadbalancer timeout

If you are using lower spec machines, upload requests may take some time to process more than the default timeout of the loadbalancer. One way to increase the timeout is via the gcloud commands:

First get the name of the new backend service 

```
gcloud compute backend-services list

NAME        BACKENDS                                            PROTOCOL
k8s-be-XXX  zone/instanceGroups/k8s-ig--XX        HTTP
```
then using the name, update the timeout value. Here we increase the timeout to 90 seconds

```
gcloud compute backend-services update k8s-be-XXX --timeout=90
```
(and choose 1 to apply it for global)



### Scaling

Use the kubectl scale command passing in the amount of desired replicas 

`kubectl scale --replicas=2 deployment mapwarper-web`


### Auto Scaler

There are three ways that Kubernetes on GKE/GCP autoscales. Horizonal Pod Autoscaler (scale pods across the cluster), Vertical Pod Autoscaler (increase CPU and Ram across pods) and Cluster Autoscaler (increase cluster size). 

#### Horizontal Pod Autoscaler (HPA)

You can create a basic horizontal pod autoscaler (HPA) based on CPU usage

`kubectl create -f autoscaler.yaml`

Note that autoscaling is based on pod limit and thresholds. The relevant things to look at and change to fit a deployment would be. Future performance work should change these values. 

In `mapwarper_deployment.yaml`  Depending on the cluster and nodes you can give a mapwarper pod more or less resources. By default with no resources definition GKE sets the cpu requests to "100m". 

```
resources:
  limits:
    cpu: 1
  requests:
    cpu: 250m
```

and in the `autoscaler.yaml` You can change the maximum number of replicas, and targetCPUUtilizationPercentage is the average usage across all the pods which kubernetes uses to estimate if things needs scaling or not. 

```
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

Watch `watch kubectl get all -n default` to see pods being scaled the hpa showing the usage or `watch kubectl get hpa` to just see the autoscaler. 

You can also use `kubectl top node` and `kubectl top pod` to see what your nodes and pods are using.

### Vertical Pod Autoscaler (VPA)

Still in beta https://cloud.google.com/kubernetes-engine/docs/how-to/vertical-pod-autoscaling  This will increase the CPU and RAM requests of pods, it can also make recommendations for initial request levels. However it cannot currently be used with HPA when CPU or memory is being used for the metrics - it only work with custom metrics. 

### Cluster Autoscaler (CA)

https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler

"GKE's cluster autoscaler automatically resizes clusters based on the demands of the workloads you want to run. With autoscaling enabled, GKE automatically adds a new node to your cluster if you've created new Pods that don't have enough capacity to run; conversely, if a node in your cluster is underutilized and its Pods can be run on other nodes, GKE can delete the node."

How does Horizontal Pod Autoscaler work with Cluster Autoscaler?

"Horizontal Pod Autoscaler changes the deployment's or replicaset's number of replicas based on the current CPU load. If the load increases, HPA will create new replicas, for which there may or may not be enough space in the cluster. If there are not enough resources, CA will try to bring up some nodes, so that the HPA-created pods have a place to run. If the load decreases, HPA will stop some of the replicas. As a result, some nodes may become underutilized or completely empty, and then CA will delete such unneeded nodes."

Enable Cluster Autoscaling for existing cluster from size 3 to 15 

```
gcloud container clusters update [CLUSTER_NAME] --enable-autoscaling --min-nodes 3 --max-nodes 15 --zone [COMPUTE_ZONE] --node-pool default-pool
```

So for full autoscaling both a HPA and a CA should be used, with maxReplicas and max-nodes configured in the HPA and CA respectively. For example using the HPA with a maxReplicas of 10 - with 10 replicas, we might see a maximum number of nodes scaled up to around 6. 

To monitor the CA:

```
kubectl describe configmap cluster-autoscaler-status --namespace=kube-system
```

### Rolling Deploy 


First build the image and push to the registry
```
docker build . -t gcr.io/PROJECT_ID/IMAGE_NAME:NEW_VERSION
docker push gcr.io/PROJECT_ID/IMAGE_NAME:NEW_VERSION
```

Then set the deployment to this new image tag

`kubectl set image deployment/mapwarper-web web=gcr.io/PROJECT_ID/IMAGE_NAME:NEW_VERSION`

Kubernetes will then rollout this image across the pods ensuring that theres no break in service. (Note that if you just have the one pod and getting things running it might be a quicker to scale replicas to 0 and then to 1 again but you would have a break in service whilst that occurs) 




