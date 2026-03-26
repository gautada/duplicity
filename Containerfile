ARG IMAGE_VERSION=latest
FROM gautada/debian:$IMAGE_VERSION as container

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="duplicity"
LABEL org.opencontainers.image.description="A container for backup service using duplicity."
LABEL org.opencontainers.image.source="https://github.com/gautada/duplicity"

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
ARG USER=duplicity
RUN /usr/sbin/groupmod -n $USER debian \
 && /usr/sbin/usermod -l $USER -d /home/$USER -m debian \
 && /bin/chown -R $USER:$USER /home/$USER \
 && /bin/chown -R $USER:$USER /mnt/volumes/backup

# ╭――――――――――――――――――――╮
# │ PRIVILEGES         │
# ╰――――――――――――――――――――╯
COPY privileges /etc/sudoers.d/duplicity
RUN chmod 0440 /etc/sudoers.d/duplicity

# ╭――――――――――――――――――――╮
# │ APPLICATION        │
# ╰――――――――――――――――――――╯
# Install duplicity and backends from apt
RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    duplicity \
    python3-boto3 \
    rsync \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Symlinks for volumes as in original container.build
RUN -u $USER mkdir -p /home/$USER/source /home/$USER/local /home/$USER/cache /home/$USER/target \
 && /bin/ln -svf /mnt/volumes/source /home/$USER/source \
 && /bin/ln -svf /mnt/volumes/container /home/$USER/cache \
 && /bin/ln -svf /mnt/volumes/backup /home/$USER/target

COPY duplicity-backup /usr/bin/duplicity-backup
COPY duplicity-syncjob /usr/bin/duplicity-syncjob
RUN chmod +x /usr/bin/duplicity-backup /usr/bin/duplicity-syncjob \
 && ln -fsv /usr/bin/duplicity-syncjob /etc/cron.daily/duplicity-syncjob

# ╭――――――――――――――――――――╮
# │ VOLUMES            │
# ╰――――――――――――――――――――╯
VOLUME /mnt/volumes/backup
VOLUME /mnt/volumes/container
VOLUME /mnt/volumes/secrets
VOLUME /mnt/volumes/source

# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
USER $USER
WORKDIR /home/$USER
