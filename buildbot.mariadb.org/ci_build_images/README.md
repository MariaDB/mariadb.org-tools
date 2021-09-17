# Dockerfiles for BB workers

## manually build containers

Command line example to manually build containers:

```console
# debian
cat debian.Dockerfile common.Dockerfile >/tmp/Dockerfile
docker build . -f /tmp/Dockerfile --build-arg mariadb_branch=10.7 --build-arg base_image=debian:sid
# ubuntu
cat debian.Dockerfile common.Dockerfile >/tmp/Dockerfile
docker build . -f /tmp/Dockerfile --build-arg mariadb_branch=10.7 --build-arg base_image=ubuntu:21.04
# fedora
cat fedora.Dockerfile common.Dockerfile >/tmp/Dockerfile
docker build . -f /tmp/Dockerfile --build-arg base_image=fedora:34
# rhel8
cat rhel8.Dockerfile common.Dockerfile >/tmp/Dockerfile
docker build . -f /tmp/Dockerfile --build-arg "rhel_user=user" --build-arg "rhel_pwd=password"
```

## search for missing dependencies

apt:

```bash
for pkg in $(cat list.txt); do echo -e "\n$pkg: $(dpkg -l | grep "$pkg")"; done
```

rpm:

```bash
for pkg in $(cat list.txt); do echo -e "\n$pkg: $(rpm -qa | grep "$pkg")"; done
```

## Best practice

### Sort and remove duplicate packages

One package by line, see:
<https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#sort-multi-line-arguments>

Use the following in vim:

```vim
:sort u
```

### Use hadolint tool to verify the dockerfile

```console
docker run -i -v $(pwd):/mnt -w /mnt hadolint/hadolint:latest hadolint /mnt/fedora.Dockerfile
```
