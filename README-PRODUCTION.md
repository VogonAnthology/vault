# Vault Production avec Corrections KDF ed25519

Cette version de Vault v1.20.4 inclut des corrections pour le problème de KDF des clés ed25519 dérivées.

## Fonctionnalités

- ✅ **Correction KDF ed25519** : Les clés ed25519 avec `derived=true` utilisent maintenant correctement `hkdf_sha256` au lieu de `hmac-sha256-counter`
- ✅ **Image Docker de production** : Multi-stage build optimisé avec Alpine Linux
- ✅ **Configuration de sécurité** : Utilisateur non-root, capabilities limitées, TLS configuré
- ✅ **Monitoring** : Healthchecks et métriques Prometheus intégrés

## Modifications Apportées

### Fichiers Modifiés pour la Correction KDF :
- `sdk/helper/keysutil/lock_manager.go` - Logique de correction KDF
- `sdk/helper/keysutil/policy.go` - Méthodes de politique
- `builtin/logical/transit/backend.go` - Enregistrement des endpoints
- `builtin/logical/transit/path_import.go` - Support des paramètres KDF

## Déploiement en Production

### 1. Préparation des Certificats TLS

```bash
# Créer le répertoire de configuration
mkdir -p vault-config

# Générer un certificat auto-signé (pour test uniquement)
openssl req -x509 -newkey rsa:4096 -keyout vault-config/vault-key.pem \
    -out vault-config/vault-cert.pem -days 365 -nodes \
    -subj "/C=FR/ST=State/L=City/O=Organization/CN=vault.votre-domaine.com"

# Ou copier vos certificats existants
# cp your-vault-cert.pem vault-config/vault-cert.pem
# cp your-vault-key.pem vault-config/vault-key.pem
```

### 2. Préparation des Répertoires de Données

```bash
# Créer les répertoires de données persistantes
sudo mkdir -p /opt/vault/data /opt/vault/logs
sudo chown -R 1000:1000 /opt/vault
```

### 3. Construction et Déploiement

```bash
# Cloner votre fork avec les modifications
git clone https://github.com/VotreUsername/vault.git
cd vault
git checkout kdf-ed25519-fix-1.20.4

# Construire et démarrer
docker-compose -f docker-compose.production.yml up -d --build
```

### 4. Initialisation de Vault

```bash
# Attendre que Vault soit prêt
docker-compose -f docker-compose.production.yml logs -f vault

# Initialiser Vault (première fois seulement)
docker exec -it vault-kdf-custom vault operator init

# Unsealer Vault avec les clés obtenues
docker exec -it vault-kdf-custom vault operator unseal <unseal-key-1>
docker exec -it vault-kdf-custom vault operator unseal <unseal-key-2>
docker exec -it vault-kdf-custom vault operator unseal <unseal-key-3>
```

### 5. Test des Corrections KDF

```bash
# Se connecter à Vault
export VAULT_ADDR="https://vault.votre-domaine.com:8200"
export VAULT_TOKEN="<root-token>"

# Activer le moteur transit
vault secrets enable transit

# Tester la création d'une clé ed25519 dérivée
vault write transit/keys/test-ed25519 \
    type=ed25519 \
    derived=true

# Vérifier que le KDF est correct (devrait être "hkdf_sha256")
vault read transit/keys/test-ed25519

# Tester l'importation avec dérivation
vault write transit/keys/imported-ed25519/import \
    type=ed25519 \
    derived=true \
    public_key="<votre-clé-publique-ed25519>"

# Vérifier le KDF de la clé importée
vault read transit/keys/imported-ed25519
```

## Configuration de Production

### Variables d'Environnement Importantes

```bash
# Dans docker-compose.production.yml
VAULT_ADDR=https://0.0.0.0:8200
VAULT_API_ADDR=https://vault.votre-domaine.com:8200
VAULT_CLUSTER_ADDR=https://0.0.0.0:8201
```

### Stockage Backend Recommandé

Pour la production, remplacez le stockage file par Consul :

```hcl
# Dans vault-config/vault.hcl
storage "consul" {
  address = "consul.votre-domaine.com:8500"
  path    = "vault/"
}
```

### Auto-Unseal Recommandé

```hcl
# Dans vault-config/vault.hcl
seal "awskms" {
  region     = "us-west-2"
  kms_key_id = "your-kms-key-id"
}
```

## Monitoring et Logs

```bash
# Voir les logs
docker-compose -f docker-compose.production.yml logs -f vault

# Vérifier le statut
docker exec -it vault-kdf-custom vault status

# Métriques Prometheus
curl https://vault.votre-domaine.com:8200/v1/sys/metrics?format=prometheus
```

## Sécurité

### Bonnes Pratiques Appliquées :

- ✅ Utilisateur non-root (uid:1000)
- ✅ Capabilities minimales (IPC_LOCK uniquement)
- ✅ TLS obligatoire
- ✅ Volumes en lecture seule pour la config
- ✅ Limites de ressources
- ✅ Healthchecks intégrés

### Configuration Firewall :
```bash
# Autoriser uniquement les ports nécessaires
ufw allow 8200/tcp  # API Vault
ufw allow 8201/tcp  # Cluster Vault (si multi-nœuds)
```

## Backup et Restauration

```bash
# Backup des données
docker run --rm -v vault-data:/source:ro -v $(pwd):/backup \
    alpine tar czf /backup/vault-backup-$(date +%Y%m%d).tar.gz -C /source .

# Restauration
docker run --rm -v vault-data:/target -v $(pwd):/backup \
    alpine tar xzf /backup/vault-backup-YYYYMMDD.tar.gz -C /target
```

## Support

Version basée sur HashiCorp Vault v1.20.4 avec corrections personnalisées pour les clés ed25519.

Pour les questions spécifiques aux modifications KDF, référez-vous aux commits dans la branche `kdf-ed25519-fix-1.20.4`.