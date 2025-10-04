# Seedbox-Ansible

This is an Ansible playbook designed to setup a fresh Ubuntu Virual Machine running on UNRAID. All you have to do is create a new Ubuntu VM in UNRAID, add the appriopriate shares to the VM and run the playbook!

## Table of Contents

- [Seedbox-Ansible](#seedbox-ansible)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Usage](#usage)
    - [General UNRAID Setup](#general-unraid-setup)
      - [UNRAID Permissions](#unraid-permissions)
    - [UNRAID VM Setup](#unraid-vm-setup)
    - [Ansible Setup](#ansible-setup)
    - [Run the playbook](#run-the-playbook)
  - [Configuration](#configuration)
    - [Miscellaneous Settings](#miscellaneous-settings)
    - [Logging Settings](#logging-settings)
    - [Container Settings](#container-settings)
    - [Downloader Settings](#downloader-settings)
    - [Shares](#shares)
    - [Extras](#extras)
      - [MAM](#mam)
    - [Indiviual Container Settings](#indiviual-container-settings)
      - [pia\_vpn](#pia_vpn)
      - [cleanuparr](#cleanuparr)
      - [radarr](#radarr)
      - [radarr\_2](#radarr_2)
      - [sonarr](#sonarr)
      - [sonarr\_2](#sonarr_2)
      - [huntarr](#huntarr)
      - [recyclarr](#recyclarr)
      - [notifiarr](#notifiarr)
      - [prowlarr](#prowlarr)
      - [flaresolverr](#flaresolverr)
      - [readarr\_audiobooks](#readarr_audiobooks)
      - [readarr\_ebooks](#readarr_ebooks)
      - [lazylibrarian](#lazylibrarian)
      - [bookbounty](#bookbounty)
      - [bazarr](#bazarr)
      - [kapowarr](#kapowarr)
      - [qbittorrent](#qbittorrent)
      - [qbittorrent\_porthelper](#qbittorrent_porthelper)
      - [qbittorrent\_managetorrents](#qbittorrent_managetorrents)
      - [sabnzbd](#sabnzbd)
      - [firefox](#firefox)
      - [portainer](#portainer)
      - [watchtower](#watchtower)
      - [syncthing](#syncthing)
      - [Health Check Settings](#health-check-settings)
  - [Containers](#containers)
  - [Post-Installation Configuration](#post-installation-configuration)
  - [Disclaimer](#disclaimer)
  - [License](#license)
  - [Support](#support)

## Features

- Enable/Disable all containers individually
- Mounts UNRAID shares to VM so all of the containers have the have path to the media (removes the need for Remote Path Mapping)
- Optional PIA VPN container that routes all neccessary traffic through the VPN
- qBittorrent portHelper container that automatically updates the port for qBittorrent based on the port that is forwarded by the PIA VPN container
- qBittorrent manageTorrents container that automatically sends torrents that are slow/hanging to the bottom of the queue; then eventually removes them if they remain slow/hanging
- Recyclarr or Notifiarr for automatically configuring your Sonarr and Radarr instances to follow the TRaSH guides
- Multiple instances of readarr. One for audiobooks and one for ebooks
- Multiple instances of Radarr and Sonarr.
- Firefox instance behind the VPN for manually searching for torrents
- Syncthing for backing up your data to a remote server
- Autoheal for automatically restarting containers that have become unhealthy
- Watchtower for automatically updating containers
- Portainer for a gui for managing all of the containers
- Optional feature to automatically update your VPN IP in your MAM account

## Usage

### General UNRAID Setup

There are really only two ways that I have seen people do this.
1. Create a share for each of the media folders that you have. For example: downloads, anime, audiobooks, ebooks, movies, tv shows, etc.
   -  This is the way I do it. I like having the separation
2. Create a single media share and then create a sub-directory for each of the media folders that you have.

> [!IMPORTANT]
> **If you have a cache/buffer pool:**
>   - You should add a share called `Staging` and set it to only use your cache/buffer pool. This is the share that your downloads should be configured to use for their temporary storage while they are downloading. Their completed download location should be set to the `Downloads` share
>   - All of the other media shares should be set to use only the array
>   - This is because hardlinks only work when the files are on the same filesystem, they do not work between the array and the cache/buffer pool. This does mean that your write speeds will be slower but things will hardlink rather than copy (which uses more space)

#### UNRAID Permissions

I have the `User Scripts` plugin installed in UNRAID running the following script hourly. This ensures that there are no permission issues with the media files.

I know that this not "best practice" but it works for me.

The script is a bit overengineered but it allows me to quickly change permissions of my shares if I need to. It sets all of the media shares to `777` and has the option to set the rest of the shares to `775`/`774` if you need to.

```bash
#!/bin/bash

name=""
puid="nobody"
pgid=""
dir_perms=""
file_perms=""

og="$puid:$pgid"

updated_shares=()

function isShareUpdated() {
    local share
    for share in "${updated_shares[@]}"; do
        [[ "$share" == "$1" ]] && return 0
    done
    return 1
}

function setDirPerms() {
    directory=$1

    echo "[$name] Setting directory perms for $directory to $dir_perms..."
    find "$directory" -type d -exec chmod $dir_perms {} +
}

function setFilePerms() {
    directory=$1

    echo "[$name] Setting file perms for $directory to $file_perms..."
    find "$directory" -type f -exec chmod $file_perms {} +
}

function setOwnerGroup() {
    directory=$1

    echo "[$name] Setting owner:group for $directory to $og..."
    chown -R $og "$directory"
}

function setBothPerms() {
    directory=$1

    echo "[$name] Setting perms for $directory to $dir_perms..."
    chmod -R $dir_perms "$directory"
}

function setPerms() {
    setOwnerGroup "$1"

    if [ "$dir_perms" == "$file_perms" ]; then
        setBothPerms "$1"
    else
        setDirPerms "$1"

        setFilePerms "$1"
    fi
}

function setSharePerms() {
    directory=/mnt/user/$1

    if isShareUpdated "$1"; then
        echo "Share $1 has already been updated!! Remove the the duplicate from the script"
    else
        updated_shares+=("$1")

        setPerms "$directory"
    fi
}

function setVars() {
    name=$1
    pgid=$2
    dir_perms=$3
    file_perms=$4

    og="$puid:$pgid"

    echo -e "\n"
}

function updateAllRemainingShares() {
    for folder in /mnt/user/*/; do
        folder_name=$(basename "$folder")

        if ! isShareUpdated "$1"; then
            setSharePerms "$folder_name"
        fi
    done
}

# Media Shares
setVars "Media" "users" "777" "777"

setSharePerms "movies"
setSharePerms "movie_editions"
setSharePerms "tv"
setSharePerms "anime"
setSharePerms "downloads"
setSharePerms "staging"
setSharePerms "audiobooks"
setSharePerms "books"
setSharePerms "podcasts"


# Defaults
# setVars "Share" "users" "775" "774"
# updateAllShares

echo "Done Setting Permissions!"
```

### UNRAID VM Setup

1. Create a new VM and pick Ubuntu as the OS
2. Give it a name, assign the logical CPUs (Id recommend atleast 4 if have the resources), and assign the memory (4GB probably would be enough but I recommend 8GB)
3. Select the OS iso from the list. If you don't have any isos in the list, you will need to download one and add it to the isos share
4. For the vdisk, select `Auto` and then specify the size of the vdisk (I recommend at least 50GB)
5. Add a Manual Share with the source path of `/mnt/user` (`mnt/user/media` if its all under a single share) and a mount tag of something like `Shares`. Rememeber what you set the mount tag to, you will need it later.
   - Make sure to set the mode to `virtiofs` (9p is the default but virtiofs is better)
6. Turn on `VM Console enable Copy/paste` this will make it a lot easier for filling in some of the settings
7. Create the VM and go through the Ubuntu install process (I recommend using the default settings)

### Ansible Setup

1. Install git if not already installed

```bash
sudo apt update
sudo apt install git
```

2. Clone this repo

```bash
git clone https://github.com/TheDataDen/Seedbox-Ansible.git
cd Seedbox-Ansible
```

> [!NOTE]
> If you already have run this playbook before and are updating, you probably wouldn't be able to run `git pull` because of the changes you made to the `vars/main.yml` file.
> To fix this, run `git stash` to stash your changes, then run `git pull` and then run `git stash pop` to restore your changes. There may be merge conflicts for the `vars/main.yml` file, make sure to scan through the file and fix any conflicts.

3. Modify the [vars/main.yml](vars/main.yml) file to match your setup. Check out the [Configuration](#configuration) section for more information

### Run the playbook

The [run.sh](run.sh) script will install Ansible and tmux, create a tmux session, and run the playbook. The tmux session will be called `Seedbox-Ansible`, and can be re-attached to at any time in case you lose connectivity.

To detach from the tmux session, press `Ctrl+B` then `D`.

To re-attach to the tmux session run the following script: `./attach.sh`

```bash
./run.sh
```

> [!NOTE]
> The Create Seedbox Docker stack step may look like it is hanging. This is because the docker images need to be downloaded. If you are on a slow internet connection, this may take a while.
>
> If it hangs on `Gathering Facts` then you most likely entered your password incorrectly. Ctrl+C to exit and try again.

## Configuration

The playbook is configured using the [vars/main.yml](vars/main.yml) file.

Make sure to replace all instances of `REPLACEME` with the appropriate values.

### Miscellaneous Settings

| Variable Name | Required | Description                                                                                    |
| ------------- | -------- | ---------------------------------------------------------------------------------------------- |
| `docker_user` | Yes      | The user that you created on the Ubuntu VM                                                     |
| `host_ip`     | Yes      | The IP address of the VM.                                                                      |
| `timezone`    | Yes      | The Timezone that you are in                                                                   |
| `puid`        | Yes      | The UID of the user that will run the docker containers. (Probably doesn't need to be changed) |
| `pgid`        | Yes      | The GID of the user that will run the docker containers. (Probably doesn't need to be changed) |
| `umask`       | Yes      | The umask that will be used for the docker containers. (Probably doesn't need to be changed)   |

### Logging Settings

| Variable Name              | Required | Description                      |
| -------------------------- | -------- | -------------------------------- |
| `logging.driver`           | Yes      | The Docker logging driver.       |
| `logging.options.max_size` | Yes      | The max size of the log.         |
| `logging.options.max_file` | Yes      | The max number of files to keep. |

### Container Settings

| Variable Name                | Required | Description                                              |
| ---------------------------- | -------- | -------------------------------------------------------- |
| `pia_vpn`                    | No       | Enable/Disable the PIA VPN container.                    |
| `cleanuparr`                 | No       | Enable/Disable the Cleanuperr container.                 |
| `radarr`                     | No       | Enable/Disable the Radarr container.                     |
| `radarr_2`                   | No       | Enable/Disable the Second Radarr container.              |
| `sonarr`                     | No       | Enable/Disable the Sonarr container.                     |
| `sonarr_2`                   | No       | Enable/Disable the Second Sonarr container.              |
| `huntarr`                    | No       | Enable/Disable the Huntarr container.                    |
| `recyclarr`                  | No       | Enable/Disable the Recyclarr container.                  |
| `notifiarr`                  | No       | Enable/Disable the Notifiarr container.                  |
| `prowlarr`                   | No       | Enable/Disable the Prowlarr container.                   |
| `flaresolverr`               | No       | Enable/Disable the FlareSolverr container.               |
| `readarr_audiobooks`         | No       | Enable/Disable the readarr_audiobooks container.         |
| `readarr_ebooks`             | No       | Enable/Disable the readarr_ebooks container.             |
| `lazylibrarian`              | No       | Enable/Disable the Lazylibrarian container.              |
| `bookbounty`                 | No       | Enable/Disable the Bookbounty container.                 |
| `bazarr`                     | No       | Enable/Disable the Bazarr container.                     |
| `kapowarr`                   | No       | Enable/Disable the Kapowarr container.                   |
| `qbittorrent`                | No       | Enable/Disable the qBittorrent container.                |
| `qbittorrent_managetorrents` | No       | Enable/Disable the qBittorrent manageTorrents container. |
| `sabnzbd`                    | No       | Enable/Disable the SABnzbd container.                    |
| `portainer`                  | No       | Enable/Disable the Portainer container.                  |
| `watchtower`                 | No       | Enable/Disable the Watchtower container.                 |
| `autoheal`                   | No       | Enable/Disable the Autoheal container.                   |
| `syncthing`                  | No       | Enable/Disable the Syncthing container.                  |

### Downloader Settings

| Variable Name                    | Required | Description                                                       |
| -------------------------------- | -------- | ----------------------------------------------------------------- |
| `downloaders.staging.enabled`    | Yes      | Enable/Disable the staging share                                  |
| `downloaders.staging.share_name` | Yes      | The name of the share that will be used for the staging downloads |

### Shares

| Variable Name      | Required | Description                                                        |
| ------------------ | -------- | ------------------------------------------------------------------ |
| `shares.mount_tag` | Yes      | The tag that will be used for the UNRAID shares when passed to VM. |

### Extras

#### MAM

| Variable Name    | Required | Description                                                                                                                             |
| ---------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`        | Yes      | Enable/Disable the MAM script to run with the VPN comes up                                                                              |
| `session_cookie` | Yes      | The MAM session cookie that will be used to login to MAM. Only needs to be set for the first run, after that a cookie file will be used |

### Indiviual Container Settings

#### pia_vpn

| Variable Name   | Required | Description                                                                                                        |
| --------------- | -------- | ------------------------------------------------------------------------------------------------------------------ |
| `local_network` | Yes      | The local network that the PIA VPN container will use.                                                             |
| `username`      | Yes      | The username that will be used to connect to the PIA VPN container.                                                |
| `password`      | Yes      | The password that will be used to connect to the PIA VPN container.                                                |
| `server_loc`    | No       | The location of the PIA server. If using Dedicated IP, this should be commented out with a `#`.                    |
| `dip_token`     | No       | The DIP token of the PIA server. If NOT using Dedicated IP, this should be commented out with a `#`.               |
| `port_fatal`    | No       | Enables the port_fatal option for the PIA VPN container. If the VPN port forward fails, the container will exit.   |
| `port_persist`  | No       | Enables the port_persist option for the PIA VPN container. The container will try to use the same port every time. |

#### cleanuparr

| Variable Name                  | Required | Description                                                                                        |
| ------------------------------ | -------- | -------------------------------------------------------------------------------------------------- |
| `dry_run`                      | Yes      | If true, the container will not actually clean up the files. Use this to verify your setup.        |
| `ignored`                      | Yes      | A list of ignored tags, categories, and torrents. The file will be created if it doesn't exist.    |
| `sonarr.list_type`             | Yes      | Either `blacklist` or `whitelist`. The type of list that will be used for blocking bad files.      |
| `sonarr.list`                  | Yes      | The path to the file that contains the list of blocked files. Can either be local or an url.       |
| `radarr.list_type`             | Yes      | Either `blacklist` or `whitelist`. The type of list that will be used for blocking bad files.      |
| `radarr.list`                  | Yes      | The path to the file that contains the list of blocked files. Can either be local or an url.       |
| `notifiarr.discord_channel_id` | Yes      | The ID of the discord channel that notifiarr will post to.                                         |
| `search.enabled`               | Yes      | If true, the container will search for replacements after a download has been removed from an arr. |
| `search.delay`                 | Yes      | The delay before the search is performed. Helps to prevent spamming the indexer.                   |
| `queue_cleaner.enabled`        | Yes      | If true, the container will clean up the queue.                                                    |
| `queue_cleaner.triggers`       | Yes      | The cron schedule that controls when the queue cleaner will run.                                   |
| `content_blocker.enabled`      | Yes      | If true, the container will block files that are not allowed.                                      |
| `content_blocker.triggers`     | Yes      | The cron schedule that controls when the content blocker will run.                                 |
| `download_cleaner.enabled`     | Yes      | If true, the container will clean up files that have finished seeding.                             |
| `download_cleaner.triggers`    | Yes      | The cron schedule that controls when the download cleaner will run.                                |
| `download_cleaner.ratio`       | Yes      | The ratio that the download cleaner will use to determine if a file is finished seeding.           |

#### radarr

| Variable Name   | Required | Description                                      |
| --------------- | -------- | ------------------------------------------------ |
| `port`          | Yes      | The port that Radarr's webUI will be running on. |
| `instance_name` | No       | The name that will appear in the browser tab.    |

#### radarr_2

| Variable Name   | Required | Description                                                 |
| --------------- | -------- | ----------------------------------------------------------- |
| `port`          | Yes      | The port that the second Radarr's webUI will be running on. |
| `instance_name` | No       | The name that will appear in the browser tab.               |

#### sonarr

| Variable Name   | Required | Description                                      |
| --------------- | -------- | ------------------------------------------------ |
| `port`          | Yes      | The port that Sonarr's webUI will be running on. |
| `instance_name` | No       | The name that will appear in the browser tab.    |

#### sonarr_2

| Variable Name   | Required | Description                                                 |
| --------------- | -------- | ----------------------------------------------------------- |
| `port`          | Yes      | The port that the second Sonarr's webUI will be running on. |
| `instance_name` | No       | The name that will appear in the browser tab.               |

#### huntarr

| Variable Name | Required | Description                                       |
| ------------- | -------- | ------------------------------------------------- |
| `port`        | Yes      | The port that Huntarr's webUI will be running on. |

#### recyclarr

| Variable Name   | Required | Description                                               |
| --------------- | -------- | --------------------------------------------------------- |
| `version`       | Yes      | The version of Recyclarr to use.                          |
| `cron_schedule` | Yes      | The cron schedule that controls how often Recyclarr runs. |

#### notifiarr

| Variable Name | Required | Description                                         |
| ------------- | -------- | --------------------------------------------------- |
| `port`        | Yes      | The port that Notifiarr's webUI will be running on. |
| `api_key`     | Yes      | The API key for your Notifiarr account.             |

#### prowlarr

| Variable Name | Required | Description                                        |
| ------------- | -------- | -------------------------------------------------- |
| `port`        | Yes      | The port that Prowlarr's webUI will be running on. |

#### flaresolverr

| Variable Name | Required | Description                                    |
| ------------- | -------- | ---------------------------------------------- |
| `port`        | Yes      | The port that FlareSolverr will be running on. |

#### readarr_audiobooks

| Variable Name   | Required | Description                                                  |
| --------------- | -------- | ------------------------------------------------------------ |
| `port`          | Yes      | The port that readarr_audiobooks's webUI will be running on. |
| `instance_name` | Yes      | The name that will appear in the browser tab.                |

#### readarr_ebooks

| Variable Name   | Required | Description                                              |
| --------------- | -------- | -------------------------------------------------------- |
| `port`          | Yes      | The port that readarr_ebooks's webUI will be running on. |
| `instance_name` | Yes      | The name that will appear in the browser tab.            |

#### lazylibrarian

| Variable Name | Required | Description                                                                               |
| ------------- | -------- | ----------------------------------------------------------------------------------------- |
| `port`        | Yes      | The port that Lazylibrarian's webUI will be running on.                                   |
| `docker_mods` | No       | The mods that will be used for Lazylibrarian. Default enables calibre-importer and ffmpeg |

#### bookbounty

| Variable Name               | Required | Description                                                                                  |
| --------------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `port`                      | Yes      | The port that Bookbounty's webUI will be running on.                                         |
| `sync_schedule`             | Yes      | The cron schedule that controls how often Bookbounty syncs. 24h format, comma seperated list |
| `selected_language`         | Yes      | The language that Bookbounty will sync. Default is English                                   |
| `preferred_ext_fiction`     | Yes      | The preferred extensions for fiction. Comma sperated list.                                   |
| `preferred_ext_non_fiction` | Yes      | The preferred extensions for non-fiction. Comma sperated list.                               |
| `selected_path_type`        | Yes      | The path type that Bookbounty will use. Either `file` or `folder`                            |
| `download_path`             | Yes      | The path that Bookbounty will download to.                                                   |

#### bazarr

| Variable Name | Required | Description                                      |
| ------------- | -------- | ------------------------------------------------ |
| `port`        | Yes      | The port that Bazarr's webUI will be running on. |

#### kapowarr

| Variable Name | Required | Description                                        |
| ------------- | -------- | -------------------------------------------------- |
| `port`        | Yes      | The port that Kapowarr's webUI will be running on. |

#### qbittorrent

| Variable Name  | Required | Description                                                                                                                                                                 |
| -------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `port`         | Yes      | The port that qBittorrent's webUI will be running on.                                                                                                                       |
| `sub_dir_name` | Yes      | The name of the sub directory that will be created under the staging share.                                                                                                 |
| `host`         | No       | The host ip that qBittorrent will be running on. Don't change this unless it different from the host IP. Only required if using the porthelper or managetorrents containers |
| `username`     | No       | The username that will be used to connect to qBittorrent. Only required if using the porthelper or managetorrents containers                                                |
| `password`     | No       | The password that will be used to connect to qBittorrent. Only required if using the porthelper or managetorrents containers                                                |

#### qbittorrent_porthelper

| Variable Name         | Required | Default | Description                                          |
| --------------------- | -------- | ------- | ---------------------------------------------------- |
| `update_time_seconds` | No       | `60`    | The time in seconds between each update of the port. |

#### qbittorrent_managetorrents

| Variable Name         | Required | Default | Description                                             |
| --------------------- | -------- | ------- | ------------------------------------------------------- |
| `update_time_seconds` | No       | `120`   | The time in seconds between each check of the torrents. |

#### sabnzbd

| Variable Name  | Required | Description                                                                 |
| -------------- | -------- | --------------------------------------------------------------------------- |
| `port`         | Yes      | The port that SABnzbd's webUI will be running on.                           |
| `sub_dir_name` | Yes      | The name of the sub directory that will be created under the staging share. |


#### firefox

| Variable Name | Required | Description                                       |
| ------------- | -------- | ------------------------------------------------- |
| `port`        | Yes      | The port that Firefox's webUI will be running on. |
| `shm_size`    | Yes      | The size of the shared memory for Firefox.        |

#### portainer

| Variable Name | Required | Description                                         |
| ------------- | -------- | --------------------------------------------------- |
| `port`        | Yes      | The port that Portainer's webUI will be running on. |

#### watchtower

| Variable Name   | Required | Description                                                                                                                                               |
| --------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cron_schedule` | Yes      | The cron schedule that Watchtower will use to check for updates. Use [Crontab.guru](https://crontab.guru/) for help creating a cron. Example: `0 5 * * *` |

#### syncthing

| Variable Name | Required | Description                                         |
| ------------- | -------- | --------------------------------------------------- |
| `gui_port`    | Yes      | The port that Syncthing's webUI will be running on. |

#### Health Check Settings

Used for all of the health checks except for the pia_vpn health check

| Variable Name  | Required | Description                                                                  |
| -------------- | -------- | ---------------------------------------------------------------------------- |
| `interval`     | Yes      | How often the health of a container is checked                               |
| `timeout`      | Yes      | The timeout for each health check until the healthcheck is considered failed |
| `retries`      | Yes      | The number of retries before the container is marked as unhealthy            |
| `start_period` | Yes      | The delay after the container start until the healthcheck starts             |

## Containers

Below is a list of all of the containers that are available to be enabled/disabled with a description of what they do.

| Container Name               | Description                                                                                                                                                                                                |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pia_vpn`                    | Runs a Private Internet Access VPN where all of the traffic for the neccessary containers are routed through the vpn. If the VPN loses connection, the containers lose access to the internet              |
| `cleanuparr`                 | Automatically cleans up files from your downloads and prevents downloads from clogging up the queue                                                                                                        |
| `radarr`                     | For managing your movies                                                                                                                                                                                   |
| `radarr_2`                   | For managing your movies. Second instance. Possible uses: 4K versions, IMAX versions, multiple editions, etc.                                                                                              |
| `sonarr`                     | For managing your TV shows/Anime                                                                                                                                                                           |
| `sonarr_2`                   | For managing your TV shows/Anime. Second instance. Poissible uses: 4K versions, multiple editions, etc.                                                                                                    |
| `huntarr`                    | For automatically search for Movies/Shows/Books that are not recently released. Sonarr/Radarr works off of RSS feeds so older content that might be added to an indexer is not automatically searched for. |
| `recyclarr`                  | For automatically configuring your Sonarr and Radarr instances to follow the TRaSH guides                                                                                                                  |
| `notifiarr`                  | For automatically configuring your Sonarr and Radarr instances to follow the TRaSH guides. As well as monitoring tools.                                                                                    |
| `prowlarr`                   | For managing your torrents. As well as updating the indexers on Radarr, Sonarr, and Readarr                                                                                                                |
| `flaresolverr`               | Used in Prowlarr as a proxy server to bypass Cloudflare and DDoS-GUARD protection                                                                                                                          |
| `readarr_audiobooks`         | For managing your audiobooks                                                                                                                                                                               |
| `readarr_ebooks`             | For managing your ebooks                                                                                                                                                                                   |
| `lazylibrarian`              | For managing your ebooks and audiobooks. An alternative to readarr                                                                                                                                         |
| `bookbounty`                 | For downloading ebooks that Readarr can't find                                                                                                                                                             |
| `bazarr`                     | Automatically downloads external subtitles for your movies, TV Shows, and Anime                                                                                                                            |
| `kapowarr`                   | For managing your comics                                                                                                                                                                                   |
| `qbittorrent`                | Downloads torrents                                                                                                                                                                                         |
| `qbittorrent_porthelper`     | Used with the PIA VPN and qBittorrent to set the qBittorrent port used for incoming connection to the port that is forwarded by PIA                                                                        |
| `qbittorrent_managetorrents` | Used with qBittorrent to automatically send torrents that are slow/hanging to the bottom of the queue; then eventually removes them                                                                        |
| `sabnzbd`                    | Downloads NZBs (Usenet)                                                                                                                                                                                    |
| `firefox`                    | A Firefox instance that is used for manually searching for torrents                                                                                                                                        |
| `portainer`                  | A WebGUI for managing all of the docker containers                                                                                                                                                         |
| `watchtower`                 | Automatically updates the containers to their latest versions. Runs on a cron schedule                                                                                                                     |
| `autoheal`                   | Automatically restarts any container that becomes unhealthy                                                                                                                                                |
| `syncthing`                  | Add the ability to sync files with a remote server                                                                                                                                                         |

## Post-Installation Configuration

All instances of Sonarr and Radarr should be configured under `Media Management` to set the file perms to `777` and the group to `100`.

Sabnzbd should be configured to set the perms to `777`.

## Disclaimer

This project is provided as-is, without any warranties or guarantees. By using this project, you acknowledge and agree that:

- **I am not responsible for any VPN leaks, IP exposure, or other privacy breaches** that may occur while using this software.
- **It is your responsibility to ensure your VPN setup is secure** and functioning properly to avoid any leaks or unintended exposure of your activity.
- **I am not liable for any legal consequences, fines, or actions** taken by your ISP, government, or any other entity as a result of your use of this project.
- **Downloading, sharing, or accessing copyrighted content without proper authorization** may be illegal in your jurisdiction. You are solely responsible for understanding and complying with the laws applicable in your location.

Use this software at your own risk.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please open an issue in this repository.
