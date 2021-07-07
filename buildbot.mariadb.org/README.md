 ```
 _________________________
< Build all the things!   >
 -------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
 ```

# Overview
==========

buildbot.mariadb.org is our continuous integration testing platform, based on the Buildbot.net open-source testing framework.

This installation uses a custom version 2.7.1 at time of initial deployment running with Python 3 on a Ubuntu 18.04 decently tuned (performance wise) machine for a more speedy, modern and responsive UI in contrast to the existing Buildbot v0.8.8 running at buildbot.askmonty.org.

This directory contains all the configuration needed to deploy a new installation of Buildbot master to a new machine, as well as all the information needed to add new builder configurations, extra worker machines to extend our building capability and platform support and specific steps you can take to reproduce the exact environment in which a build failure occurred so you can debug without much effort.

Quick layout of the main components of the current directory structure:

```
buildbot.mariadb.org/
├── buildbot.tac
├── dockerfiles
│   ├── buildbot.tac
│   └── ...
│   └── ecofiles
│       ├── installdb.sh
│       ├── test-php.sh
│       └── test-pymysql.sh
├── master.cfg
├── master-private.cfg-sample
├── master-web
│   ├── buildbot.tac
│   ├── master.cfg
│   ├── static
│   │   └── (sponsor logos)
│   ├── templates
│   │   ├── console_view
│   │   │   └── console.jade
│   │   ├── grid.html
│   │   ├── grid_view
│   │   │   └── grid.jade
│   │   ├── home.jade
│   │   └── sponsor.html
│   └── twistd.pid
├── README.md
├── sponsor.py
├── static
└── util
    ├── buildbot-master.service
    ├── buildbot-worker.service
    └── nginx.conf
```

