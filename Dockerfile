# Multi-Stage Production Container Build for Solas WebRTC SFU

# Stage 1: Build & Compilation Environment
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    valac \
    meson \
    ninja-build \
    pkg-config \
    libglib2.0-dev \
    libgee-0.8-dev \
    libjson-glib-dev \
    libssl-dev \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Configure and compile with Meson and Ninja in Release mode
RUN meson setup build --buildtype=release --strip \
    && ninja -C build \
    && ninja -C build test

# Stage 2: Minimal Production Runtime
FROM debian:bookworm-slim AS runner

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libgee-0.8-2 \
    libjson-glib-1.0-0 \
    libssl3 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create unprivileged system user for process isolation
RUN groupadd -r solas && useradd -r -g solas -s /usr/sbin/nologin -d /var/lib/solas solas \
    && mkdir -p /var/lib/solas /etc/solas \
    && chown -R solas:solas /var/lib/solas /etc/solas

# Copy compiled binaries from builder
COPY --from=builder /src/build/solas-server /usr/local/bin/solas-server
COPY --from=builder /src/build/solas-cli /usr/local/bin/solas-cli
COPY --from=builder /src/build/solas-bench /usr/local/bin/solas-bench
COPY --from=builder /src/config/solas.json /etc/solas/config.json

USER solas
WORKDIR /var/lib/solas

# Expose WebRTC Gateway Ports
# 8080: HTTP REST & WebSocket Signaling
# 50000/udp: Unified Media Gateway (STUN, DTLS, SRTP, SCTP)
# 3478/udp: TURN Relay / STUN Port
EXPOSE 8080 50000/udp 3478/udp 7000/udp

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/usr/local/bin/solas-server"]
CMD ["--config", "/etc/solas/config.json"]
