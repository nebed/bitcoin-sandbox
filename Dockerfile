# syntax=docker/dockerfile:1

# Use Alpine as base
FROM alpine:latest AS build

# Install build dependencies
RUN apk update && apk add --no-cache \
      build-base \
      cmake \ 
      linux-headers \
      pkgconf \
      python3 \
      libevent-dev \
      boost-dev \
      sqlite-dev \
      capnproto \
      capnproto-dev \
      zeromq-dev \
      bash \
      autoconf \
      automake \
      libtool \
      curl \
      git \
      make \
      g++ \
      openssl-dev \
      zlib-dev \
      miniupnpc-dev

# Set version
ARG BITCOIN_VERSION=v30.0
ENV BITCOIN_VERSION=${BITCOIN_VERSION}

# Clone the Bitcoin Core source
WORKDIR /usr/src
RUN git clone --branch ${BITCOIN_VERSION} --depth 1 https://github.com/bitcoin/bitcoin.git bitcoin
WORKDIR /usr/src/bitcoin

# Prepare build system (for autoconf/automake)
RUN cmake -B build -DENABLE_WALLET=ON -DBUILD_GUI=OFF -DCMAKE_INSTALL_PREFIX=/usr/local-staging

RUN cmake --build build -j"$(nproc)" && \
    cmake --install build --prefix /usr/local-staging

# Now build a smaller runtime image
FROM alpine:latest

RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    libevent \
    sqlite \
    boost \
    zeromq \
    openssl \
    capnproto \
    zlib \
    bash \
    tini

# Create a bitcoin user and data directory
RUN addgroup -S bitcoin && adduser -S -G bitcoin bitcoin \
    && mkdir -p /bitcoin/data \
    && chown bitcoin:bitcoin /bitcoin/data

# Copy built binaries from build stage
COPY --from=build /usr/local-staging/bin/bitcoind /usr/local/bin/
COPY --from=build /usr/local-staging/bin/bitcoin-cli /usr/local/bin/
COPY --from=build /usr/local-staging/bin/bitcoin-tx /usr/local/bin/
COPY --from=build /usr/local-staging/bin/bitcoin-wallet /usr/local/bin/
COPY --from=build /usr/local-staging/bin/bitcoin /usr/local/bin/

# Set ownership
RUN chown bitcoin:bitcoin /usr/local/bin/bitcoind \
    && chown bitcoin:bitcoin /usr/local/bin/bitcoin-cli \
    && chown bitcoin:bitcoin /usr/local/bin/bitcoin-tx \
    && chown bitcoin:bitcoin /usr/local/bin/bitcoin-wallet \
    && chown bitcoin:bitcoin /usr/local/bin/bitcoin

# Expose default P2P/RPC ports (adjust if needed)
EXPOSE 8333 8332 18333 18332

# Set default working directory
WORKDIR /bitcoin/data

# Use entrypoint script so mountable config + args supported
ENTRYPOINT ["/usr/local/bin/bitcoind"]
# Allow overriding CMD for args
CMD ["-datadir=/bitcoin/data", "-conf=/bitcoin/data/bitcoin.conf"]

# Switch to non-root user
USER bitcoin
