# Spring Cloud Config Server + HashiCorp Vault

A secure configuration management setup using:

- Spring Cloud Config Server
- HashiCorp Vault
- Vault KV v2
- AppRole Authentication
- Nginx Reverse Proxy
- Dockerized Vault with Raft Storage

---

# Architecture
```TEXT
Spring Boot Client
        |
        v
Spring Cloud Config Server
        |
        v
HashiCorp Vault
        |
        v
KV v2 Secret Engine
```

Features
    - Centralized configuration management
    - Secure secret storage using Vault
    - AppRole authentication for machine-to-machine access
    - Profile-based secret loading
    - Vault exposed securely through HTTPS

Vault Setup
    Docker Compose

```YAML
services:
  vault:
    image: hashicorp/vault:latest
    restart: always
    container_name: vault
    network_mode: host

    cap_add:
      - IPC_LOCK

    environment:
      - VAULT_API_ADDR=https://vault.devith.it.com
      - VAULT_UI=true

    volumes:
      - ./config:/vault/config
      - ./data:/vault/data

    entrypoint: vault
    command: server -config=/vault/config/vault.hcl
```

    Vault Configuration
        File: config/vault.hcl
```hcl
ui = true
disable_mlock = true

api_addr     = "https://vault.devith.it.com"
cluster_addr = "http://127.0.0.1:8201"

storage "raft" {
  path = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address         = "127.0.0.1:8200"
  cluster_address = "127.0.0.1:8201"
  tls_disable     = 1
}
```


```BASH
#Start Vault
docker compose up -d
docker compose logs -f

#Initialize Vault
docker exec -it vault vault operator init
    #Save:
        #- Unseal Keys
        #- Root Token

#Unseal Vault
docker exec -it vault vault operator unseal
    #Run the command 3 times using different unseal keys.

#Login
docker exec -it vault vault login

#Enable KV v2
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault secrets enable -path=kv kv-v2

#Store Secret
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault kv put kv/account/dev username=devith password=123456

#AppRole Authentication
    #Enable AppRole
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault auth enable approle

    #Create Policy
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -i vault \
vault policy write configserver-policy - <<'EOF'
path "kv/data/account" {
  capabilities = ["read"]
}

path "kv/data/account/*" {
  capabilities = ["read"]
}
EOF

    #Create AppRole
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault write auth/approle/role/configserver-role \
token_policies="configserver-policy" \
token_type="batch"

    #Get Role ID
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault read auth/approle/role/configserver-role/role-id

    #Generate Secret ID
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault write -f auth/approle/role/configserver-role/secret-id
        #Save:
            #role_id
            #secret_id
```

Secret Resolution
```text
# Request:
/account/dev

# Vault lookup:
kv/account
kv/account/dev
```

Test Config Server
```bash
curl http://localhost:8888/account/dev
```

Expected response:
```json
{
  "name": "account",
  "profiles": ["dev"],
  "propertySources": [
    {
      "name": "vault:account/dev",
      "source": {
        "username": "devith",
        "password": "123456"
      }
    }
  ]
}
```

Useful Commands
```bash
# Read Secret
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -it vault \
vault kv get kv/account/dev

# Test AppRole Login
curl --request POST \
  --data '{
    "role_id":"ROLE_ID",
    "secret_id":"SECRET_ID"
  }' \
  https://vault.devith.it.com/v1/auth/approle/login
```

Here the example of using Vault in Spring Cloud Config Server
url: https://github.com/chengdevith/spring-cloud-config-server.git