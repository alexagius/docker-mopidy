FROM debian:bookworm-slim

######################################
########### Mopidy setup ###########

COPY Pipfile Pipfile.lock /


RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt update \
 && DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        gnupg \
        python3-distutils \
        python3-venv \
        python3-pip \
        pipx \
        wget \
 && pipx install pipenv \
 && mkdir -p /etc/apt/keyrings \
 && wget -q -O /etc/apt/keyrings/mopidy-archive-keyring.gpg \
        https://apt.mopidy.com/mopidy.gpg \
 && wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/bookworm.list \
 && wget -q -O - https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && apt update

RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt update \
 && pip3 config set global.break-system-packages true \
 && DEBIAN_FRONTEND=noninteractive apt install -y \
        mopidy \
        mopidy-mpd \
        mopidy-soundcloud \
    # Spotify is seemingly not a pacakge anymore
 && pip3 install Mopidy-Spotify==5.0.0a3 \
 && pip3 install pipenv \
 && pipenv install --system --deploy \
 && apt purge --auto-remove -y \
        gcc \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# custom gst-plugin for spotify
# see: https://github.com/mopidy/mopidy-spotify/releases/tag/v5.0.0a3
RUN curl -LO 'https://github.com/kingosticks/gst-plugins-rs-build/releases/download/gst-plugin-spotify_0.14.0-alpha.1-1/gst-plugin-spotify_0.14.0.alpha.1-1_amd64.deb' \
 && dpkg -i --force-all 'gst-plugin-spotify_0.14.0.alpha.1-1_amd64.deb' \
 && apt -f install -y \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

##  Copy fallback configuration.
COPY mopidy.conf /etc/default/mopidy.conf

#  Copy default configuration.
RUN rm /etc/mopidy/mopidy.conf
COPY mopidy.conf /etc/mopidy/mopidy.conf

## Copy the pulse-client configuratrion.
#COPY pulse-client.conf /etc/pulse/client.conf

EXPOSE 6600 6680 5555/udp

######################################
########### Snapcast setup ###########
# https://docs.docker.com/config/containers/multi-service_container/

# Taken and adapted from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
ARG SNAPCASTVERSION=0.29.0
ARG SNAPCASTDEP_SUFFIX=-1

# Download snapcast package
RUN apt update \
 && DEBIAN_FRONTEND=noninteractive apt install -y \
        libavahi-client3 \
        libavahi-common3 \
        libsoxr0 \
 && curl -LO 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64_bookworm.deb' \
 && dpkg -i --force-all 'snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64_bookworm.deb' \
 && apt -f install -y \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# Create config directory
RUN mkdir -p /root/.config/snapcast/
# copy configuration
COPY snapserver.conf /etc/snapserver.conf
COPY snapserver.conf /root/.config/snapcast/snapserver.conf

## Expose TCP port used to stream audio data to snapclient instances
EXPOSE 1704

#######################################
############ Supervisor setup #########

# https://docs.docker.com/config/containers/multi-service_container/

RUN apt update \
 && DEBIAN_FRONTEND=noninteractive apt install -y supervisor \
 && mkdir -p /var/log/supervisor \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# copy configuration
COPY supervisord.conf /etc/supervisord.conf

#
## makepkg user and workdir
#ARG user=mopidy
#RUN useradd -m $user \
# && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
#USER $user
#WORKDIR /home/$user
#

RUN cat /etc/mopidy/mopidy.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
