FROM osgeo/gdal:ubuntu-small-3.4.1 as base

ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

RUN apt-get update \
    && apt-get install -y \
    # Build tools
    build-essential \
    git \
    python3-pip \
    # For Psycopg2
    libpq-dev python3-dev \
    # For SSL
    ca-certificates \
    # for pg_isready
    postgresql-client \
    # Try adding libgeos-dev
    libgeos-dev \
    # Tidy up
    && apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/{apt,dpkg,cache,log}

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

# ENV APPDIR=/code
# RUN mkdir -p $APPDIR
# WORKDIR $APPDIR
# ADD . $APPDIR

# CMD ["python", "--version"]

# RUN 