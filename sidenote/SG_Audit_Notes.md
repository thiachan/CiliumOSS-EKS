# Security Group Audit — EKS `isovalent-syd` (ap-southeast-2)

> Side reference only. Date of audit: 2026-06-21. VPC: `vpc-0fcacc6025ece912c`.
> Question asked: *do any security groups for this EKS (and related) have inbound rules
> allowing source = any (`0.0.0.0/0` / `::/0`)?*
> **Answer: the EKS-managed SGs are clean; two Kubernetes LoadBalancer SGs are open to any.**

## EKS core security groups — OK (no any-source inbound)

Only intra-cluster / control-plane ↔ node traffic; nothing from `0.0.0.0/0`.

| SG ID | Purpose |
|-------|---------|
| `sg-0148c2e764c7494b7` | EKS cluster security group |
| `sg-092cf92a4bdc04a49` | EKS primary SG (control plane ↔ nodes / managed workloads) |
| `sg-0f1c1e02c97ddc454` | EKS node shared security group |
| `sg-09d2da7a4d1b01a2c` | default VPC security group |

## LoadBalancer security groups — OPEN TO ANY (`0.0.0.0/0`)

| SG ID | Service | Open inbound | Notes |
|-------|---------|--------------|-------|
| `sg-0d80b252174816a24` | `boutique/frontend-external` | TCP **80** (+ ICMP 3/4) | Expected — public Online Boutique storefront (demo). Low risk. |
| `sg-0152beaaa17f82849` | **ClusterMesh apiserver** | TCP **2379** (+ ICMP 3/4) | **Concern** — ClusterMesh etcd/2379 exposed to the entire internet. |

- ICMP type 3/4 = Path-MTU discovery → normal/harmless.
- Source of the 2379 exposure: `clustermesh.apiserver.service.type: LoadBalancer` in
  `cilium/values.yaml.tftpl` creates a **public** load balancer.

## Remediation options (for the 2379 / ClusterMesh exposure)

1. **Make it internal** (recommended if ClusterMesh will be used):
   ```yaml
   clustermesh:
     useAPIServer: true
     apiserver:
       service:
         type: LoadBalancer
         annotations:
           service.beta.kubernetes.io/aws-load-balancer-internal: "true"
   ```
2. **Restrict source** to known peer IPs via `loadBalancerSourceRanges`.
3. **Disable until needed** — `clustermesh.useAPIServer: false` (removes the public LB + SG).

Optional: lock the boutique frontend to your own IP with `loadBalancerSourceRanges`.

## How to re-run this audit

```bash
export AWS_DEFAULT_REGION=ap-southeast-2
VPC=$(aws eks describe-cluster --name isovalent-syd --query 'cluster.resourcesVpcConfig.vpcId' --output text)
aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC \
  --query "SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,OpenInbound:IpPermissions[?contains(to_string(IpRanges[].CidrIp),'0.0.0.0/0') || contains(to_string(Ipv6Ranges[].CidrIpv6),'::/0')].{Proto:IpProtocol,From:FromPort,To:ToPort,V4:IpRanges[].CidrIp,V6:Ipv6Ranges[].CidrIpv6}}" \
  --output json | jq '[.[] | select((.OpenInbound|length)>0)]'
```
