# HiveOS dans un conteneur, pour les GPU loues (vast.ai, etc.).
#
# - HiveOS en derniere version, installe depuis le depot officiel de Hiveon
#   (depot signe, empreinte de la cle verifiee ci-dessous).
# - Pas de pilote NVIDIA dans l'image : l'hote l'injecte au lancement.
# - Overclocking, reglage des ventilateurs, mise a jour du pilote et
#   redemarrage machine neutralises (impossibles en location).
# - A renseigner au lancement : RIG_ID, RIG_PASSWD, FARM_HASH.
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Empreinte de la cle qui signe le depot HiveOS (download.hiveos.farm/repo/binary).
ARG HIVE_REPO_SIGNER=96663192AD0AC131DB93CA44817791619025A82D

# Remplacements (systemctl, reboot...) et script de demarrage.
COPY rootfs/ /

# 1. Outils de base, cle et depot HiveOS
RUN chmod 0755 /usr/local/bin/* /usr/local/sbin/* /usr/local/lib/hiveostemplate/visible-gpus \
         /usr/local/lib/hiveostemplate/overrides/* \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         ca-certificates curl wget gnupg cron screen sudo iproute2 net-tools pciutils usbutils dmidecode \
         procps kmod lsb-release unzip \
    && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${HIVE_REPO_SIGNER}" -o /tmp/hive.asc \
    && fpr=$(gpg --show-keys --with-colons /tmp/hive.asc | awk -F: '/^fpr/ {print $10; exit}') \
    && if [ "$fpr" != "$HIVE_REPO_SIGNER" ]; then echo "ERREUR: cle HiveOS inattendue ($fpr)" >&2; exit 1; fi \
    && gpg --dearmor -o /etc/apt/trusted.gpg.d/hiveos.gpg /tmp/hive.asc \
    && rm -f /tmp/hive.asc \
    && echo "deb https://download.hiveos.farm/repo/binary/ /" > /etc/apt/sources.list.d/hiverepo.list

# 2. HiveOS (derniere version du paquet "hive" et de ses dependances)
#    L'utilisateur "user" est attendu par le paquet.
RUN useradd -m -s /bin/bash user \
    && echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends hive \
    && dpkg-query -W -f='hive ${Version}\n' hive | tee /etc/hiveos-version \
    && rm -rf /var/lib/apt/lists/*

# 3. Neutralisation de ce qui est impossible en location. dpkg-divert garde
#    nos versions meme si HiveOS se met a jour depuis le tableau de bord.
RUN for f in nvidia-oc amd-oc intel-oc tweakers autofan nvidia-driver-update sreboot; do \
      dpkg-divert --local --rename --divert "/hive/sbin/$f.hive" --add "/hive/sbin/$f"; \
      install -m 0755 "/usr/local/lib/hiveostemplate/overrides/$f" "/hive/sbin/$f"; \
    done

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

LABEL org.opencontainers.image.title="hiveostemplate" \
      org.opencontainers.image.description="HiveOS (derniere version) dans un conteneur pour GPU loues : RIG_ID, RIG_PASSWD, FARM_HASH"

ENTRYPOINT ["/usr/local/bin/hiveos-start"]
