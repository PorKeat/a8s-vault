ui = true
disable_mlock = true

api_addr     = "https://vault.devith.it.com"
cluster_addr = "http://127.0.0.1:8201"

storage "raft" {
  path = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}