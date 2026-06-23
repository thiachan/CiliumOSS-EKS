region          = "ap-southeast-2"
cluster_name    = "isovalent-syd"
cluster_version = "1.36"

instance_type     = "m5.large"
node_desired_size = 2
node_min_size     = 2
node_max_size     = 2

# Isovalent Enterprise (helm.isovalent.com)
cilium_version   = "1.18.10"
tetragon_version = "1.18.3"

# Provide the Isovalent/Cisco-issued pull secret out-of-band, e.g.:
#   export TF_VAR_isovalent_pull_secret_json="$(cat isovalent-pull-secret.json)"
# or place it in an UNCOMMITTED secrets.auto.tfvars. Do NOT commit credentials.