* __buildbot.tac__: the only application configuration file Buildbot needs to get up and running in master mode, this one can remain largely unchanged
* __dockerfiles/buildbot.tac__: worker application configuration file, being sent by the master to the Docker workers
* __dockerfiles/*.dockerfile__: [docker image files](https://docs.docker.com/engine/reference/builder/), also sent from the master to the docker based worker machines
* __master.cfg__: the master configuration file, describes the build scheme and all other site site specific configuration
* __sponsor.py__: custom Buildbot dashboard plugin that adds a menu item named *Sponsors*, used to list all the donated servers that are being used by this instance
* __static__: image logos for the donors HTML presentation of the dashboard plugin
* __templates__: HTML templates for dashboard plugins, currently only *sponsor.html* for the Sponsors plugin
* __util__: various associated config files and tools, like the systemd service file and nginx configuration
* __master-web__: a separate master configuration for handling the UI

## A word on Docker
===================

We are using Docker for targeting Linux builds. This makes it easy (and cheap) to add new distribution flavored builders with just a Dockerfile, while also facilitating environment replication locally, without much effort, making it easy to inspect, reproduce the build environment and debug failures.

Using Buildbot's DockerLatentWorker to connect to docker instances, the worker runs inside the Docker image, and on a build trigger, master connects to Docker first via docker-py , instantiates the image and then connects using Buildbot usual Worker API to do the heavy lifting. Upon build completion, the image is stopped and no left-overs are left behind.


## Navigating the new interface
===============================

Starting with version 1.0, Buildbot interface changed in a significant and positive manner. The new UI is a fresh rewrite with responsive, lazy loading and modern web conveniences that makes it easy to follow running builds as well as convenient to browse build history.

Grid View and MTRLogObserver plugin are usable out of the box and behave in a similar fashion as in the current Buildbot instance.

# Debugging build failures
==========================  

Debugging build failures with Docker is facilitated by the ease of replicating the actual build environment where a particular builder failed. First step is to identify on which platform the failure occurred and what's the associated Dockerfile. If you're not familiar with Docker, start by reading the [Docker overview](https://docs.docker.com/engine/docker-overview/) and [Docker getting started documentation](https://docs.docker.com/get-started/).

To repeat a build on buildbot, first identify the platform and look for the associated dockerfile in the dockerfiles/ directory. To create a container for Ubuntu 18.04 for e.g. you would use the *docker build* command like this:
`docker build -t ubuntu-1804 --file ubuntu1804.dockerfile .`

After a successful image build, you can run a container and execute bash using that image with *docker run*:
`docker run -it ubuntu-1804 bash`

After this step you can follow the usual MariaDB development setup instructions, i.e. clone the repo and start a build. To specifically reproduce what a particular Buildbot worker did, look into the master.cfg configuration file what addStep() has been defined for that worker, and copy paste the contents of those into the session you are running in the Docker image.

# Deployment
============

Deploying a new master (since Buildbot > 1.0 supports multi-master configuration):

1. Setup your server. This configuration has been tested on Buildbot 2.0.1, Python 3 and Ubuntu so far.
2. Install Buildbot and associated plugins, you have two options here:
   a) install from the official distribution repositories (1.1 in Ubuntu 18.04)
   b) install from the PyPi repository which should have the latest stable release (2.0.1 in March 2019)
   Follow the official install instructions here:
   http://docs.buildbot.net/latest/manual/installation/installation.html
3. Clone this directory to your desired master destination. A good choice on Ubuntu would be:
   `/srv/buildbot/master`
4. Create the master using:
   `buildbot create-master -r /srv/buildbot/master`
   `buildbot upgrade-master /srv/buildbot/master`
5. Start the master using:
   `buildbot start /srv/buildbot/master`
   Stop, restart and reconfig are the other most relevant commands.
6. For service persistence and convenience, consider using the systemd service file *util/buildbot-master.service*.
7. For https support and better HTTP performance overall, consider setting up Nginx as a reverse proxy, see *util/nginx.conf*.
8. Some build artefacts are uploaded from workers to the master for archival and debugging purposes. In our setup, they are placed in /srv/buildbot/bb_builds/. This directory is also exposed via nginx index listing at [ci.mariadb.org](https://ci.mariadb.org).

To upgrade Buildbot to latest version:
```bash
$ sudo systemctl stop buildbot-master
$ sudo pip3 install -U buildbot buildbot-grid-view buildbot-waterfall-view buildbot-console-view buildbot-wsgi-dashboards buildbot-www 
$ buildbot upgrade-master /srv/buildbot/master
$ buildbot cleanupdb /srv/buildbot/master
$ sudo systemctl start buildbot-master
```
To upgrade Buildbot-worker to latest version:
```bash
$ sudo pip3 install -U buildbot-worker
```

## Master configuration

The master configuration can be site specific and should be customized according to the needs and purpose for a particular master. What follows is a description of our current master configuration.

Master.cfg is a Python script and defines the behavior of Buildbot. These are the main sections of interest:

* PROJECT IDENTITY - various site specific definitions
* WORKERS - defines the list of recognized workers by this instance
* CHANGESOURCES - defines list of repositories to watch for changes
* SCHEDULERS - defines what changes we are interested in and triggers appropriate builders based on that
* BUILDERS & FACTORY CODE - defines the steps for any individual builder

Also, master.cfg sources a private config file that is not included in this repo, namely *master-private.cfg*. This file should include a Python dictionary with private information like worker passwords, database url and anything else not deemed for public disclosure.

### Reloading the master

For changes to the master.cfg to take effect, the server needs to be reloaded. While doing this, please keep an eye on the logs with `tail -f /srv/buildbot/master/twistd.log`. The Buildbot master is managed by our own rolled systemd file. To invoke a reload run `sudo systemctl reload buildbot-master`. The other usual systemctl are also available (`status`, `restart`). Before the reload, consider testing the config with `buildbot checkconfig`.

## Adding workers

There's currently two types of workers that we use. Normal Buildbot workers, running bare-bones builds and can be added using `c['workers'].append(mkWorker("bm-bbw1-ubuntu1804"))`. The password entry needs to be defined in `master-private.cfg`. Note that the worker name cannot be a hostname with dots. Only alphanumeric and dashes are allowed in the worker name.

For instructions on setting up a Buildbot Worker see http://docs.buildbot.net/latest/manual/installation/worker.html.

To add a buildbot worker use the following commands:
```
useradd buildbot
su - buildbot
python3 -m venv buildbot-worker
source buildbot-worker/bin/activate
pip install buildbot-worker
curl -o buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
#set buildmaster, port and worker user and password
buildbot-worker start
```

The other type of worker we use is [DockerLatentWorker](https://docs.buildbot.net/current/manual/configuration/workers-docker.html). It is useful for running tests inside single use, disposable container Linux instances. We are currently aiming to use it for most of our Linux builds.

Adding a Docker based worker is as simple as providing the IP address to the Docker server and everything else can be handled on the master side.

We currently have 2 Docker instances:
* `do-ubuntu-1804-bbw1-docker`: DigitalOcean worker 1 running Debian/Ubuntu (including main tarbake) builds
* `do-ubuntu-1804-bbw2-docker`: DigitalOcean worker 2 running Fedora, CentOS, OpenSuSe docker builds

This separation is purely conventional and can be arbitrarily implemented subject to available resources on each Docker host.

Sample DockerLatentWorker configuration:
```
c['workers'].append(worker.DockerLatentWorker("do-bbw1-docker-tarball", None,
                    docker_host='tcp://10.0.0.46:2375',
                    dockerfile=open("dockerfiles/debian.dockerfile").read(),
                    masterFQDN='buildbot.mariadb.org',
                    hostconfig={ 'shm_size':'500M' },
                    volumes=['/srv/buildbot/ccache:/mnt/ccache'],
                    properties={ 'jobs':'2' }))
```

## Current build matrix

We currently define a build matrix via _supportedPlatforms_ which specified which builders should we run for a particular change after figuring out which branch it is based on. For this particular reason, all branch names should follow the following naming scheme: `<version>-<suffix>` or `<prefix>-<version>-<suffix>`.

Examples
* `10.4` - main development branch that becomes the next 10.4.x release
* `10.0-galera` - main development branch that becomes the next 10.0.x Galera release
* `bb-10.3-feature` - feature branch targeting next 10.3.x release, tested by Buildbot normally
* `hf-5.5-fixbug` - hotfix branch targeting next 5.5.x release, **not** tested by Buildbot as it lacks bb-*


## Adding builders

http://docs.buildbot.net/latest/manual/cfg-builders.html
http://docs.buildbot.net/latest/manual/cfg-buildsteps.html

-TBD-

## Special Thanks

This project would not have gotten off the ground without the help and support
of Rasmus Johansson. We thank him for his many contributions to the community,
and remember him for his kindness, level headedness, and as an example for us
all.
