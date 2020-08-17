###############################################################################
#
# Python base
# Full official Debian-based Python image
FROM python:3.6-slim-buster AS base

# These will change for every build
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.created="$BUILD_DATE" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.build-date="$BUILD_DATE" \
      maintainer="rxpy-web tzhu" \
      org.opencontainers.image.title="rxpy-web" \
      org.opencontainers.image.description="Python RxPy Demo" \
      org.opencontainers.image.url="https://github.com/tideorz/python-reactive-programming" \
      org.opencontainers.image.source="https://github.com/Tideorz/python-reactive-programming.git" \

      org.opencontainers.image.vendor="Tideorz" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.name="rxpy-web" \
      org.label-schema.description="Python Rxpy Demo" \
      org.label-schema.url="https://github.com/tideorz/python-reactive-programming" \
      org.label-schema.vcs-url="https://github.com/tideorz/python-reactive-programming.git" \
      org.label-schema.vendor="Tideorz"

# Core env
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8 \
    LDFLAGS=-L/usr/lib/x86_64-linux-gnu/ \
    DEBIAN_FRONTEND=noninteractive \
    BASEPATH="$PATH" \
    PATH="/venv/bin:$PATH" \
    VIRTUAL_ENV="/venv" \
    PIPENV_VERBOSITY=-1 \
    PYTHONWARNINGS="ignore::DeprecationWarning" \
    PYTHONPATH="${PYTHONPATH}:/app/rxpy_demo"

# Core user/dirs
RUN groupadd -g 1000 test \
    && groupadd -g 1100 test-rw \
    && useradd -u 1000 -g 1000 test \
    && mkdir -p /app \
    && chown -R 1000:1000 /app

WORKDIR /app

CMD ["python", "/app/rxpy_demo/server.py"]


###########################################################################
# BUILDER  BASE - finish pipenv stuff
###########################################################################
FROM base AS devel

ARG BUILD_DEPS="\
    build-essential \
    libcurl4 \
    libssl-dev \
    libc6-dev \
    libcurl4-openssl-dev \
"

# Ignore until we determine required versions
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        $BUILD_DEPS && \
    rm -rf /var/lib/apt/lists/*

# Install base Python depedancies.
COPY Pipfile* /tmp/builder/

WORKDIR /tmp/builder/

COPY scripts/init-pyenv.sh .

RUN umask 0002 && bash ./init-pyenv.sh

ARG GIT_PERSONEAL_ACCESS_TOKEN
