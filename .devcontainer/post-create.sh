#!/usr/bin/env bash
set -euo pipefail

# 1) PHP deps — skip auto-scripts to avoid cache:clear before DB is ready
composer install --no-interaction --prefer-dist --no-progress --no-scripts
composer dump-autoload --no-scripts

# 2) .env.local — include both granular APP_DATABASE_* and DATABASE_URL (Doctrine config in this repo reads these)
cat > .env.local <<'EOF'
SECURE_SCHEME=http

APP_SECRET=dev-secret

APP_ENV=dev
# Host-based routing
APP_FRONTEND_HOSTNAME=frontend.localtest.me
APP_ADMIN_HOSTNAME=admin.localtest.me

# MySQL
APP_DATABASE_DRIVER=pdo_mysql
APP_DATABASE_SERVER_VERSION=8.0
APP_DATABASE_HOST=db
APP_DATABASE_PORT=3306
APP_DATABASE_NAME=ldap
APP_DATABASE_USER=app
APP_DATABASE_PASSWORD=app
DATABASE_URL=mysql://app:app@db:3306/ldap

# Messenger transport (Doctrine)
MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=0

# Disable HTTPS enforcement locally
SECURE_SCHEME=

# Dev convenience: skip magic-link emails
APP_FEATURES=dev-auto-login
EOF

# 3) JS deps
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack enable
yarn --version
yarn install

# 4) Build assets
yarn dev

# 5) Wait for MySQL to be ready
echo "Waiting for MySQL @ db:3306..."
for i in {1..60}; do
  mysqladmin ping -h db -u root -proot --silent && break
  sleep 1
done

# 6) DB prepare
php bin/console doctrine:database:create --if-not-exists
php bin/console doctrine:migrations:migrate -n
php bin/console messenger:setup-transports

# 7) Now run Composer auto-scripts (cache:clear, assets:install, etc.)
XDEBUG_MODE=off composer run-script post-install-cmd
XDEBUG_MODE=off composer run-script post-update-cmd
