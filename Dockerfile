# --- Build Stage ---
FROM ubuntu:25.04 AS build

LABEL maintainer="John Coffey"
ARG BACKEND_BRANCH=main
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    procmail \
    curl \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    gnupg-agent \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add Yarn repository and key
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Add NodeSource repository and key for Node.js (prebuilt binaries)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Install Node.js (includes npm) and Yarn
RUN apt-get update && \
    apt-get install -y --no-install-recommends nodejs yarn && \
    rm -rf /var/lib/apt/lists/*

# Use your forked backend repo for version tracking and cloning
ADD https://api.github.com/repos/johnco3/quick-bench-back-end/git/refs/heads/${BACKEND_BRANCH} /tmp/backend-version.json

RUN git clone -b ${BACKEND_BRANCH} https://github.com/johnco3/quick-bench-back-end /quick-bench && \
    cd /quick-bench && \
    npm install && \
    echo '{ \
      "defaultAction": "SCMP_ACT_ALLOW", \
      "archMap": [ \
        { "architecture": "SCMP_ARCH_X86_64", "subArchitectures": [ "SCMP_ARCH_X86", "SCMP_ARCH_X32" ] }, \
        { "architecture": "SCMP_ARCH_AARCH64", "subArchitectures": [ "SCMP_ARCH_ARM" ] } \
      ], \
      "syscalls": [ \
        { "names": ["perf_event_open"], "action": "SCMP_ACT_ALLOW" } \
      ] \
    }' > seccomp.json && \
    (sysctl -w kernel.perf_event_paranoid=1 || echo "Cannot set perf_event_paranoid in container")

# Frontend version tracking and cloning
ADD https://api.github.com/repos/fredtingaud/quick-bench-front-end/git/refs/heads/main /tmp/frontend-version.json

RUN git clone -b main https://github.com/FredTingaud/quick-bench-front-end /quick-bench/quick-bench-front-end && \
    cd /quick-bench/quick-bench-front-end/build-bench && \
    yarn && \
    yarn build && \
    cd ../quick-bench && \
    yarn && \
    yarn build

# Copy startup scripts
COPY ./build-scripts/start-* /quick-bench/

# --- Production Stage ---
FROM ubuntu:25.04 AS final

ARG DEBIAN_FRONTEND=noninteractive

# Add NodeSource repository and key for Node.js (prebuilt binaries)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Install only runtime dependencies (prebuilt Node.js and certs)
RUN apt-get update && \
    apt-get install -y --no-install-recommends nodejs ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user and group
RUN groupadd --system quickbench && \
    useradd --system --create-home --home-dir /quick-bench --gid quickbench quickbench

# Copy built backend and frontend from build stage
COPY --from=build /quick-bench /quick-bench

# Set permissions for the non-root user
RUN chown -R quickbench:quickbench /quick-bench

# Switch to non-root user
USER quickbench

# Set working directory
WORKDIR /quick-bench