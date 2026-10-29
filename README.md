# demo-api

Le fil rouge des quêtes Docker : une mini-API "catalogue" conteneurisée, persistante, isolée en réseau, et orchestrée avec Docker Compose.

L'application repose sur :
- **api** : API REST Node.js / Express (`http://localhost:8080`)
- **db** : Base de données relationnelle PostgreSQL 16 Alpine (`demo_pgdata`)
- **adminer** : Interface web d'administration de base de données (`http://localhost:8081`)

---

## 🚀 Prérequis

- **Docker Engine** et **Docker Compose v2** (`docker compose` avec un espace)
- **Git**
- **curl** (ou terminal bash / WSL / Git Bash sous Windows)

Vérifiez vos versions :
```bash
docker --version
docker compose version
```

---

## ⚙️ Configuration & Secrets

### 1. Variables d'environnement
Copiez le fichier d'exemple pour initialiser votre configuration locale :
```bash
cp .env.example .env
```
*(Le fichier `.env` est ignoré par Git et ne doit jamais être commité).*

### 2. Gestion des Secrets (Bonus Docker Secrets)
Le mot de passe de la base de données ne transite pas en clair dans les variables d'environnement ni dans Git. Il est géré via un **Docker Secret** :
```bash
# Création du dossier et du fichier secret (ignoré par Git)
mkdir -p secrets
echo "change-moi" > secrets/db_password.txt
```

---

## 🏃 Démarrage de la stack

Pour construire les images et démarrer l'ensemble des services en tâche de fond :

```bash
docker compose up -d --build
```

Compose effectue automatiquement :
1. La création du réseau privé `demo-api_default` et du volume nommé `pgdata`.
2. Le montage sécurisé du secret dans `/run/secrets/db_password`.
3. Le lancement de `db` et l'exécution du script `db/init.sql`.
4. L'attente du healthcheck de `db` (`pg_isready`).
5. Le démarrage de l'API `api` dès que la base est prête (`service_healthy`).
6. Le lancement d'Adminer.

---

## 📊 État des services (`docker compose ps`)

Extrait de l'exécution confirmant la santé des conteneurs :

```text
NAME                                 IMAGE                          COMMAND                  SERVICE   CREATED          STATUS                    PORTS
vocanson_matteo_demo-api-adminer-1   adminer:4                      "entrypoint.sh docke…"   adminer   15 seconds ago   Up 14 seconds             0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
vocanson_matteo_demo-api-api-1       vocanson_matteo_demo-api-api   "docker-entrypoint.s…"   api       15 seconds ago   Up 9 seconds (healthy)    0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
vocanson_matteo_demo-api-db-1        postgres:16-alpine             "docker-entrypoint.s…"   db        15 seconds ago   Up 14 seconds (healthy)   5432/tcp
```

---

## 🌐 URLs d'accès

| Service | URL | Identifiants |
| :--- | :--- | :--- |
| **demo-api** | `http://localhost:8080` | Accès public |
| **Adminer** | `http://localhost:8081` | Système: `PostgreSQL` / Serveur: `db` / Utilisateur: `demo` / Mot de passe: `change-moi` / Base: `demo` |

---

## 🧪 Tests de fonctionnement et persistance

### 1. Consulter les produits initiaux
```bash
curl -s localhost:8080/products
```
Réponse attendue :
```json
[{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"..."},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"..."},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"..."}]
```

### 2. Ajouter un produit via l'API
```bash
curl -s -X POST -H 'content-type: application/json' \
  -d '{"name":"Gourde","price_cents":900}' localhost:8080/products
```
Réponse :
```json
{"id":4,"name":"Gourde","price_cents":900,"created_at":"..."}
```

### 3. Tester la persistance (arrêt puis relance de la stack)
```bash
docker compose down
docker compose up -d
curl -s localhost:8080/products
```
Le produit **"Gourde"** est toujours présent grâce au volume nommé `pgdata`.

---

## 🧹 Arrêter et repartir de zéro

- **Arrêter la stack en conservant les données** :
  ```bash
  docker compose down
  ```

- **Repartir complètement de zéro (supprimer conteneurs, réseau et volumes de données)** :
  ```bash
  docker compose down -v
  ```
  *(Au prochain démarrage, la base sera réinitialisée avec les données de `db/init.sql`).*
