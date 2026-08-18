# purpose: first-party Providence image. Upstream is fetched at an immutable commit and
# never modified; everything BOS-specific lives outside the PHP process.
#
# Deliberately NOT built FROM a community CollectiveAccess image: there is no
# CollectiveAccess-maintained image, and the community ones are single-maintainer,
# historically 1.7.x, and pin nothing. They are reference material, not a base layer.

ARG PHP_IMAGE=php:8.2-fpm-bookworm
FROM ${PHP_IMAGE} AS build

ARG PROVIDENCE_REPO
ARG PROVIDENCE_COMMIT

RUN test -n "${PROVIDENCE_COMMIT}" || { echo "PROVIDENCE_COMMIT build-arg is required"; exit 1; }

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Fetch exactly one commit. A tag is a moving pointer; the SHA is the contract.
RUN git init /providence \
 && cd /providence \
 && git remote add origin "${PROVIDENCE_REPO}" \
 && git fetch --depth 1 origin "${PROVIDENCE_COMMIT}" \
 && git checkout --detach FETCH_HEAD \
 && test "$(git rev-parse HEAD)" = "${PROVIDENCE_COMMIT}" \
 && rm -rf .git

RUN cd /providence && composer install --no-dev --no-interaction --prefer-dist --no-progress

FROM ${PHP_IMAGE}

# Runtime media/metadata toolchain. Providence shells out to these; without them
# derivative generation and metadata extraction fail at ingest, not at boot.
RUN apt-get update && apt-get install -y --no-install-recommends \
      imagemagick ghostscript ffmpeg mediainfo libimage-exiftool-perl \
      libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
      libicu-dev libxml2-dev libcurl4-openssl-dev default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
      pdo_mysql mysqli gd zip intl exif mbstring opcache

# Providence renders PDFs through ImageMagick's Ghostscript delegate. Debian ships a
# policy.xml that refuses PDF outright; without this, PDF ingest fails silently-ish.
COPY docker/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

COPY --from=build /providence /var/www/providence
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Writable state is volume-mounted; the code tree itself is not written to at runtime.
RUN mkdir -p /var/www/providence/media /var/www/providence/app/tmp /var/www/providence/app/log \
 && chown -R www-data:www-data /var/www/providence/media /var/www/providence/app/tmp /var/www/providence/app/log

WORKDIR /var/www/providence
USER www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
