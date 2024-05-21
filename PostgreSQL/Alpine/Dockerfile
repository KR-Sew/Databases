# Start with the Alpine base image
FROM alpine:latest

# Set environment variables for PostgreSQL
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=postgres

# Install PostgreSQL and other necessary packages
RUN apk update && \
    apk add --no-cache postgresql postgresql-contrib && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql

# Switch to the postgres user
USER postgres

# Initialize the PostgreSQL database cluster
RUN initdb -D /var/lib/postgresql/data

# Expose the default PostgreSQL port
EXPOSE 5432

# Set the default command to run PostgreSQL
CMD ["postgres", "-D", "/var/lib/postgresql/data"]

# Add a health check (optional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD pg_isready -U $POSTGRES_USER
