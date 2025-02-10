Nightscout Installer
=

This repository provides a means to install [Nightscout](https://nightscout.github.io/) and its dependencies as a set of containers, running in either [Docker](https://www.docker.com/) or [Podman](https://podman.io/) and with traffic proxied from the internet via a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/). This will provide you with a public instance of Nightscout in your own domain, available exclusively over HTTPS, with TLS/SSL certificates managed automatically. Please note that this setup requires you to have a [domain registered with Cloudflare](https://www.cloudflare.com/products/registrar/).

The optimal configuration is to run these components in rootless containers under Podman as services managed by systemd. This is both more secure and more robust than running rootful containers in Docker, and quite simple if you use this installer.

## Prerequisites

The first thing you need to do is to view your "Global API Key" in the [Cloudflare dashboard](https://dash.cloudflare.com/profile/api-tokens). Make a note of it somewhere as you will be prompted for it later. You should also [create separate zone and DNS tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) as described [here](https://github.com/caddy-dns/cloudflare?tab=readme-ov-file#configuration) and store them in a secure location, such as your password manager.

The second prerequisite is to [create a Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/). You have to give it a name (such as your second-level domain) and add two public hostnames: both your domain (e.g. example.com) and a dedicated nightscout subdomain (e.g. nightscout.example.com). You will need to edit both of these hostname entries to ensure that the corresponding service type is set to HTTPS, the URL to caddy:443, and (under "Additional application settings/TLS") the origin server name is set to your domain name (e.g. example.com).

Finally, you need a Linux server (or virtual machine) to run Nightscout and the various scripts included in this repository. They have been tested on Ubuntu and Fedora, so derivatives of those distros are likely to work too. If you do not want to use Podman, it is assumed that Docker (and Docker Compose) is installed already.

# Installation

The first few steps of the installation depend on which container runtime engine you wish to use.

## Docker

- Ensure that [Task](https://taskfile.dev/installation/) is installed
- Clone this repository and cd to the working directory
- Run ```task compose:up```

## Podman

- Download (curl or wget) [bootstrap.sh](https://github.com/swebster/nightscout-installer/raw/refs/heads/main/bootstrap.sh) from this repository
- Review the script, and if you are confident that it doesn't do anything untoward then mark it as executable and run it
- Run ```sudo machinectl shell podman@.host``` to start a shell as the new podman user
- Change directory to /home/podman/src/nightscout-installer
- Run ```task service:enable```

# Configuration

The remaining steps are almost the same regardless of whether you are using Docker or Podman.

- Respond to the prompts requesting your domain name, the Nightscout [API_SECRET](https://nightscout.github.io/nightscout/setup_variables/#api-secret-nightscout-password) that you want to use, Cloudflare tokens, etc.
- Wait for all of the container images to be pulled or built. Caddy can take a while...
- Run ```task``` to verify that the Nightscout container is up and running
- Navigate to your Nightscout URL (e.g. https://nightscout.example.com) in a browser and log in using the API_SECRET
- If you are using Podman, run ```task config:secrets:truncate``` to erase your API_SECRET from the local filesystem

You can then [configure Nightscout](https://nightscout.github.io/nightscout/profile_editor/) as normal. As you should not log in using the API_SECRET for regular use, be sure to to [create login tokens](https://nightscout.github.io/nightscout/security/#create-a-token) for your users. At minimum, you should create one token that has been granted the "readable" role for read-only access.

# Security

Nightscout sites created using this installer are only accessible over HTTPS, and then only using the API_SECRET or the login tokens you have created. However, you should consider providing additional protection from malicious traffic by defining custom rules for Cloudflare's [Web Application Firewall](https://developers.cloudflare.com/waf/custom-rules/) and review their other security options (such as [mTLS](https://developers.cloudflare.com/api-shield/security/mtls/)) as well.
