FROM postgres:12

ENV POSTGRES_PASSWORD docker
ENV POSTGRES_USER docker
ENV POSTGRES_DB docker

# From here:
# https://stackoverflow.com/questions/26598738/how-to-create-user-database-in-script-for-docker-postgres
#
COPY init.sql /docker-entrypoint-initdb.d/

# Expose the PostgreSQL port
EXPOSE 5432


