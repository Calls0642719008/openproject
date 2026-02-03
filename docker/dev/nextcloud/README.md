A minimal setup to run a Nextcloud inside the TLS-enabled docker development stack.

# First installation steps

1. Allow accessing OP through `openproject.local`:
    * `docker compose exec --user www-data nextcloud php occ config:system:set allow_local_remote_servers --value 1`
    * If using an alternative hostname: `docker compose exec --user www-data nextcloud php occ config:system:set trusted_domains 1 --value=nextcloud.example.com`
2. Import Dev CA cert into Nextcloud's own certificate store:
    * `docker compose cp /path/to/your/OpenProject_Development_Root_CA.crt nextcloud:/tmp/root.crt`
    * `docker compose exec nextcloud chown www-data /tmp/root.crt`
    * `docker compose exec --user www-data nextcloud php occ security:certificates:import /tmp/root.crt`
3. Configure Traefik as trusted proxy
    * e.g. `docker compose exec --user www-data nextcloud php occ config:system:set trusted_proxies 2 --value=172.0.0.0/8` for a pretty broad allowance for most docker services (verify that your `gateway` network uses IPs in the given address range)
4. Download/Activate Nextcloud plugins:
    * `integration_openproject`
    * `groupfolders` (dependency for certain OP functions)
