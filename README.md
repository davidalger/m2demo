# Magento Demo Environment

## Prerequisites

* [Warden](https://warden.dev/) 0.2.0 or later is installed. Reference documentation on [Installing Warden](https://docs.warden.dev/installing.html) for further info on Warden requirements and install procedures.

## Docker Images

The base images used by this demo environment can be found on Docker Hub or on Github at the following locations:

* https://github.com/davidalger/warden/tree/develop/images
* https://github.com/davidalger/docker-images-magento

## Building Environment

1. Clone this repository.

        mkdir -p ~/Sites/m2demo
        git clone git@github.com:davidalger/m2demo.git ~/Sites/m2demo

2. Build and start the environment (optionally passing the `--no-sampledata` flag):

        time ~/Sites/m2demo/start.sh

3. Launch the site in your browser and login using information provided in the script output.

## Destroying Environment

1. Change into the demo environment's local directory.

        cd ~/Sites/m2demo

2. Tear down containers, volumes, networks, etc.

        warden env down -v

## License

This work is licensed under the MIT license. See LICENSE file for details.
