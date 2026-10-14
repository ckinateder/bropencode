# syntax=docker/dockerfile:1

# ---- Pinned version. To upgrade: bump the version AND its checksum. ----
ARG OPENCODE_VERSION=2.0.29
# sha512 (hex) of cli-linux-x64-${OPENCODE_VERSION}.tgz. The npm registry's "integrity"
# field is the same hash in base64:
#   curl -s https://registry.npmjs.org/@opencode%2fcli-linux-x64/<ver> | jq -r .dist.integrity \
#     | cut -d- -f2 | base64 -d | od -An -tx1 | tr -d ' \n'
ARG OPENCODE_SHA512=a5d1bf4f8b81c520b78635133ab4e5c76a5795997656a00195bd00803959f153bfab5a5450e62fa285a637955e4a2f843fc70a19552c8f419498c0de076ca6a4

# ---- opencode: prebuilt, self-contained binary from the npm registry ----
FROM node:24-trixie-slim AS opencode-fetch
ARG OPENCODE_VERSION
ARG OPENCODE_SHA512
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fsSL -o opencode.tgz "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${OPENCODE_VERSION}.tgz" \
 && echo "${OPENCODE_SHA512}  opencode.tgz" | sha512sum -c - \
 && tar -xzf opencode.tgz \
 && install -D -m 0755 package/bin/opencode /out/opencode

# ---- Runtime: node 24 so the agent can work on JS projects; no curl ----
FROM node:24-trixie-slim
# Tools available to the agent. Add more apt packages here.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates fd-find git ripgrep \
 && rm -rf /var/lib/apt/lists/*
COPY --from=opencode-fetch /out/opencode /usr/local/bin/opencode
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
RUN useradd --uid 10001 --user-group --no-create-home --home-dir /home/opencode --shell /usr/sbin/nologin opencode \
 && mkdir -p /workspace /data && chown 10001:10001 /workspace \
 # 0777: oc-here runs the container as the host uid, which must be able to write the volume
 && chmod 0777 /data
# Sessions live on the /data volume, outside HOME, so all of HOME can be a tmpfs.
# Stop opencode's own calls home (update check, model catalog); the proxy blocks them anyway.
# Project config is ignored so a repo's opencode.json can't loosen the rendered config.
ENV HOME=/home/opencode \
    XDG_DATA_HOME=/data \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    OPENCODE_DISABLE_MODELS_FETCH=1 \
    OPENCODE_DISABLE_PROJECT_CONFIG=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false
USER 10001:10001
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
