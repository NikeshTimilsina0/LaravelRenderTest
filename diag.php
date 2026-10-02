cat << 'EOF' > docker-inspect.sh
#!/bin/bash

echo "=== LARAVEL DOCKER REQUIREMENTS INSPECTOR ==="
echo ""

# 1. PHP Version
PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "Unknown")

# 2. Required PHP Extensions from composer.json
EXTENSIONS=$(php -r '
    $json = json_decode(@file_get_contents("composer.json"), true);
    $reqs = array_keys($json["require"] ?? []);
    $exts = array_filter($reqs, fn($k) => str_starts_with($k, "ext-"));
    echo implode(", ", array_map(fn($e) => str_replace("ext-", "", $e), $exts));
' 2>/dev/null)

# 3. Database Driver Detection
DB_DRIVERS=$(php -r '
    $env = @file_get_contents(".env") . "\n" . @file_get_contents(".env.example");
    preg_match_all("/DB_CONNECTION=([a-zA-Z0-9_]+)/", $env, $m);
    echo implode(", ", array_unique($m[1] ?? []));
' 2>/dev/null)

# 4. Frontend Asset Bundler & Node
HAS_PACKAGE_JSON=$(test -f package.json && echo "Yes" || echo "No")
HAS_LOCK_FILE=$(test -f package-lock.json && echo "package-lock.json" || (test -f yarn.lock && echo "yarn.lock" || (test -f pnpm-lock.yaml && echo "pnpm-lock.yaml" || echo "None")))
BUNDLER="None"
if [ -f vite.config.js ] || [ -f vite.config.ts ]; then BUNDLER="Vite"; fi
if [ -f webpack.mix.js ]; then BUNDLER="Laravel Mix"; fi

NODE_VER=$(node -v 2>/dev/null || echo "Not installed locally")

# 5. Key File Presence Check
ENTRY_POINT=$(test -f public/index.php && echo "public/index.php (Valid Laravel)" || echo "Missing public/index.php!")

cat << JSON
{
  "php_version": "$PHP_VER",
  "composer_extensions": "$EXTENSIONS",
  "detected_db_drivers": "$DB_DRIVERS",
  "has_package_json": "$HAS_PACKAGE_JSON",
  "lock_file": "$HAS_LOCK_FILE",
  "asset_bundler": "$BUNDLER",
  "local_node_version": "$NODE_VER",
  "entry_point": "$ENTRY_POINT"
}
JSON
EOF

chmod +x docker-inspect.sh
./docker-inspect.sh