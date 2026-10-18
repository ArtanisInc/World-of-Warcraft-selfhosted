# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=26.04

FROM docker.io/library/ubuntu:${UBUNTU_VERSION} AS source

ARG DEBIAN_FRONTEND=noninteractive

# Source revisions are committed in docker/sources.lock. Do not clone mutable
# branch heads here: the lock is the sole authority for the core and modules.
COPY docker/sources.lock /usr/local/share/acore-sources.lock
RUN set -eux; \
    apt-get update; apt-get install -y --no-install-recommends ca-certificates git; \
    rm -rf /var/lib/apt/lists/*; \
    core_line=$(awk -F ';' '$1 == "core" { print; exit }' /usr/local/share/acore-sources.lock); \
    test -n "$core_line"; \
    core_url=$(printf '%s\n' "$core_line" | cut -d ';' -f2); \
    core_commit=$(printf '%s\n' "$core_line" | cut -d ';' -f4); \
    test "${#core_commit}" = 40; \
    git init /azerothcore; \
    git -C /azerothcore remote add origin "$core_url"; \
    git -C /azerothcore fetch --depth=1 origin "$core_commit"; \
    git -C /azerothcore checkout --detach --force FETCH_HEAD; \
    test "$(git -C /azerothcore rev-parse HEAD)" = "$core_commit"

FROM source AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG ALE_LUA_VERSION=lua52
ARG BUILD_TYPE=Release
ARG BUILD_JOBS=4

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ccache clang-20 cmake python3 \
      default-libmysqlclient-dev libboost-all-dev libbz2-dev libicu-dev liblzma-dev \
      libncurses-dev libreadline-dev libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY docker/build-source.sh /usr/local/bin/build-source
COPY docker/sources.lock /usr/local/share/acore-sources.lock
COPY docker/patch-gunship.py /usr/local/bin/patch-gunship.py

RUN --mount=type=cache,target=/root/.cache/ccache,sharing=locked \
    ALE_LUA_VERSION="$ALE_LUA_VERSION" \
    BUILD_TYPE="$BUILD_TYPE" \
    BUILD_JOBS="$BUILD_JOBS" \
    build-source

FROM docker.io/library/ubuntu:${UBUNTU_VERSION} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV TZ=Etc/UTC \
    AC_FORCE_CREATE_DB=1 \
    PATH=/azerothcore/env/dist/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl default-mysql-client gettext-base gosu python3 \
      libicu78 libmysqlclient24 libncurses6 libreadline8t64 tini \
    && rm -rf /var/lib/apt/lists/* \
    && if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi \
    && groupadd --gid "$GROUP_ID" acore \
    && useradd --uid "$USER_ID" --gid "$GROUP_ID" --create-home --shell /bin/bash acore \
    && mkdir -p /azerothcore/env/dist/bin /azerothcore/env/dist/data \
         /azerothcore/env/dist/etc /azerothcore/env/dist/logs \
         /azerothcore/env/dist/temp /azerothcore/env/ref/etc \
    && chown -R acore:acore /azerothcore

COPY --from=build --chown=acore:acore /azerothcore/env/dist/etc/ /azerothcore/env/ref/etc/
COPY --from=build --chown=acore:acore /azerothcore/env/dist/build-manifest.tsv /azerothcore/env/dist/build-manifest.tsv
COPY --chown=acore:acore THIRD_PARTY_NOTICES.md /azerothcore/THIRD_PARTY_NOTICES.md
COPY --from=build --chown=acore:acore --chmod=755 /azerothcore/apps/docker/entrypoint.sh /azerothcore/upstream-entrypoint.sh
RUN sed -i 's/cp -rnv /cp -rv --update=none /; s/cp -vn /cp -v --update=none /' /azerothcore/upstream-entrypoint.sh
COPY --chown=acore:acore --chmod=755 docker/entrypoint.sh /azerothcore/entrypoint.sh

USER root
WORKDIR /azerothcore
ENTRYPOINT ["/usr/bin/tini", "--", "/azerothcore/entrypoint.sh"]

FROM runtime AS authserver
ENV ACORE_COMPONENT=authserver \
    AC_UPDATES_ENABLE_DATABASES=0 \
    AC_DISABLE_INTERACTIVE=1 \
    AC_CLOSE_IDLE_CONNECTIONS=0
COPY --from=build --chown=acore:acore /azerothcore/env/dist/bin/authserver /azerothcore/env/dist/bin/authserver
EXPOSE 3724
CMD ["authserver"]

FROM runtime AS worldserver
ENV ACORE_COMPONENT=worldserver \
    AC_UPDATES_ENABLE_DATABASES=0 \
    AC_DISABLE_INTERACTIVE=0 \
    AC_CLOSE_IDLE_CONNECTIONS=0
COPY --from=build --chown=acore:acore /azerothcore/env/dist/bin/worldserver /azerothcore/env/dist/bin/worldserver
COPY --from=build --chown=acore:acore /azerothcore/env/dist/bin/lua_scripts/ /azerothcore/env/dist/bin/lua_scripts/
COPY --chown=acore:acore docker/lua_scripts/ /azerothcore/env/dist/bin/lua_scripts/
# Playerbots initializes its dedicated database at worldserver startup and
# resolves these SQL files from the source-tree module path.
COPY --from=build --chown=acore:acore /azerothcore/modules/mod-playerbots/data/ /azerothcore/modules/mod-playerbots/data/
EXPOSE 8085 7878
CMD ["worldserver"]

FROM runtime AS db-import
ENV ACORE_COMPONENT=dbimport
COPY --from=build --chown=acore:acore /azerothcore/env/dist/bin/dbimport /azerothcore/env/dist/bin/dbimport
COPY --from=build --chown=acore:acore /azerothcore/data /azerothcore/data
COPY --from=build --chown=acore:acore /azerothcore/modules /azerothcore/modules
CMD ["dbimport"]

FROM db-import AS operations
ENV ACORE_COMPONENT=operations
COPY --chown=acore:acore docker/tools/ /azerothcore/tools/
CMD ["python3", "/azerothcore/tools/health.py"]

FROM docker.io/library/ubuntu:${UBUNTU_VERSION} AS client-data
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data
COPY --from=source /azerothcore/apps /azerothcore/apps
RUN sed -i \
      's|^source "$AC_PATH_INSTALLER/includes/modules-manager/modules.sh"$|[[ -f "$AC_PATH_INSTALLER/includes/modules-manager/modules.sh" ]] \&\& source "$AC_PATH_INSTALLER/includes/modules-manager/modules.sh"|' \
      /azerothcore/apps/installer/includes/functions.sh
ENV DATAPATH=/data
VOLUME /data
CMD ["bash", "-c", "source /azerothcore/apps/installer/includes/functions.sh && inst_download_client_data"]
