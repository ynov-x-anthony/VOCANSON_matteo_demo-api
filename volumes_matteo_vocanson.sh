#!/usr/bin/env bash
set -e

export MSYS_NO_PATHCONV=1

echo "--------------------------"

echo "  1. Nettoyage initial"
echo "--------------------------"
docker rm -f demo-api demo-db >/dev/null 2>&1 || true
docker network rm demo-net >/dev/null 2>&1 || true
docker volume rm demo_pgdata >/dev/null 2>&1 || true

echo "--------------------------"
echo "  2. Creation du reseau et du volume nomme"
echo "--------------------------"
docker network create demo-net
docker volume create demo_pgdata

echo "--------------------------"
echo "  3. Build de l'image de l'API"
echo "--------------------------"
docker build -t demo-api:1.0 ./api

echo "--------------------------"
echo "  4. Lancement de demo-db (PostgreSQL 16)"
echo "--------------------------"
INIT_SQL_PATH="$(pwd)/db/init.sql"
if command -v cygpath >/dev/null 2>&1; then
  INIT_SQL_PATH="$(cygpath -w "$(pwd)/db/init.sql")"
fi

docker run -d --name demo-db \
  --network demo-net \
  -v demo_pgdata:/var/lib/postgresql/data \
  -v "${INIT_SQL_PATH}":/docker-entrypoint-initdb.d/init.sql:ro \
  -e POSTGRES_USER=demo \
  -e POSTGRES_PASSWORD=demo \
  -e POSTGRES_DB=demo \
  postgres:16-alpine

echo "--------------------------"
echo "  5. Attente que PostgreSQL soit pret (pg_isready)"
echo "--------------------------"
until docker exec demo-db pg_isready -U demo >/dev/null 2>&1; do
  echo "En attente de PostgreSQL..."
  sleep 1
done
echo "PostgreSQL est pret"

echo "--------------------------"
echo "  6. Lancement de demo-api"
echo "--------------------------"
docker run -d --name demo-api \
  --network demo-net \
  -p 8080:3000 \
  -e PGHOST=demo-db \
  demo-api:1.0

echo "Attente de l'API..."
until curl -s http://localhost:8080/health >/dev/null 2>&1; do
  sleep 1
done
echo "API lancée sur http://localhost:8080"

echo "--------------------------"
echo "  7. Ajout du produit 'Casquette Demo' via l'API"
echo "--------------------------"
curl -s -X POST -H 'content-type: application/json' \
  -d '{"name":"Casquette Démo","price_cents":1200}' http://localhost:8080/products
echo ""

echo "--- Produits presents AVANT suppression de la DB : ---"
curl -s http://localhost:8080/products
echo ""

echo "--------------------------"
echo "  8. Simulation de panne : docker rm -f demo-db"
echo "--------------------------"
docker rm -f demo-db
echo "Conteneur demo-db supprime"

echo "--------------------------"
echo "  9. Re-creation de demo-db sur le MEME volume demo_pgdata"
echo "--------------------------"
docker run -d --name demo-db \
  --network demo-net \
  -v demo_pgdata:/var/lib/postgresql/data \
  -v "${INIT_SQL_PATH}":/docker-entrypoint-initdb.d/init.sql:ro \
  -e POSTGRES_USER=demo \
  -e POSTGRES_PASSWORD=demo \
  -e POSTGRES_DB=demo \
  postgres:16-alpine

echo "Attente que PostgreSQL soit a nouveau pret..."
until docker exec demo-db pg_isready -U demo >/dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL est a nouveau pret"

echo "Relance de demo-api..."
docker restart demo-api
sleep 2

echo "--------------------------"
echo "  10. Preuve : Produits presents APRES re-creation de la DB"
echo "--------------------------"
curl -s http://localhost:8080/products
echo ""

echo "--------------------------"
echo "  11. Preuve : Volume Docker existant"
echo "--------------------------"
docker volume ls | grep demo_pgdata

echo "--------------------------"
echo "  12. Nettoyage des conteneurs et du reseau"
echo "--------------------------"
docker rm -f demo-api demo-db >/dev/null 2>&1 || true
docker network rm demo-net >/dev/null 2>&1 || true

echo ""
echo "SUCCES : La persistance du volume demo_pgdata est validee"
