# syntax=docker/dockerfile:1.7
# hadolint ignore=DL3007
FROM docker.io/gautada/debian:latest AS container

# ARG DEBIAN_TAG=latest
# FROM docker.io/library/gautada/debian:$DEBIAN_TAG AS container

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="duplicity"
LABEL org.opencontainers.image.description="A container for offsite backup client service based on Duplicity."
LABEL org.opencontainers.image.source="https://github.com/gautada/duplicity"
LABEL org.opencontainers.image.license="GPL-2.0-or-later"

ENV DEBIAN_FRONTEND=noninteractive

# ╭――――――――――――――――――――╮
# │ PACKAGES           │
# ╰――――――――――――――――――――╯
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install --yes --no-install-recommends \
    duplicity \
    python3-boto3 \
    python3-pip \
    rsync \
    gnupg \
    nano \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ╭──────────────────────────────────────────────────────────╮
# │ User                                                     │
# ╰──────────────────────────────────────────────────────────╯
ARG USER=duplicity
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/passwd -d $USER \
 && rm -rf /home/debian



# # ╭―
# # │ PRIVILEGES
# # ╰――――――――――――――――――――
# # Note: The original privileges file is for Alpine's privileged group.
# # debian base uses a different mechanism. We'll update the privileges file
# # to match the debian base expectations (sudoers.d).
# COPY privileges /etc/sudoers.d/duplicity
# RUN chmod 0440 /etc/sudoers.d/duplicity
#
# ╭―
# │ SCRIPTS
# ╰――――――――――――――――――――
COPY generate-key.sh /usr/bin/generate-key
COPY setup-keys.sh /usr/bin/setup-keys
COPY duplicity-common.sh /usr/bin/duplicity-common
COPY duplicity-backup.sh /usr/bin/duplicity-backup
COPY duplicity-status.sh /usr/bin/duplicity-status
RUN chmod +x /usr/bin/duplicity-backup /usr/bin/duplicity-status \
             /usr/bin/generate-key /usr/bin/setup-keys \
 && ln -s duplicity-backup /usr/bin/duplicity-full-backup


# ╭――――――――――――――――――――╮
# │ CRONTAB            │
# ╰――――――――――――――――――――╯
# 997 COPY --chown=<user>:<group> <src> <dest>
COPY --chown=1001:997 duplicity.crontab /var/spool/cron/crontabs/duplicity
RUN chmod 0600 /var/spool/cron/crontabs/duplicity

# ╭――――――――――――――――――――╮
# │ VERSION            │
# ╰――――――――――――――――――――╯
# Override the default container-version to report application version
COPY appversion-check.sh /etc/container/health/appversion-check
COPY container-version.sh /usr/bin/container-version
RUN chmod +x /usr/bin/container-version 

#
# # ╭――――――――――――――――――――╮
# # │ ENTRYPOINT         │
# # ╰――――――――────────────────
# # debian base uses s6-svscan /etc/services.d
# # We'll put a service in place for duplicity if it's meant to be a long-running daemon
# # but the original entrypoint was a blocking tail -f /dev/null after GPG import.
# # We will adapt the original entrypoint to an s6 service or a wrapper.
#
# ENTRYPOINT ["tail", "-f", "/dev/null"]
# COPY entrypoint /usr/bin/duplicity-entrypoint
# RUN chmod +x /usr/bin/duplicity-entrypoint
#
# # Create an s6 service for duplicity entrypoint
# RUN mkdir -p /etc/services.d/duplicity
# COPY <<EOF /etc/services.d/duplicity/run
# #!/bin/sh
# exec /usr/bin/duplicity-entrypoint
# EOF
# RUN chmod +x /etc/services.d/duplicity/run
#
# # ╭――――――――――――――――――――╮
# # │ CONTAINER          │
# # ╰――――――――――――――――――――╯
# COPY aws_test.py /home/$USER/aws_test.py
# RUN /bin/chown -R $USER:$USER /home/$USER
#
# USER $USER
# VOLUME /mnt/volumes/backup
# VOLUME /mnt/volumes/configmaps
# VOLUME /mnt/volumes/container
# VOLUME /mnt/volumes/secrets
# VOLUME /mnt/volumes/source
# WORKDIR /home/$USER
