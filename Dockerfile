FROM osgeo/gdal:ubuntu-small-3.6.3

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# Install system dependencies and security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      openssl \
      build-essential \
      fish \
      git \
      vim \
      htop \
      wget \
      unzip \
      python3-pip \
      libpq-dev python3-dev \
    && if grep -q '^mozilla/emSign_ECC_Root_CA_-_G3.crt$' /etc/ca-certificates.conf; then \
         sed -i 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt$|!mozilla/emSign_ECC_Root_CA_-_G3.crt|' /etc/ca-certificates.conf; \
       fi \
    && update-ca-certificates --fresh \
    && rm -rf /var/lib/apt/lists/*

# Update pip and its bundled CA certificates
RUN python3 -m pip install --no-cache-dir --upgrade "pip==26.2.2"

# Pip installation
RUN mkdir -p /conf
COPY requirements.txt /conf/
COPY constraints.txt /conf/
RUN python3 -m pip install --no-cache-dir -r /conf/requirements.txt -c /conf/constraints.txt
# Copy source code and install it
RUN mkdir -p /code
WORKDIR /code
ADD . /code

RUN echo "Installing dea-fmc through the Dockerfile."
RUN python3 -m pip install --no-cache-dir -c /conf/constraints.txt --extra-index-url="https://packages.dea.ga.gov.au" .

# Verify installed Python dependencies
RUN python3 -m pip freeze \
    && python3 -m pip check \
    && python3 -c "import certifi; assert certifi.__version__ == '2026.10.19'; print('certifi:', certifi.__version__)" \
    && python3 -m pip --version

# Make sure it's working
RUN dea-fmc --version
