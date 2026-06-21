variable "region" {
  description = "AWS region (Sydney)."
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "isovalent-syd"
}

variable "cluster_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
  default     = "m5.large"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "cilium_version" {
  description = "Cilium (OSS) Helm chart / image version."
  type        = string
  default     = "1.15.6"
}

variable "tetragon_version" {
  description = "Tetragon (OSS) Helm chart version."
  type        = string
  default     = "1.1.2"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project   = "isovalent-eks"
    Stack     = "cilium-oss"
    ManagedBy = "terraform"
    Region    = "ap-southeast-2"
  }
}
