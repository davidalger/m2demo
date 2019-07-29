# Magento Demo Environment

## Prerequisites

* [Homebrew](https://brew.sh/) package manager (for installing Warden and other dependencies)
* [Docker for Mac](https://hub.docker.com/editions/community/docker-ce-desktop-mac) or [Docker for Linux](https://docs.docker.com/install/) (tested on Fedora 29 and Ubuntu 18.10)
* `docker-compose` available in your `$PATH` (included with Docker for Mac, can be installed via `brew`, `apt` or `dnf` on Linux)
* [Warden](https://warden.dev/) installed via Homebrew.

## Building Environment

1. Clone this repository.

        mkdir -p ~/Sites/m2demo
        git clone git@github.com:davidalger/m2demo.git ~/Sites/m2demo

2. Build and start the environment.

        time ~/Sites/m2demo/start.sh

3. Launch the site in your browser and login using information provided in the script output.

## Destroying Environment

1. Change into the demo environment's local directory.

        cd ~/Sites/m2demo

2. Tear down containers, volumes, networks, etc.

        warden env down -v

## License

This work is licensed under the MIT license. See LICENSE file for details.
