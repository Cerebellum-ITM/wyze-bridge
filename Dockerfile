# syntax=docker/dockerfile:1

ARG BRIDGE_VERSION=4.5.0

# Go cross-compiles without emulation, so this stage stays on the native
# builder architecture and targets the requested one instead of running under
# QEMU.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build

ARG GO2RTC_REPO=https://github.com/Cerebellum-ITM/go2rtc
# Pinned so a rebuild always produces the same image. Bumping this commit is
# what releases a new version of the fork.
ARG GO2RTC_REF=69eea6899a9eb6e7955614278871947bbf8d4bfb
ARG TARGETARCH

RUN apk add --no-cache git

# Fetching a single ref accepts both a branch name and a commit SHA, which
# `git clone --branch` does not.
RUN git init /src \
 && cd /src \
 && git remote add origin "${GO2RTC_REPO}" \
 && git fetch --depth 1 origin "${GO2RTC_REF}" \
 && git checkout FETCH_HEAD

WORKDIR /src

RUN CGO_ENABLED=0 GOOS=linux GOARCH="${TARGETARCH}" \
    go build -trimpath -buildvcs=false -o /out/go2rtc . \
 && CGO_ENABLED=0 GOOS=linux GOARCH="${TARGETARCH}" \
    go build -trimpath -buildvcs=false -o /out/wyze-ptzd ./cmd/wyze-ptzd

FROM idisposablegithub365/wyze-bridge:${BRIDGE_VERSION}

LABEL org.opencontainers.image.source=https://github.com/Cerebellum-ITM/wyze-bridge
LABEL org.opencontainers.image.description="docker-wyze-bridge with go2rtc built from Cerebellum-ITM/go2rtc"
LABEL org.opencontainers.image.licenses=AGPL-3.0

COPY --from=build /out/go2rtc /usr/local/bin/go2rtc
COPY --from=build /out/wyze-ptzd /usr/local/bin/wyze-ptzd
