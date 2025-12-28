ARG RUBY_VERSION="3.4.7"
ARG DEBIAN_BASE="trixie"
# Add SBOM scan context for intermediate steps
ARG BUILDKIT_SBOM_SCAN_CONTEXT=true
ARG BUILDKIT_SBOM_SCAN_STAGE=true
FROM ruby:${RUBY_VERSION}-${DEBIAN_BASE} AS base
LABEL maintainer="operations@openproject.com"

ARG NODE_VERSION="22.21.0"
ARG BIM_SUPPORT=true
ENV USE_JEMALLOC=false
ENV DEBIAN_FRONTEND=noninteractive
ENV BUNDLE_JOBS=8
ENV BUNDLE_RETRY=3
ENV BUNDLE_WITHOUT="development:test"

# SYSTEM
ENV DOCKER=1
ENV APP_USER=app
ENV APP_PATH=/app
ENV APP_DATA_PATH=/var/openproject/assets
ENV PGVERSION="17"
ENV PGVERSION_CHOICES="13 15 17"
ENV PGBIN="/usr/lib/postgresql/$PGVERSION/bin"
ENV PATH="$PGBIN:$PATH"
ENV BUNDLE_WITHOUT="development:test"

# RAILS
# Set a default key base, ensure to provide a secure value in production environments!
ENV SECRET_KEY_BASE=OVERWRITE_ME
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1
ENV RAILS_SERVE_STATIC_FILES=1

# OPENPROJECT
# Valid values are: standard,bim
ENV OPENPROJECT_EDITION=standard
ENV OPENPROJECT_INSTALLATION__TYPE=docker
ENV OPENPROJECT_ATTACHMENTS__STORAGE__PATH=$APP_DATA_PATH/files
ENV OPENPROJECT_RAILS__CACHE__STORE=file_store
ENV OPENPROJECT_ANGULAR_UGLIFY=true

RUN useradd -d /home/$APP_USER -m $APP_USER && \
  mkdir -p $APP_PATH && chown $APP_USER:$APP_USER $APP_PATH && \
  mkdir -p $APP_DATA_PATH && chown $APP_USER:$APP_USER $APP_DATA_PATH && chmod g+rwx $APP_DATA_PATH

WORKDIR $APP_PATH

# upgrade bundler
RUN gem install bundler --no-document

# system dependencies, nodejs
COPY ./docker/prod/setup/preinstall-common.sh ./docker/prod/setup/preinstall-common.sh
RUN ./docker/prod/setup/preinstall-common.sh

# stuff required for gems
COPY Gemfile Gemfile.* .ruby-version ./
COPY modules ./modules
# Add vendor for saas-openproject plugins
COPY vendor ./vendor
# Add lib in case a plugin tries to load VERSION file under lib
COPY lib ./lib

COPY ./docker/prod/setup/bundle-install.sh ./vendor/bundle* ./vendor/
RUN bash vendor/bundle-install.sh && rm vendor/bundle-install.sh

COPY . .

# Copy lock file again as the updated version was overriden by COPY just now
RUN cp Gemfile.lock.bak Gemfile.lock && rm Gemfile.lock.bak && \
  ./docker/prod/setup/precompile-assets.sh && \
  ./docker/prod/setup/postinstall-common.sh && \
  cp ./config/database.production.yml config/database.yml && \
  ln -s $APP_PATH/docker/prod/setup/.irbrc /home/$APP_USER/

# -------------------------------------
# slim (public)
# -------------------------------------
FROM base AS slim

USER $APP_USER
EXPOSE 8080
CMD ["./docker/prod/web"]
ENTRYPOINT ["./docker/prod/entrypoint-slim.sh"]
VOLUME ["$APP_DATA_PATH"]

# -------------------------------------
# slim-bim (public)
# same as slim but with BIM support enabled
# -------------------------------------
FROM base AS slim-bim

USER $APP_USER
EXPOSE 8080
CMD ["./docker/prod/web"]
ENTRYPOINT ["./docker/prod/entrypoint-slim.sh"]
VOLUME ["$APP_DATA_PATH"]
ENV OPENPROJECT_EDITION=bim
# -------------------------------------
# all-in-one (public)
# -------------------------------------
FROM base AS all-in-one

ENV OPENPROJECT_RAILS__CACHE__STORE=memcache
ENV DATABASE_URL=postgres://openproject:openproject@127.0.0.1/openproject
ENV PGDATA=/var/openproject/pgdata

COPY --from=openproject/gosu /go/bin/gosu /usr/local/bin/gosu
RUN chmod +x /usr/local/bin/gosu && gosu nobody true

RUN ./docker/prod/setup/postinstall-onprem.sh && \
  ln -s /app/docker/prod/setup/.irbrc /root/

# Expose ports for apache and postgres
EXPOSE 80

# Expose the postgres data directory and OpenProject data directory as volumes
VOLUME ["$PGDATA", "$APP_DATA_PATH"]

# Set a custom entrypoint to allow for privilege dropping and one-off commands
ENTRYPOINT ["./docker/prod/entrypoint.sh"]

# Set default command to launch the all-in-one configuration supervised by supervisord
CMD ["./docker/prod/supervisord"]
