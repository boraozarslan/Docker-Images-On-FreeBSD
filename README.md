# Docker Images On FreeBSD

This repository explains how to download and run docker images on FreeBSD.

### Disclaimer

These scripts are written for downloading Docker images to test the Linuxulator. For a more serious use, they should undergo more scrutiny.

## Getting Started

### Prerequisites

Setup linuxulator as docker will only download linux binaries.

Here is how I setup the linuxulator which might not be complete but worked\
enough for my case to not be a problem.

First load the Linux kernel modules:

```
$ kldload linux
$ kldload linux64
```

Download a set of linux libraries:

```
$ pkg install linux-c7
```

Which should tell you this message but I included here anyways.

```
Some programs need linprocfs mounted on /compat/linux/proc.  Add the
following line to /etc/fstab:

linprocfs   /compat/linux/proc	linprocfs	rw	0	0

Then run "mount /compat/linux/proc".

Some programs need linsysfs mounted on /compat/linux/sys.  Add the
following line to /etc/fstab:

linsysfs    /compat/linux/sys	linsysfs	rw	0	0

Then run "mount /compat/linux/sys".

Some programs need tmpfs mounted on /compat/linux/dev/shm.  Add the
following line to /etc/fstab:

tmpfs    /compat/linux/dev/shm	tmpfs	rw,mode=1777	0	0

Then run "mount /compat/linux/dev/shm".
```

Linuxulator now should be ready to go. Note that if you would like to run any of your own
linux binaries you might need to run `$ brandelf -t Linux <binary>`.

Download the following packages as they're required by the scripts:

```
sudo
bash
jq
curl
go
```

Download the following script that can download images from docker:

[download-frozen-image-v2.sh](https://github.com/moby/moby/blob/master/contrib/download-frozen-image-v2.sh)

Change the `sha256sum` to `sha256` at line 109.
If you don't put this into the same folder as the project or if you change the name, you will
need to change the `docker-pull.sh` script to use the correct script.

## Scripts

The general use of these scripts is

```
$ ./docker-pull.sh gcc latest
$ cd gcc
$ ../docker-run.sh
```

Then evaluate the last output to know what to run.

### Docker-pull.sh

`docker-pull` will pull and setup the docker image specified.

The usage is

```
$ docker-pull [username] <image-name> <tag>
```

If the image is an official image then the username is left blank.

For example:

```
$ docker-pull ubuntu latest
```

This script will first create a new directory with the same name as the image's name which it will place everything new in.
Then it will download image's files inside a directory named images-files.
Then it will untar all the image's files into a directory called fs. fs is essentially the root directory.
We then use brandelf to brand all ELF files to have linux tags. This is required because FreeBSD needs this tag to run binaries as Linux binaries.
However, Linux usually leaves this as field empty (as 0).
Then as the last step the script handles all the required mounts.

Note that currently user images return an authentication error.

### Docker-run.sh

docker-run will try to figure out what command would run when `docker run` command is used.

The usage is

```
$ docker-run
```

Note that it should be used one level below the fs directory created with docker-pull.

To figure out the command, docker-run will look at the `manifest.json` file in the image-files folder.
Then it will look at the specified config file which is again in json format.
It will then generate the exact command that can be copied and used to run the image.
It will also print out the expected environment variables. Some programs will need these
environment variables so if the program fails this could be the reason.

[Here](http://goinbigdata.com/docker-run-vs-cmd-vs-entrypoint/) is a link explaining how docker decides what to run. `docker-run` is written with this in mind.

## Tested Containers

The following containers from the Docker Hub have been tested to see if they work.
Note that none of the tests were exhaustive but were smoke tests.

### Passed

* busybox
* alpine
* node
* hello-world
* gcc
* nginx
* pypy
* bash
* rust
* php
* python
* ubuntu

### Failed

Note that some of these failures are because of my lack of knowledge of the underlying application.

* couchbase - The errors are hard to trace because couchbase outputs it's own errors by printing out each character, essentially hiding the error message from the linuxulator by generating too many error messages while tracing.
* postgres - Needs some configuration.
* wordpress - The default configuration seems to fail. It is trying to load two modules that require the other to not be loaded. However, unloading either doesn't seem to fix the problem.
* redis - linprocfs uses pseudo file system. Since redis is trying to use `linux_fchownat` via the pseudo fs it fails. This is because `pfs_setattr` isn't implemented.
* debian - `apt-get install` fails because ioctl isn't fully implemented.
* traefik - Leads to an error saying `Error creating server: accept tcp: accept4: address family not supported by protocol`. The only failing function seems to be `linux_accept4` which is returning an error of `EAGAIN`.
* openjdk - Fails on startup.

## Sources

* [Notes on Linuxulator on FreeBSD](https://www.bsdcan.org/2018/schedule/attachments/473_linuxulator-notes-bsdcan2018.txt)
* [FreeBSD Handbook - Linux Binary Compatibility](https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/linuxemu.html)
* [Linuxulator on FreeBSD wiki](https://wiki.freebsd.org/linux-kernel)
* [Linux emulation in FreeBSD by Roman Divacky](https://www.freebsd.org/doc/en_US.ISO8859-1/articles/linux-emulation/article.html)
* [`docker run`'s behaviour](http://goinbigdata.com/docker-run-vs-cmd-vs-entrypoint/)

## Authors

* **Bora Ozarslan** - borako.ozarslan at gmail dot com (Feel free to email any questions)

## License

This project is licensed under the BSD-2-clause.

## Acknowledgments

* [Thanks to the people who wrote the docker image download script](https://github.com/moby/moby)
* Thanks Ed Maste for responding to my every question.
* Thanks to everyone who explained how these programs behave.

