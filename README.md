# PHP-FPM

## What is PHP-FPM?

> PHP-FPM (FastCGI Process Manager) is an alternative PHP FastCGI implementation with some additional features useful for sites of any size, especially busier sites.

[Overview of PHP-FPM](http://php-fpm.org/)

Trademarks: The respective trademarks mentioned in this document are owned by the respective companies, and use of them does not imply any affiliation or endorsement.

## TL;DR

```console
$ docker run -it --name phpfpm -v /path/to/app:/app ghcr.io/bitcompat/php-fpm
```

## Supported tags

* `8.2`, `8.2-bullseye`, `8.2.11`, `8.1.11-bullseye`, `8.1.11-bullseye-r1`, `latest`
* `8.1`, `8.1-bullseye`, `8.1.24`, `8.1.24-bullseye`, `8.1.24-bullseye-r1`
* `8.0`, `8.0-bullseye`, `8.0.30`, `8.0.30-bullseye`, `8.0.30-bullseye-r6` 

## Get this image

The recommended way to get the PHP-FPM Image is to pull the prebuilt image from the [AWS Public ECR Gallery](https://gallery.ecr.aws/bitcompat/php-fpm) or from the [GitHub Container Registry](https://github.com/bitcompat/php-fpm/pkgs/container/php-fpm)

```console
$ docker pull ghcr.io/bitcompat/php-fpm:latest
```

To use a specific version, you can pull a versioned tag. You can view the [list of available versions](https://github.com/bitcompat/php-fpm/pkgs/container/php-fpm/versions) in the GitHub Registry or the [available tags](https://gallery.ecr.aws/bitcompat/php-fpm) in the public ECR gallery.


```console
$ docker pull ghcr.io/bitcompat/php-fpm:[TAG]
```

## Connecting to other containers

This image is designed to be used with a web server to serve your PHP app, you can use docker networking to create a network and attach all the containers to that network.

### Serving your PHP app through an nginx frontend

We will use PHP-FPM with nginx to serve our PHP app. Doing so will allow us to setup more complex configuration, serve static assets using nginx, load balance to different PHP-FPM instances, etc.

#### Step 1: Create a network

```console
$ docker network create app-tier --driver bridge
```

or using Docker Compose:

```yaml
version: '2'

networks:
  app-tier:
    driver: bridge
```

#### Step 2: Create a server block

Let's create an nginx server block to reverse proxy to our PHP-FPM container.

```nginx
server {
  listen 0.0.0.0:80;
  server_name myapp.com;

  root /app;

  location / {
    try_files $uri $uri/index.php;
  }

  location ~ \.php$ {
    # fastcgi_pass [PHP_FPM_LINK_NAME]:9000;
    fastcgi_pass phpfpm:9000;
    fastcgi_index index.php;
    include fastcgi.conf;
  }
}
```

Notice we've substituted the link alias name `myapp`, we will use the same name when creating the container.

Copy the server block above, saving the file somewhere on your host. We will mount it as a volume in our nginx container.

#### Step 3: Run the PHP-FPM image with a specific name

Docker's linking system uses container ids or names to reference containers. We can explicitly specify a name for our PHP-FPM server to make it easier to connect to other containers.

```console
$ docker run -it --name phpfpm \
  --network app-tier
  -v /path/to/app:/app \
 ghcr.io/bitcompat/php-fpm
```

or using Docker Compose:

```yaml
services:
  phpfpm:
    image: 'ghcr.io/bitcompat/php-fpm:latest'
    networks:
      - app-tier
    volumes:
      - /path/to/app:/app
```

#### Step 4: Run the nginx image

```console
$ docker run -it \
  -v /path/to/server_block.conf:/opt/bitnami/nginx/conf/server_blocks/yourapp.conf \
  --network app-tier \
  ghcr.io/bitcompat/nginx
```

or using Docker Compose:

```yaml
services:
  nginx:
    image: 'ghcr.io/bitcompat/nginx:latest'
    depends_on:
      - phpfpm
    networks:
      - app-tier
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - /path/to/server_block.conf:/opt/bitnami/nginx/conf/server_blocks/yourapp.conf
```

## PHP runtime

Since this image bundles a PHP runtime, you may want to make use of PHP outside of PHP-FPM. By default, running this image will start a server. To use the PHP runtime instead, we can override the the default command Docker runs by stating a different command to run after the image name.

### Entering the REPL

PHP provides a REPL where you can interactively test and try things out in PHP.

```console
$ docker run -it --name phpfpm ghcr.io/bitcompat/php-fpm php -a
```

**Further Reading:**

- [PHP Interactive Shell Documentation](http://php.net/manual/en/features.commandline.interactive.php)

## Running your PHP script

The default work directory for the PHP-FPM image is `/app`. You can mount a folder from your host here that includes your PHP script, and run it normally using the `php` command.

```console
$ docker run -it --name php-fpm -v /path/to/app:/app ghcr.io/bitcompat/php-fpm \
  php script.php
```

## Configuration

### Mount a custom config file

You can mount a custom config file from your host to edit the default configuration for the php-fpm docker image. The following is an example to alter the configuration of the _php-fpm.conf_ configuration file:

#### Step 1: Run the PHP-FPM image

Run the PHP-FPM image, mounting a file from your host.

```console
$ docker run --name phpfpm -v /path/to/php-fpm.conf:/opt/bitnami/php/etc/php-fpm.conf ghcr.io/bitcompat/php-fpm
```

#### Step 2: Edit the configuration

Edit the configuration on your host using your favorite editor.

```console
$ vi /path/to/php-fpm.conf
```

#### Step 3: Restart PHP-FPM

After changing the configuration, restart your PHP-FPM container for the changes to take effect.

```console
$ docker restart phpfpm
```

### Add additional .ini files

PHP has been configured at compile time to scan the `/opt/bitnami/php/etc/conf.d/` folder for extra .ini configuration files so it is also possible to mount your customizations there.

Multiple files are loaded in alphabetical order. It is common to have a file per extension and use a numeric prefix to guarantee an order loading the configuration.

Please check [http://php.net/manual/en/configuration.file.php#configuration.file.scan](http://php.net/manual/en/configuration.file.php#configuration.file.scan) to know more about this feature.

In order to override the default `max_file_uploads` settings you can do the following:

1. Create a file called _custom.ini_ with the following content:

```config
max_file_uploads = 30M
```

2. Run the php-fpm container mounting the custom file.

```console
$ docker run -it -v /path/to/custom.ini:/opt/bitnami/php/etc/conf.d/custom.ini ghcr.io/bitcompat/php-fpm php -i | grep max_file_uploads

```

You should see that PHP is using the new specified value for the `max_file_uploads` setting.

## Logging

The PHP-FPM Docker Image sends the container logs to the `stdout`. You can configure the containers [logging driver](https://docs.docker.com/engine/reference/run/#logging-drivers-log-driver) using the `--log-driver` option. By defauly the `json-file` driver is used.

To view the logs:

```console
$ docker logs phpfpm
```

*The `docker logs` command is only available when the `json-file` or `journald` logging driver is in use.*

## Maintenance

### Upgrade this image

Up-to-date versions of PHP-FPM are provided by Bitcompat project, including security patches, soon after they are made upstream. We recommend that you follow these steps to upgrade your container.

#### Step 1: Get the updated image

```console
$ docker pull ghcr.io/bitcompat/php-fpm:latest
```

#### Step 2: Stop and backup the currently running container

Stop the currently running container using the command

```console
$ docker stop php-fpm
```

or using Docker Compose:

```console
$ docker-compose stop php-fpm
```

Next, take a snapshot of the persistent volume `/path/to/php-fpm-persistence` using:

```console
$ rsync -a /path/to/php-fpm-persistence /path/to/php-fpm-persistence.bkp.$(date +%Y%m%d-%H.%M.%S)
```

You can use this snapshot to restore the database state should the upgrade fail.

#### Step 3: Remove the currently running container

```console
$ docker rm -v phpfpm
```

or using Docker Compose:

```console
$ docker-compose rm -v phpfpm
```

#### Step 4: Run the new image

Re-create your container from the new image.

```console
$ docker run --name phpfpm ghcr.io/bitcompat/php-fpm:latest
```

## Contributing

We'd love for you to contribute to this container. You can request new features by creating an [issue](https://github.com/bitcompat/php-fpm/issues), or submit a [pull request](https://github.com/bitcompat/php-fpm/pulls) with your contribution.

## Issues

If you encountered a problem running this container, you can file an [issue](https://github.com/bitcompat/php-fpm/issues/new).

## License

This package is released under MIT license.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
