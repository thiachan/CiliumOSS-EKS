region          = "ap-southeast-2"
cluster_name    = "isovalent-syd"
cluster_version = "1.30"

instance_type     = "m5.large"
node_desired_size = 2
node_min_size     = 2
node_max_size     = 2

cilium_version   = "1.15.6"
tetragon_version = "1.1.2"
