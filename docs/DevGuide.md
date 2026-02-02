# Dev container workflow (MySQL + Symfony + Xdebug)

A minimal, fast local setup using **VS Code Dev Containers**, **PHP 8.3**, **Symfony**, **Webpack Encore**, **MySQL 8**, and **Xdebug**. 

Two terminals should bve all you need: one for assets watch, one for the PHP server (with on/off debug).

---

## Prerequisites
- Docker Desktop
- VS Code + “Dev Containers” extension
---

## First run

1) Open the repo in VS Code → **Reopen in Container**.  It'll try and launch Docker if it's not running.
   `post-create.sh` installs dependencies, builds assets, writes `.env.local`, creates the DB, runs migrations and sets up Messenger tables.

2) Open **two terminals** **inside the container**:

Terminal A (assets):
```bash
make watch
```

Terminal B (server):
```bash
make serve     # or: make debug-on  (to enable Xdebug)
```

You can view make help by running:

```bash
make help
```

3) Browse:
- Frontend: `http://frontend.localtest.me:8000`
- Admin:    `http://admin.localtest.me:8000`

> Use **http** in dev (HTTPS is disabled via dev config).  
> `localtest.me` resolves to `127.0.0.1`.

---

## Dev workflow

- Edit PHP/Twig/SCSS/JS.
- Assets rebuild automatically (`make watch`).
- PHP reloads per request.

## PHP intellisense issues
You'll most likely see a lot of red in your file explorer and circa 90 "Problems" in the Problems pane. You can overcome that by disabling PHP IntelliSense (Damjan Cvetko) which is installed into the conatiner as part of xdebug.php-pack.

### Toggle debugging (no container restart required)
```bash
make debug-on     # start/restart server with Xdebug
make debug-off    # restart server without Xdebug
make debug-status # show effective Xdebug config
```
VS Code → Run and Debug (using .vscode/launch.json) → **Listen for Xdebug** (port **9000**).

---

## MySQL

The dev DB runs in the `db` service (see `.devcontainer/docker-compose.yml`):

```yaml
image: mysql:8.0
MYSQL_DATABASE: ldap
MYSQL_USER: app
MYSQL_PASSWORD: app
MYSQL_ROOT_PASSWORD: root
```

You can connect to eh db using the following command in the workspace terminal:
```
mysql -h db -u app -papp ldap
```

`post-create.sh` writes the DSN into `.env.local`:
```env
DATABASE_URL="mysql://app:app@db:3306/ldap?serverVersion=8.0&charset=utf8mb4"
```

Useful commands:
```bash
bin/console doctrine:database:create --if-not-exists
bin/console doctrine:migrations:migrate -n
```

---

## Files

- `.devcontainer/devcontainer.json` – container definition; runs `post-create.sh`.  
- `.devcontainer/docker-compose.yml` – two services:
  - `app` (workspace container, PHP 8.3, port 8000)
  - `db`  (MySQL 8.0, health-checked, volume-backed)
- `.devcontainer/Dockerfile` – PHP 8.3 + extensions: `intl`, `pdo_mysql`, `zip`, `mbstring`, `xml`, `opcache`, `gd`, `gmp`, and **Xdebug**.
- `.devcontainer/post-create.sh` – Composer/Yarn install, asset build, `.env.local` (MySQL DSN), migrations, Messenger transports.
- `.vscode/launch.json` – PHP debug listener on **9000** with path mapping `/workspace → ${workspaceFolder}`.
- `config/packages/dev/nelmio_security.yaml` – dev overrides (no HSTS/forced SSL, permissive CSP for local assets).
- `config/packages/dev/security.yaml` – dev `access_control` using `requires_channel: null` to avoid http→https redirects.
- `makefile` – entry points for the local workflow (see below).
---

## Make targets

```bash
make watch         # Webpack Encore watch (assets)
make build         # Build assets once

make serve         # Start PHP server (no Xdebug)
make serve-stop    # Stop server
make serve-status  # Server status

make debug-on      # Start/restart server with Xdebug
make debug-off     # Restart server without Xdebug
make debug-status  # Print effective Xdebug config

make consume       # Start Messenger worker
make consume-stop  # Stop Messenger worker

make logs          # Tail server + messenger logs
make doctor        # Quick health check (port, process, assets)
make cli CMD="…"   # Run a PHP command (e.g., bin/console …)
make cli-debug CMD="…"  # Same, with Xdebug enabled

make hot           # Hot-restart server on PHP/Twig/YAML changes (no Xdebug)
make hot-debug     # Hot-restart with Xdebug; requires `entr`
```

### Hot reload
```bash
make hot          # or: make hot-debug
```

---

## Debugging notes

- VS Code configuration listens on **9000**.
- The PHP server is started with the correct Xdebug settings by `make debug-on`.

Sanity:
```bash
make debug-status
php -i | grep -E 'xdebug.client_(host|port)|xdebug.mode|start_with_request'
```

---

## Troubleshooting

- **CSS missing**: ensure you visit `http://…:8000` (not https). Run `make build`. Confirm dev Nelmio/Twig config is present.
- **Breakpoints not hit**: run `make debug-on`, ensure VS Code “Listen for Xdebug” is running on **9000**, refresh, inspect `make debug-status`.
- **Port 8000 busy**: `make serve-stop` then `make serve` (or `debug-on`).
- **MySQL not ready**: wait for compose health-check or `docker compose logs db`.

---

## Links
- Dev Containers: <https://code.visualstudio.com/docs/devcontainers/containers>  
- Xdebug step debugging: <https://xdebug.org/docs/step_debug>  
- Symfony form/themes: <https://symfony.com/doc/current/form/form_themes.html>