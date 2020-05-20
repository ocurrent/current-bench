FROM postgres:12

FROM library/postgres

# From here:
# https://stackoverflow.com/questions/26598738/how-to-create-user-database-in-script-for-docker-postgres
#
COPY init.sql /docker-entrypoint-initdb.d/

# Expose the PostgreSQL port
EXPOSE 5432

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

# Set the default command to run when starting the container
# This should ideally work, but gives a no such file or directory error so
# not using this for now.
#CMD ["/usr/lib/postgresql/12/bin/postgres", "-D", "/var/lib/postgresql/12/main", "-c", "config_file=/etc/postgresql/12/main/postgresql.conf"]

