#!/bin/bash

# Script de déploiement automatisé pour Vault avec corrections KDF
# Usage: ./deploy-vault-production.sh

set -e

# Configuration
VAULT_VERSION="1.20.4-kdf-custom"
VAULT_DOMAIN="vault.votre-domaine.com"
DATA_DIR="/opt/vault"
CONFIG_DIR="./vault-config"

echo "🚀 Déploiement de Vault Production avec corrections KDF ed25519"
echo "Version: $VAULT_VERSION"
echo "Domaine: $VAULT_DOMAIN"

# Vérifications préalables
echo "📋 Vérifications préalables..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose n'est pas installé"
    exit 1
fi

# Créer les répertoires de données
echo "📁 Création des répertoires de données..."
sudo mkdir -p $DATA_DIR/data $DATA_DIR/logs
sudo chown -R 1000:1000 $DATA_DIR

# Vérifier les certificats TLS
echo "🔐 Vérification des certificats TLS..."
if [ ! -f "$CONFIG_DIR/vault-cert.pem" ] || [ ! -f "$CONFIG_DIR/vault-key.pem" ]; then
    echo "⚠️ Certificats TLS manquants. Génération d'un certificat auto-signé..."
    mkdir -p $CONFIG_DIR
    
    openssl req -x509 -newkey rsa:4096 \
        -keyout $CONFIG_DIR/vault-key.pem \
        -out $CONFIG_DIR/vault-cert.pem \
        -days 365 -nodes \
        -subj "/C=FR/ST=France/L=Paris/O=Organization/CN=$VAULT_DOMAIN"
    
    echo "✅ Certificat auto-signé généré"
    echo "⚠️ ATTENTION: Utilisez un certificat valide en production!"
else
    echo "✅ Certificats TLS trouvés"
fi

# Vérifier la configuration
echo "⚙️ Vérification de la configuration..."
if [ ! -f "$CONFIG_DIR/vault.hcl" ]; then
    echo "❌ Fichier de configuration vault.hcl manquant"
    echo "Copiez le fichier exemple depuis vault-config/vault.hcl"
    exit 1
fi

# Mise à jour de la configuration avec le bon domaine
sed -i "s/vault.votre-domaine.com/$VAULT_DOMAIN/g" $CONFIG_DIR/vault.hcl
sed -i "s/vault.votre-domaine.com/$VAULT_DOMAIN/g" docker-compose.production.yml

echo "✅ Configuration mise à jour avec le domaine $VAULT_DOMAIN"

# Arrêter les conteneurs existants
echo "🛑 Arrêt des conteneurs existants..."
docker-compose -f docker-compose.production.yml down --remove-orphans || true

# Construction de l'image
echo "🔨 Construction de l'image Vault personnalisée..."
docker-compose -f docker-compose.production.yml build --no-cache

# Démarrage des services
echo "🚀 Démarrage de Vault..."
docker-compose -f docker-compose.production.yml up -d

# Attente que Vault soit prêt
echo "⏳ Attente que Vault soit prêt..."
for i in {1..30}; do
    if docker exec vault-kdf-custom vault status &>/dev/null; then
        break
    fi
    echo "Tentative $i/30..."
    sleep 2
done

# Vérification du statut
echo "🔍 Vérification du statut..."
if docker exec vault-kdf-custom vault status; then
    echo "✅ Vault est démarré et répond"
else
    echo "❌ Problème avec le démarrage de Vault"
    echo "📋 Logs:"
    docker-compose -f docker-compose.production.yml logs vault
    exit 1
fi

# Instructions d'initialisation
echo ""
echo "🎉 Déploiement terminé avec succès!"
echo ""
echo "📝 Prochaines étapes:"
echo ""
echo "1. Initialiser Vault (première fois seulement):"
echo "   docker exec -it vault-kdf-custom vault operator init"
echo ""
echo "2. Unsealer Vault avec 3 clés:"
echo "   docker exec -it vault-kdf-custom vault operator unseal <key1>"
echo "   docker exec -it vault-kdf-custom vault operator unseal <key2>"
echo "   docker exec -it vault-kdf-custom vault operator unseal <key3>"
echo ""
echo "3. Configurer les variables d'environnement:"
echo "   export VAULT_ADDR=\"https://$VAULT_DOMAIN:8200\""
echo "   export VAULT_TOKEN=\"<root-token>\""
echo ""
echo "4. Tester les corrections KDF ed25519:"
echo "   vault secrets enable transit"
echo "   vault write transit/keys/test-ed25519 type=ed25519 derived=true"
echo "   vault read transit/keys/test-ed25519"
echo ""
echo "🌐 Interface Web: https://$VAULT_DOMAIN:8200"
echo "📊 Métriques: https://$VAULT_DOMAIN:8200/v1/sys/metrics?format=prometheus"
echo ""
echo "📋 Commandes utiles:"
echo "   - Logs: docker-compose -f docker-compose.production.yml logs -f vault"
echo "   - Status: docker exec vault-kdf-custom vault status"
echo "   - Shell: docker exec -it vault-kdf-custom sh"
echo ""
echo "⚠️ N'oubliez pas de:"
echo "   - Sauvegarder les clés d'unsealing et le root token"
echo "   - Configurer un certificat TLS valide"
echo "   - Configurer le firewall (ports 8200, 8201)"
echo "   - Planifier les sauvegardes régulières"