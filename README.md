# Magento Demo Environment

## Prerequisites

* [Homebrew](https://brew.sh) package manager (for installing Warden)
* [Docker for Mac](https://hub.docker.com/editions/community/docker-ce-desktop-mac) or [Docker for Linux](https://docs.docker.com/install/linux/docker-ce/fedora/) (currently tested on Fedora 29)
* `docker-compose` available in your `$PATH` (included in Docker for Mac, can be installed via brew on Linux hosts)
* [Warden](https://warden.dev/) installed via Homebrew.

## Building Environment

1. Clone this repository.

        mkdir -p ~/Sites/m2demo
        git clone git@github.com:davidalger/m2demo.git ~/Sites/m2demo

2. Build and start the environment.

        ~/Sites/m2demo

3. Launch the site in your browser and login using information provided in the script output.

## License

This work is licensed under the MIT license. See LICENSE file for details.
