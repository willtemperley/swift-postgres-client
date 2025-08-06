# Setting up a Postgres database for testing

To run the test suite, you need access to a PostgreSQL server built with SSL support.
The tests were adapted from [PostgresClientKit](https://github.com/codewinsdotcom/PostgresClientKit) hence the naming.

After [installing Postgres](https://www.postgresql.org/download/), follow the steps below to configure Postgres and set up a test database and users.

Two servers need to be available - one running on 5432 with ssl = on, and one running on 5433 with ssl = off (the default).
Alternatively just comment out the environments in `BasicConnectionTests` that use the server running on 5433.

## Configure Postgres

In `postgresql.conf`, for the server running on 5432, ensure:

    ssl = on
    password_encryption = scram-sha-256
    
If running Postgres on a different host than PostgresClientKit, confirm `postgresql.conf` also sets [`listen_addresses`](https://www.postgresql.org/docs/current/runtime-config-connection.html#RUNTIME-CONFIG-CONNECTION-SETTINGS) to the desired network interface.
    
## Configure authentication

Add the following lines to `pg_hba.conf`, placing them before other configuration records.

```
# For PostgresClientKit testing
host    postgresclientkittest   terry_postgresclientkittest     0.0.0.0/0       trust
host    postgresclientkittest   terry_postgresclientkittest     ::0/0           trust
host    postgresclientkittest   charlie_postgresclientkittest   0.0.0.0/0       password
host    postgresclientkittest   charlie_postgresclientkittest   ::0/0           password
host    postgresclientkittest   mary_postgresclientkittest      0.0.0.0/0       md5
host    postgresclientkittest   mary_postgresclientkittest      ::0/0           md5
host    postgresclientkittest   sally_postgresclientkittest     0.0.0.0/0       scram-sha-256
host    postgresclientkittest   sally_postgresclientkittest     ::0/0           scram-sha-256
```

This configures how Postgres authenticates three test users.

- User `terry_postgresclientkittest` authenticates by `trust` (no password)
- User `charlie_postgresclientkittest` authenticates by `password` (a cleartext password)
- User `mary_postgresclientkittest` authenticates by `md5` (an MD5 hash of the username, password, and random salt)
- User `sally_postgresclientkittest` authenticates by `scram-sha-256` (the most secure authentication mechanism supported)

(The users will be created below.)

**Security note:**  If the Postgres database accepts connections from other hosts, you should modify the lines added to `pg_hba.conf` to restrict the allowed client IP addresses.  See the [Postgres documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html) for details.

## Restart Postgres

Restart Postgres to pick up the changes made above.

## Create a test database and test users

The `CreateTestEnvironment.sql` script creates a test database (named `postgresclientkittest`) and three test users.

To execute the script:

```
  cd <path-to-clone>/Tests/Scripts
  psql --host=<host> --port=<port> --dbname=<dbname> --username=<superuser> < CreateTestEnvironment.sql
```
   
where:

- `<host>` is the hostname for the Postgres server
- `<port>` is the port number for the Postgres server (5432 by default)
- `<dbname>` is the name of any existing database on the Postgres server
- `<superuser>` is the name of the Postgres superuser

For example:

```bash
psql --host=127.0.0.1 --port=5432 --dbname=postgres --username=root < CreateTestEnvironment.sql 
```

## Review the test suite configuration

The file `Tests/SwiftPostgresClientTests/TestEnvironment.swift` describes the environment used by the PostgresClientKit test suite.  Review its content and make any changes for your environment.

Note that most test functions run in an isolated schema named `test_<uuid>`. This avoids data races caused by tests executing in parallel updating the same table. During development if tests are stopped before completion, a schema may not be torn down and will require manual cleanup. These schema are automatically cleaned up if tests are allowed to run to completion.
