#!/usr/bin/env bash
set -e

# Empeche MSYS / Git Bash de convertir les chemins UNIX en chemins Windows dans les options Docker
export MSYS_NO_PATHCONV=1

echo "=========================================================="
echo "  Challenge Reseaux Docker - demo-api & PostgreSQL"
echo "=========================================================="

echo ""
echo "----------------------------------------------------------"
echo "  1. Nettoyage prealable des conteneurs et reseaux"
echo "----------------------------------------------------------"
docker rm -f demo-api demo-db >/dev/null 2>&1 || true
docker network rm demo_front demo_back >/dev/null 2>&1 || true

echo ""
echo "----------------------------------------------------------"
echo "  2. Creation des reseaux personnalises (demo_front et demo_back)"
echo "----------------------------------------------------------"
docker network create demo_front
docker network create demo_back
echo "Reseaux crees :"
docker network ls | grep -E "demo_front|demo_back"

echo ""
echo "----------------------------------------------------------"
echo "  3. Build de l'image de l'API (demo-api:1.0)"
echo "----------------------------------------------------------"
docker build -t demo-api:1.0 ./api

echo ""
echo "----------------------------------------------------------"
echo "  4. Lancement de demo-db sur demo_back uniquement (sans -p)"
echo "----------------------------------------------------------"
INIT_SQL_PATH="$(pwd)/db/init.sql"
if command -v cygpath >/dev/null 2>&1; then
  INIT_SQL_PATH="$(cygpath -m "$(pwd)/db/init.sql")"
fi

docker run -d --name demo-db \
  --network demo_back \
  -v "${INIT_SQL_PATH}":/docker-entrypoint-initdb.d/init.sql:ro \
  -e POSTGRES_USER=demo \
  -e POSTGRES_PASSWORD=demo \
  -e POSTGRES_DB=demo \
  postgres:16-alpine

echo "Attente que PostgreSQL soit pret..."
until docker exec demo-db pg_isready -U demo >/dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL est pret"

echo ""
echo "----------------------------------------------------------"
echo "  5. Lancement de demo-api sur demo_front et connexion a demo_back"
echo "----------------------------------------------------------"
docker run -d --name demo-api \
  --network demo_front \
  -p 8080:3000 \
  -e PGHOST=demo-db \
  demo-api:1.0

# Connexion au second reseau demo_back
docker network connect demo_back demo-api

echo "Attente que demo-api soit operationnelle..."
until curl -s http://localhost:8080/ready | grep -q 'READY'; do
  sleep 1
done
echo "demo-api est operationnelle sur http://localhost:8080"

echo ""
echo "----------------------------------------------------------"
echo "  6. Verification 1 : demo-api joint demo-db par son nom (DNS interne)"
echo "----------------------------------------------------------"
docker exec demo-api getent hosts demo-db

echo ""
echo "----------------------------------------------------------"
echo "  7. Verification 2 : Conteneur tiers sur demo_front ne joint PAS demo-db (Echec attendu)"
echo "----------------------------------------------------------"
set +e
docker run --rm --network demo_front alpine nc -zv -w 2 demo-db 5432
RET_NC=$?
set -e
if [ $RET_NC -ne 0 ]; then
  echo "(Echec confirme : le conteneur tiers sur demo_front ne peut pas resoudre ni joindre demo-db)"
fi

echo ""
echo "----------------------------------------------------------"
echo "  8. Verification 3 : Adresses IPv4 des conteneurs"
echo "----------------------------------------------------------"
echo "IPv4 demo-db (connecte a demo_back) :"
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAMConfig}} {{.IPAddress}}{{"\n"}}{{end}}' demo-db

echo "IPv4 demo-api (connecte a demo_front et demo_back) :"
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAMConfig}} {{.IPAddress}}{{"\n"}}{{end}}' demo-api

echo ""
echo "----------------------------------------------------------"
echo "  9. Verification 4 : Reponse de l'API (/products)"
echo "----------------------------------------------------------"
curl -s http://localhost:8080/products
echo ""

echo ""
echo "----------------------------------------------------------"
echo "  10. Nettoyage des conteneurs et des reseaux"
echo "----------------------------------------------------------"
docker rm -f demo-api demo-db >/dev/null 2>&1 || true
docker network rm demo_front demo_back >/dev/null 2>&1 || true
echo "Nettoyage termine avec succes."
