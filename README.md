# wyze-bridge (patched)

[docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge) with a
patched [go2rtc](https://github.com/AlexxIT/go2rtc) built from
[Cerebellum-ITM/go2rtc](https://github.com/Cerebellum-ITM/go2rtc), branch
`wyze-ptz`.

The upstream image downloads an official go2rtc release binary. This image
replaces that binary with one built from the fork, and adds the `wyze-ptzd`
daemon alongside it.

    ghcr.io/cerebellum-itm/wyze-bridge:latest

Built for `linux/amd64` and `linux/arm64`.

## What the fork changes

| Change | Why |
| --- | --- |
| Close the DTLS socket before waiting on goroutines | A failed dial leaked its socket and hung the caller, which eventually stopped go2rtc from connecting a stream at all |
| Keep the SDP SPS in sync after a resolution switch | A stale 360p SPS was advertised for a 1080p stream, so HomeKit Secure Video silently discarded every recording |
| Clamp the overstated H.264 level | Pan V3 announces level 5.0 for a stream that fits in 4.0, which HomeKit refuses |
| Pan/tilt, position and patrol commands | The v4 bridge does not implement camera movement |
| `wyze-ptzd` | Exposes movement, power and patrol over HTTP for Home Assistant |

## Usage

Drop-in replacement for the upstream image:

```yaml
services:
  wyze-bridge:
    image: ghcr.io/cerebellum-itm/wyze-bridge:latest
    network_mode: host
    restart: unless-stopped
    environment:
      - WYZE_EMAIL=${WYZE_EMAIL}
      - WYZE_PASSWORD=${WYZE_PASSWORD}
      - WYZE_API_ID=${WYZE_API_ID}
      - WYZE_API_KEY=${WYZE_API_KEY}
    volumes:
      - ./config:/config

  wyze-ptzd:
    image: ghcr.io/cerebellum-itm/wyze-bridge:latest
    command: /usr/local/bin/wyze-ptzd
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./config:/config:ro
```

Credentials stay in the environment and the camera configuration stays in the
mounted volume. Neither is baked into the image.

`wyze-ptzd` listens on `:5081` and reads the camera list from
`/config/go2rtc.yaml`; the Wyze session comes from the bridge state file in the
same directory.

## Updating the fork

`GO2RTC_REF` is pinned to a commit, so the same Dockerfile always produces the
same image and a push to the fork does not silently change what ships here.

Releasing new work from the fork is one edit: bump `GO2RTC_REF` in the
Dockerfile to the new commit and push. That push is what rebuilds and publishes
the image.

For a throwaway build of some other revision, the `build` workflow takes a
branch or commit in its `go2rtc_ref` input; leaving it empty uses the pinned
commit. Locally:

```sh
docker build --build-arg GO2RTC_REF=<branch-or-sha> -t wyze-bridge .
```

`BRIDGE_VERSION` selects the upstream base image tag, `4.5.0` by default.

## Licensing

The base image is AGPL-3.0; its source is at
[IDisposable/docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge).
go2rtc and the changes layered on top are published at
[Cerebellum-ITM/go2rtc](https://github.com/Cerebellum-ITM/go2rtc).
