# Use the official Debian image as the base
FROM debian:latest

# Install PostgreSQL
RUN apt-get update && \
    apt-get install -y postgresql postgresql-contrib && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV POSTGRES_DB=mydatabase
ENV POSTGRES_USER=myuser
ENV POSTGRES_PASSWORD=mypassword

# Expose PostgreSQL port
EXPOSE 5432

# Create a volume mount point for PostgreSQL data
VOLUME /var/lib/postgresql/data

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Set the default command to run PostgreSQL
CMD ["postgres", "-D", "/var/lib/postgresql/data"]
