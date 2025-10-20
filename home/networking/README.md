# Networking Layer Documentation

Comprehensive guide to the homelab networking infrastructure, covering Tailscale VPN, Traefik ingress, and TLS certificate management.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
  - [Dual-Access Pattern](#dual-access-pattern)
- [Components](#components)
  - [Tailscale Operator](#tailscale-operator)
  - [Traefik Ingress Controller](#traefik-ingress-controller)
  - [cert-manager](#cert-manager)
  - [Cloudflare Tunnel (Optional)](#cloudflare-tunnel-optional)
- [Request Flow](#request-flow)
  - [VPN Access Flow (Tailscale)](#vpn-access-flow-tailscale)
  - [Public Access Flow (Cloudflare Tunnel)](#public-access-flow-cloudflare-tunnel)
  - [TLS Certificate Selection](#tls-certificate-selection)
- [Certificate Management](#certificate-management)
  - [ClusterIssuers](#clusterissuers)
  - [Certificates](#certificates)
  - [DNS-01 Challenge Flow](#dns-01-challenge-flow)
- [Configuration Files](#configuration-files)
- [Common Operations](#common-operations)
- [Application Integration](#application-integration)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The networking layer provides **dual-access patterns** for cluster services:

1. **VPN Access (Primary)**: Secure Tailscale VPN access for most services
2. **Public Access (Selective)**: Cloudflare Tunnel for specific public-facing services

### Dual-Access Pattern

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
└────────────┬────────────────────────────────────────┬────────────────────────┘
             │                                         │
             │ Path 1: VPN Access (Primary)           │ Path 2: Public Access (Selective)
             │ HTTPS via Tailscale VPN                │ HTTPS via Cloudflare Tunnel
             │                                         │
     ┌───────▼────────┐                        ┌──────▼──────────┐
     │   Tailscale    │                        │   Cloudflare    │
     │  LoadBalancer  │                        │   Edge Network  │
     │ home.ts.net    │                        │                 │
     └───────┬────────┘                        └──────┬──────────┘
             │                                         │
             │ Port 8443 (TLS)                        │ TLS Terminated at Edge
             │                                         │
     ┌───────▼────────┐                        ┌──────▼──────────┐
     │    Traefik     │                        │   cloudflared   │
     │  TLS Terminate │                        │   (Tunnel Pod)  │
     │  HTTP Routing  │                        └──────┬──────────┘
     └───────┬────────┘                                │
             │                                         │ HTTP (plain)
             │ HTTP (plain)                            │
             │                                         │
      ┌──────┴────────┬──────────────┐        ┌───────▼─────────┐
      │               │              │        │                 │
┌─────▼─────┐  ┌──────▼─────┐  ┌────▼────┐  │  Select Public  │
│  ArgoCD   │  │  Traefik   │  │  Other  │  │    Services     │
│   (VPN)   │  │ Dashboard  │  │  (VPN)  │  │  (e.g., blog,   │
│   :80     │  │   (VPN)    │  │  :80    │  │   portfolio)    │
└───────────┘  └────────────┘  └─────────┘  └─────────────────┘
```

**Key Design Decisions:**

- **VPN-First Access**: Default secure access via Tailscale VPN (no public internet exposure)
- **Selective Public Exposure**: Cloudflare Tunnel for services requiring public access (blogs, portfolios, etc.)
- **TLS Termination at Ingress**: Traefik handles TLS for VPN access, Cloudflare handles TLS for public access
- **Automated Certificate Management**: cert-manager with Let's Encrypt DNS-01 challenges
- **Multi-Domain Support**: `norriswu.me` and `pawmery.pet` domains with separate certificates

---

## Components

### Tailscale Operator

**Purpose**: Provides secure VPN access to cluster services without public internet exposure.

**Configuration**: `main.tf:78-95`, `traefik-values.yaml:1-5`

**Key Features:**
- Deploys Tailscale operator in the cluster
- Creates LoadBalancer service for Traefik with Tailscale integration
- Hostname: `home.TAILNET.ts.net` (configurable via annotation)

**How It Works:**
```
1. Tailscale operator creates a VPN endpoint in your Tailnet
2. Traefik service gets LoadBalancer IP from Tailscale
3. External clients connect via Tailscale VPN
4. Traffic routes directly to Traefik without public IP exposure
```

**Verification:**
```bash
# Check Tailscale operator status
kubectl get pods -n networking -l app.kubernetes.io/name=tailscale-operator

# Check Traefik LoadBalancer IP
kubectl get svc -n networking traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### Traefik Ingress Controller

**Purpose**: Layer 7 reverse proxy and ingress controller with TLS termination.

**Configuration**: `main.tf:97-108`, `traefik-values.yaml`

**Key Features:**
- **Dual Entrypoints:**
  - `web` (HTTP, port 80): Redirects to `websecure`
  - `websecure` (HTTPS, port 8443): TLS termination enabled
- **SNI-based Certificate Selection**: Automatically selects correct certificate based on hostname
- **Cross-Namespace Support**: Can route to services in any namespace (`allowCrossNamespace: true`)
- **Default IngressClass**: All Ingress resources use Traefik by default

**Configuration Highlights:**

```yaml
# traefik-values.yaml
service:
  spec:
    loadBalancerClass: tailscale  # ← Integrates with Tailscale operator

ports:
  web:
    redirect: websecure            # ← Force HTTPS
  websecure:
    port: 8443
    tls: {}                        # ← Enable TLS with auto-discovery

providers:
  kubernetesCRD:
    allowCrossNamespace: true      # ← Access IngressRoutes from all namespaces
```

**Dashboard Access:**
- URL: `https://traefik.norriswu.me`
- Certificate: Uses `cluster-certificate-secret`
- Authentication: None (internal VPN access only)

---

### cert-manager

**Purpose**: Automated TLS certificate provisioning and renewal using Let's Encrypt.

**Configuration**: `cert-manager.tf`, `cert-manager-values.yaml`, `cert-manager-config-values.yaml`

**Deployment Architecture:**

```
cert-manager.tf
├── kubernetes_secret.cert_manager_creds
│   └── Contains Cloudflare API tokens (populated via script)
│
├── helm_release.cert_manager (v1.18.2)
│   └── Core cert-manager installation
│
└── helm_release.cert_manager_config
    └── ClusterIssuers and Certificate resources
```

**Key Features:**
- **DNS-01 Challenge**: Uses Cloudflare DNS for domain validation (enables wildcard certs)
- **Custom DNS Resolvers**: Uses Cloudflare (1.1.1.1) and Quad9 (9.9.9.9) for validation
- **Multi-Domain Support**: Separate Cloudflare API tokens for each domain
- **Staging Environment**: Let's Encrypt staging issuer to avoid rate limits during testing

**Secret Management Pattern:**

```bash
# 1. Terraform creates empty secret
resource "kubernetes_secret" "cert_manager_creds" {
  data = {
    norriswu_me_cf_dns_token = ""
    pawmery_pet_cf_dns_token = ""
  }
}

# 2. Populate via helper script
./script/update-cert-manager-secret.sh

# 3. cert-manager reads tokens for DNS-01 challenges
```

---

### Cloudflare Tunnel (Optional)

**Purpose**: Provides selective public internet access to specific services without exposing the entire cluster or requiring inbound firewall rules.

**Configuration**: `/apps/cloudflare-tunnel/deployment.yaml`

**Key Features:**
- **Zero Trust Network Access**: Outbound-only connections from cluster to Cloudflare edge
- **No Inbound Firewall Rules**: Tunnel initiates connection from inside cluster
- **Selective Public Exposure**: Configure specific services via Cloudflare dashboard
- **DDoS Protection**: Cloudflare edge network provides built-in DDoS mitigation
- **Geographic Distribution**: Cloudflare's global network for low-latency access

**Deployment:**

```yaml
# /apps/cloudflare-tunnel/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflare-tunnel
  namespace: nori-cloud
spec:
  containers:
    - name: cloudflared
      image: cloudflare/cloudflared:latest
      command: ["cloudflared", "tunnel", "run"]
      env:
        - name: TUNNEL_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-tunnel-secret
              key: TUNNEL_TOKEN
```

**How It Works:**

```
1. cloudflared pod runs in nori-cloud namespace
2. Establishes outbound connection to Cloudflare edge (no inbound ports needed)
3. Cloudflare dashboard configures routing: public hostname → cluster service
4. Public traffic arrives at Cloudflare edge
5. Cloudflare terminates TLS
6. Traffic routed through tunnel to cluster service (HTTP)
7. Service responds through tunnel
```

**Tunnel Configuration:**

Tunnel routing is configured in **Cloudflare Zero Trust dashboard**, not in Kubernetes manifests. Example routes:

```
blog.norriswu.me     → http://blog-service.nori-cloud.svc.cluster.local:80
portfolio.pawmery.pet → http://portfolio.nori-cloud.svc.cluster.local:3000
```

**Protocol Limitations:**

Cloudflare Tunnel supports **application-layer protocols only** (OSI Layer 7):

| Protocol | Supported | Notes |
|----------|-----------|-------|
| HTTP/HTTPS | ✅ Yes | Primary use case |
| WebSocket | ✅ Yes | Requires specific configuration |
| SSH (via browser) | ✅ Yes | Cloudflare Access integration |
| gRPC | ✅ Yes | HTTP/2 based, fully supported |
| TCP (raw) | ⚠️ Limited | Requires Cloudflare Spectrum (paid feature) |
| UDP | ❌ No | Not supported through standard tunnel |
| ICMP | ❌ No | Ping/traceroute not available |
| Custom protocols | ❌ No | Application-layer HTTP-based protocols only |

**Important Limitations:**

- **No Layer 4 Access**: Cannot tunnel arbitrary TCP/UDP ports (e.g., databases, game servers)
- **HTTP-Based Only**: Services must communicate over HTTP/HTTPS/WebSocket
- **No TLS Passthrough**: Cloudflare terminates TLS at edge (cannot use Let's Encrypt certs end-to-end)
- **Path-Based Routing**: Cannot route based on SNI alone (must use HTTP Host header)

**When to Use Cloudflare Tunnel:**

✅ **Good use cases:**
- Public-facing websites (blogs, portfolios)
- Web applications requiring public access
- Static content delivery
- Public APIs (REST, GraphQL, gRPC)
- WebSocket applications (chat, real-time apps)

❌ **Not suitable for:**
- Database access (PostgreSQL, MySQL, Redis)
- Game servers (requires UDP/custom TCP)
- VoIP/video streaming (requires UDP)
- Services requiring client TLS certificates
- Non-HTTP protocols

**Security Considerations:**

- **DDoS Protection**: Cloudflare edge absorbs attacks before reaching cluster
- **Rate Limiting**: Configure at Cloudflare dashboard
- **Access Control**: Use Cloudflare Access for authentication
- **Audit Logging**: Cloudflare logs all public access attempts
- **Separation of Concerns**: Public services isolated from VPN-only services

**Verification:**

```bash
# Check tunnel pod status
kubectl get pods -n nori-cloud -l app=cloudflare-tunnel

# Check tunnel connectivity
kubectl logs -n nori-cloud -l app=cloudflare-tunnel --tail=50
# Look for: "Connection established" and "Registered tunnel connection"

# Test public access (from outside VPN)
curl https://blog.norriswu.me
```

---

## Request Flow

### VPN Access Flow (Tailscale)

**Example**: User accesses `https://nginx.norriswu.me` via Tailscale VPN (primary access method)

```
┌──────────────────────────────────────────────────────────────────────┐
│ Step 1: DNS Resolution                                               │
└──────────────────────────────────────────────────────────────────────┘
   Client → DNS Query: nginx.norriswu.me
   DNS → Returns: 100.x.x.x (Tailscale IP)

┌──────────────────────────────────────────────────────────────────────┐
│ Step 2: Tailscale VPN Connection                                     │
└──────────────────────────────────────────────────────────────────────┘
   Client (Tailscale) → Establishes VPN tunnel to home.TAILNET.ts.net
   VPN tunnel → Routes to Kubernetes Service: traefik (LoadBalancer)

┌──────────────────────────────────────────────────────────────────────┐
│ Step 3: TLS Handshake (Traefik)                                      │
└──────────────────────────────────────────────────────────────────────┘
   Client → TLS ClientHello (SNI: nginx.norriswu.me)
   Traefik → Searches available certificates:
             - cluster-certificate-secret (networking namespace)
               SANs: norriswu.me, *.norriswu.me ← MATCH!
             - pawmery-pet-certificate-secret (networking namespace)
               SANs: pawmery.pet, *.pawmery.pet
   Traefik → Returns: cluster-certificate-secret
   TLS Handshake → Complete (encrypted connection established)

┌──────────────────────────────────────────────────────────────────────┐
│ Step 4: HTTP Routing (Traefik)                                       │
└──────────────────────────────────────────────────────────────────────┘
   Traefik → Decrypts HTTPS request
   Request → Host: nginx.norriswu.me
   Traefik → Searches IngressRoutes across all namespaces
   Match Found → IngressRoute: nginx (nori-cloud namespace)
                 Rule: Host(`nginx.norriswu.me`)
                 Service: nginx:80

┌──────────────────────────────────────────────────────────────────────┐
│ Step 5: Backend Communication (HTTP)                                 │
└──────────────────────────────────────────────────────────────────────┘
   Traefik → HTTP GET / (plain HTTP)
           → Service: nginx.nori-cloud.svc.cluster.local:80
   nginx Pod → Responds: 200 OK (HTML content)

┌──────────────────────────────────────────────────────────────────────┐
│ Step 6: Response (Traefik → Client)                                  │
└──────────────────────────────────────────────────────────────────────┘
   Traefik → Encrypts response with TLS
   Client ← HTTPS Response: 200 OK
```

**Timeline:** ~50-200ms (depending on VPN latency and backend response time)

**Suitable For:**
- Administrative interfaces (Argo CD, Traefik dashboard)
- Internal tools and dashboards
- Development/staging environments
- Services with sensitive data
- Any service that should NOT be publicly accessible

---

### Public Access Flow (Cloudflare Tunnel)

**Example**: Public user accesses `https://blog.norriswu.me` (service exposed via Cloudflare Tunnel)

```
┌──────────────────────────────────────────────────────────────────────┐
│ Step 1: DNS Resolution                                               │
└──────────────────────────────────────────────────────────────────────┘
   Client → DNS Query: blog.norriswu.me
   DNS (Cloudflare) → Returns: Cloudflare Edge IP (e.g., 104.x.x.x)
   ↑ Note: DNS managed by Cloudflare, resolves to Cloudflare network

┌──────────────────────────────────────────────────────────────────────┐
│ Step 2: TLS Handshake (Cloudflare Edge)                              │
└──────────────────────────────────────────────────────────────────────┘
   Client → TLS ClientHello to Cloudflare edge
   Cloudflare → Returns certificate (Cloudflare-issued or custom cert)
   TLS Handshake → Complete (client trusts Cloudflare cert)
   ↑ Note: TLS terminated at Cloudflare edge, NOT at cluster

┌──────────────────────────────────────────────────────────────────────┐
│ Step 3: Cloudflare WAF & Security Checks                             │
└──────────────────────────────────────────────────────────────────────┘
   Cloudflare → Analyzes request
             → Bot detection, rate limiting, firewall rules
             → DDoS mitigation
   Request → Passed security checks

┌──────────────────────────────────────────────────────────────────────┐
│ Step 4: Tunnel Routing (Cloudflare → Cluster)                        │
└──────────────────────────────────────────────────────────────────────┘
   Cloudflare → Decrypts HTTPS request
             → Looks up tunnel routing config:
               blog.norriswu.me → http://blog-service:80
   Cloudflare → Sends HTTP request through established tunnel
             → Tunnel: Persistent connection from cloudflared pod

┌──────────────────────────────────────────────────────────────────────┐
│ Step 5: Cluster Service (cloudflared → Service)                      │
└──────────────────────────────────────────────────────────────────────┘
   cloudflared pod (nori-cloud namespace)
   → Receives HTTP request from Cloudflare edge
   → Forwards to: blog-service.nori-cloud.svc.cluster.local:80
   ↑ Note: Plain HTTP inside cluster, TLS already terminated at edge

┌──────────────────────────────────────────────────────────────────────┐
│ Step 6: Application Response                                         │
└──────────────────────────────────────────────────────────────────────┘
   blog-service → Processes request
                → Returns: 200 OK (HTML content)

   Response path (reverse):
   blog-service → cloudflared pod → Cloudflare tunnel
                → Cloudflare edge (re-encrypts with TLS)
                → Client (HTTPS)

┌──────────────────────────────────────────────────────────────────────┐
│ Step 7: Client Receives Response                                     │
└──────────────────────────────────────────────────────────────────────┘
   Client ← HTTPS Response: 200 OK
   ↑ User sees secure connection (Cloudflare TLS cert)
```

**Timeline:** ~100-500ms (includes Cloudflare edge processing and geographic routing)

**Key Differences from VPN Access:**
- **No VPN Required**: Public users don't need Tailscale
- **TLS at Edge**: Cloudflare handles TLS, not Traefik
- **No Traefik Involved**: Tunnel bypasses Traefik entirely
- **Security at Edge**: DDoS protection, WAF, rate limiting handled by Cloudflare
- **Global Performance**: Cloudflare's CDN provides low-latency access worldwide

**Suitable For:**
- Public-facing blogs and websites
- Portfolio sites
- Public APIs (REST, GraphQL)
- Marketing pages
- Documentation sites
- Any HTTP-based service requiring public access

**Not Suitable For:**
- Services requiring VPN-level security
- Non-HTTP protocols (databases, game servers, VoIP)
- Services with strict data sovereignty requirements
- Applications requiring client TLS certificates

---

### TLS Certificate Selection

**Note**: This section applies to **VPN access via Traefik only**. Services exposed via Cloudflare Tunnel use Cloudflare-managed certificates at the edge, not Let's Encrypt certificates from cert-manager.

Traefik uses **SNI (Server Name Indication)** from the TLS ClientHello to select the appropriate certificate.

**Certificate Discovery Process:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Traefik Startup: Certificate Discovery                          │
└─────────────────────────────────────────────────────────────────┘

1. Scan all IngressRoutes (allowCrossNamespace: true)
   ├── Find IngressRoute with tls.secretName specified
   └── Load certificate from referenced secret

2. Scan all namespaces for TLS secrets (when tls: {} is used)
   ├── networking/cluster-certificate-secret
   │   └── SANs: norriswu.me, *.norriswu.me
   ├── networking/pawmery-pet-certificate-secret
   │   └── SANs: pawmery.pet, *.pawmery.pet
   └── system/cluster-certificate-secret
       └── SANs: norriswu.me, *.norriswu.me

3. Build in-memory certificate store indexed by SAN

┌─────────────────────────────────────────────────────────────────┐
│ Runtime: Certificate Selection (per request)                    │
└─────────────────────────────────────────────────────────────────┘

Incoming TLS ClientHello with SNI: nginx.norriswu.me
  ↓
Match against certificate SANs:
  ├── *.norriswu.me ← MATCH (wildcard)
  └── Return: cluster-certificate-secret

Incoming TLS ClientHello with SNI: nginx.pawmery.pet
  ↓
Match against certificate SANs:
  ├── *.pawmery.pet ← MATCH (wildcard)
  └── Return: pawmery-pet-certificate-secret
```

**Important Notes:**
- IngressRoutes can use **explicit** (`tls.secretName`) or **implicit** (`tls: {}`) certificate references
- Explicit references are more reliable but require manual updates when adding domains
- Implicit discovery (`tls: {}`) enables automatic certificate selection via SNI matching
- Certificate updates (renewals) are automatically picked up by Traefik

---

## Certificate Management

### ClusterIssuers

ClusterIssuers define how cert-manager obtains certificates from Let's Encrypt.

**Production Issuer: `cloudflare-cluster-issuer`**

```yaml
# cert-manager-config-values.yaml:26-48
- name: cloudflare-cluster-issuer
  acmeEmail: norris.wu.au@outlook.com
  acmeServer: https://acme-v02.api.letsencrypt.org/directory
  privateKeySecretRef:
    name: cloudflare-cluster-issuer-key
  solvers:
    # Solver for norriswu.me
    - dns01:
        cloudflare:
          email: norris.wu.au@outlook.com
          apiTokenSecretRef:
            name: cert-manager-creds
            key: norriswu_me_cf_dns_token
      selector:
        dnsZones:
          - norriswu.me

    # Solver for pawmery.pet
    - dns01:
        cloudflare:
          email: Zhugeruntao@gmail.com
          apiTokenSecretRef:
            name: cert-manager-creds
            key: pawmery_pet_cf_dns_token
      selector:
        dnsZones:
          - pawmery.pet
```

**Staging Issuer: `cloudflare-cluster-issuer-staging`**

Used for testing to avoid Let's Encrypt rate limits (50 certs/week for production).

- ACME Server: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Certificates issued are **not trusted** by browsers (for testing only)
- Same DNS-01 solver configuration as production

---

### Certificates

**Active Production Certificates:**

| Certificate Name | Namespace | Secret Name | Domains | Usage |
|------------------|-----------|-------------|---------|-------|
| `cluster-certificate` | `networking` | `cluster-certificate-secret` | `norriswu.me`, `*.norriswu.me` | Traefik, networking services |
| `cluster-certificate` | `system` | `cluster-certificate-secret` | `norriswu.me`, `*.norriswu.me` | Argo CD, Authentik (system services) |
| `pawmery-pet-certificate` | `networking` | `pawmery-pet-certificate-secret` | `pawmery.pet`, `*.pawmery.pet` | Applications on pawmery.pet domain |

**Why Duplicate Certificates Across Namespaces?**

Kubernetes secrets are **namespace-scoped**. When applications use standard Ingress resources (not IngressRoutes), they can only reference secrets in their own namespace.

```yaml
# Example: Argo CD uses standard Ingress (not IngressRoute)
# /home/system/argo-cd-values.yaml:30-36
server:
  ingress:
    enabled: true
    ingressClassName: traefik
    extraTls:
      - hosts:
          - argocd.norriswu.me
    # ↑ Implicitly references cluster-certificate-secret in SAME namespace (system)
```

**Certificate Lifecycle:**

```
1. Terraform applies cert-manager-config
   ↓
2. Kubernetes creates Certificate resources
   ↓
3. cert-manager detects new Certificate
   ↓
4. cert-manager creates CertificateRequest
   ↓
5. ClusterIssuer solver selected based on dnsZones
   ↓
6. DNS-01 challenge initiated (see next section)
   ↓
7. Let's Encrypt validates challenge
   ↓
8. Certificate issued (valid 90 days)
   ↓
9. Kubernetes Secret created/updated with cert
   ↓
10. Traefik automatically reloads certificate
```

**Auto-Renewal:**
- cert-manager checks certificates daily
- Renewal triggered at 30 days before expiry
- Process is fully automated (no manual intervention)

---

### DNS-01 Challenge Flow

DNS-01 challenges prove domain ownership by creating TXT records in DNS.

**Example**: Requesting certificate for `*.pawmery.pet`

```
┌──────────────────────────────────────────────────────────────────┐
│ Step 1: Challenge Initiation                                     │
└──────────────────────────────────────────────────────────────────┘
cert-manager → Creates CertificateRequest for *.pawmery.pet
            → Selects ClusterIssuer: cloudflare-cluster-issuer
            → Matches solver: dns01 (pawmery.pet zone)

┌──────────────────────────────────────────────────────────────────┐
│ Step 2: Let's Encrypt Challenge                                  │
└──────────────────────────────────────────────────────────────────┘
cert-manager → Contacts Let's Encrypt ACME server
Let's Encrypt → Returns challenge:
                "Create TXT record at _acme-challenge.pawmery.pet
                 with value: xyz123abc456..."

┌──────────────────────────────────────────────────────────────────┐
│ Step 3: DNS Record Creation                                      │
└──────────────────────────────────────────────────────────────────┘
cert-manager → Reads secret: cert-manager-creds
            → Extracts: pawmery_pet_cf_dns_token
            → Calls Cloudflare API:
               POST /zones/{pawmery.pet}/dns_records
               {
                 "type": "TXT",
                 "name": "_acme-challenge",
                 "content": "xyz123abc456..."
               }
Cloudflare → TXT record created

┌──────────────────────────────────────────────────────────────────┐
│ Step 4: DNS Propagation Wait                                     │
└──────────────────────────────────────────────────────────────────┘
cert-manager → Polls DNS using custom resolvers (1.1.1.1, 9.9.9.9)
            → Waits for TXT record to appear (usually 5-30 seconds)
            → Verifies record content matches challenge

┌──────────────────────────────────────────────────────────────────┐
│ Step 5: Challenge Validation                                     │
└──────────────────────────────────────────────────────────────────┘
cert-manager → Notifies Let's Encrypt: "Challenge ready"
Let's Encrypt → Queries DNS for _acme-challenge.pawmery.pet
              → Validates TXT record content
              → Challenge PASSED ✓

┌──────────────────────────────────────────────────────────────────┐
│ Step 6: Certificate Issuance                                     │
└──────────────────────────────────────────────────────────────────┘
Let's Encrypt → Issues certificate for *.pawmery.pet
              → Includes SANs: pawmery.pet, *.pawmery.pet
cert-manager → Stores certificate in secret: pawmery-pet-certificate-secret
Cloudflare → Deletes TXT record (cleanup)

┌──────────────────────────────────────────────────────────────────┐
│ Step 7: Certificate Ready                                        │
└──────────────────────────────────────────────────────────────────┘
Certificate resource → Status: Ready
Traefik → Detects new TLS secret
       → Loads certificate into memory
       → Indexes by SANs: pawmery.pet, *.pawmery.pet
```

**Timeline:** Typically 1-3 minutes from request to certificate ready.

**Why DNS-01 Instead of HTTP-01?**
- **Enables wildcard certificates** (`*.domain.com`)
- **No public HTTP exposure required** (works with VPN-only setup)
- **Works for services not publicly accessible**

---

## Configuration Files

### Core Terraform Files

| File | Purpose | Key Resources |
|------|---------|---------------|
| `main.tf` | Main networking module | Namespace, Tailscale operator, Traefik |
| `cert-manager.tf` | cert-manager installation | Secret, Helm releases |

### Helm Values Files

| File | Purpose | Used By |
|------|---------|---------|
| `traefik-values.yaml` | Traefik configuration | `helm_release.traefik` |
| `cert-manager-values.yaml` | cert-manager core config | `helm_release.cert_manager` |
| `cert-manager-config-values.yaml` | ClusterIssuers & Certificates | `helm_release.cert_manager_config` |

### Custom Helm Charts

| Chart | Purpose | Templates |
|-------|---------|-----------|
| `charts/cert-manager/` | ClusterIssuer & Certificate CRDs | `templates/cert-manager.yaml` |
| `charts/metallb/` | MetalLB config (commented out) | `templates/metallb-address-config.yaml` |

### Helper Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `../script/update-cert-manager-secret.sh` | Populate Cloudflare API tokens | Run after `.env` changes |

---

## Common Operations

### Verify Networking Stack Health

```bash
# Check all networking pods
kubectl get pods -n networking

# Expected output:
# tailscale-operator-xxx   1/1   Running
# traefik-xxx              1/1   Running
# cert-manager-xxx         1/1   Running
# cert-manager-webhook-xxx 1/1   Running
# cert-manager-cainjector  1/1   Running
```

### Check Certificate Status

```bash
# List all certificates
kubectl get certificates -n networking

# Expected output:
# NAME                       READY   SECRET                              AGE
# cluster-certificate        True    cluster-certificate-secret          30d
# pawmery-pet-certificate    True    pawmery-pet-certificate-secret      1d

# Detailed certificate info
kubectl describe certificate cluster-certificate -n networking

# Check certificate expiry
kubectl get secret cluster-certificate-secret -n networking -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -dates
```

### Force Certificate Renewal

```bash
# Delete certificate secret (cert-manager will recreate)
kubectl delete secret cluster-certificate-secret -n networking

# Or trigger manual renewal
kubectl annotate certificate cluster-certificate -n networking \
  cert-manager.io/issue-temporary-certificate="true" --overwrite
```

### Update Cloudflare API Tokens

```bash
# 1. Edit .env file
cd /workspace/lab/home
vim .env

# Add/update:
# NORRISWU_ME_CF_DNS_TOKEN=your_token_here
# PAWMERY_PET_CF_DNS_TOKEN=your_token_here

# 2. Run update script
./script/update-cert-manager-secret.sh

# 3. Restart cert-manager to pick up changes
kubectl rollout restart deployment cert-manager -n networking
```

### View Traefik Routes

```bash
# List all IngressRoutes
kubectl get ingressroutes -A

# Describe specific route
kubectl describe ingressroute nginx -n nori-cloud

# Check Traefik dashboard
# Access: https://traefik.norriswu.me
# (requires Tailscale VPN connection)
```

### Test TLS Certificate Selection

```bash
# Get Traefik external IP
TRAEFIK_IP=$(kubectl get svc traefik -n networking -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test SNI for norriswu.me domain
openssl s_client -connect $TRAEFIK_IP:8443 -servername nginx.norriswu.me -showcerts 2>/dev/null | \
  openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
# Expected: DNS:norriswu.me, DNS:*.norriswu.me

# Test SNI for pawmery.pet domain
openssl s_client -connect $TRAEFIK_IP:8443 -servername test.pawmery.pet -showcerts 2>/dev/null | \
  openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
# Expected: DNS:pawmery.pet, DNS:*.pawmery.pet
```

---

## Application Integration

### Exposing a New Application

**Example**: Expose a web application on `myapp.norriswu.me`

**Step 1: Create Deployment and Service**

```yaml
# /apps/myapp/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: nori-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: nori-cloud
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

**Step 2: Create IngressRoute**

```yaml
# /apps/myapp/ingress.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: nori-cloud
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.norriswu.me`)
      kind: Rule
      services:
        - name: myapp
          port: 80
  tls: {}  # Auto-select certificate via SNI
```

**Step 3: Deploy**

```bash
# Apply manifests
kubectl apply -f /apps/myapp/

# Verify IngressRoute
kubectl get ingressroute myapp -n nori-cloud

# Test access (requires Tailscale VPN)
curl https://myapp.norriswu.me
```

**Certificate Selection:**
- Traefik receives request for `myapp.norriswu.me`
- SNI matches wildcard: `*.norriswu.me`
- Uses certificate: `cluster-certificate-secret`
- **No additional configuration needed!**

---

### Using a Different Domain (pawmery.pet)

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp-pawmery
  namespace: nori-cloud
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.pawmery.pet`)
      kind: Rule
      services:
        - name: myapp
          port: 80
  tls: {}  # Auto-selects pawmery-pet-certificate-secret
```

Certificate selection:
- SNI: `myapp.pawmery.pet`
- Matches: `*.pawmery.pet`
- Uses: `pawmery-pet-certificate-secret`

---

### Advanced: Explicit Certificate Reference

If you need to explicitly specify which certificate to use:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: nori-cloud
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.norriswu.me`)
      kind: Rule
      services:
        - name: myapp
          port: 80
  tls:
    secretName: cluster-certificate-secret  # Explicit reference
    # Note: Secret must be in same namespace OR Traefik must have RBAC access
```

**When to use explicit references:**
- Multiple certificates cover the same domain
- Debugging certificate selection issues
- Compliance requirements for specific certificate chains

---

### Adding Middleware (Authentication, Rate Limiting, etc.)

```yaml
# Example: Add authentication middleware
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: nori-cloud
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.norriswu.me`)
      kind: Rule
      services:
        - name: myapp
          port: 80
      middlewares:
        - name: authentik  # Reference to Middleware resource
          namespace: system
  tls: {}
```

See `/home/system/authentik.tf` for example Authentik middleware configuration.

---

### Exposing Services via Cloudflare Tunnel

**For services that need public internet access** (blogs, portfolios, public APIs):

**Step 1: Ensure Cloudflare Tunnel is Running**

```bash
# Verify cloudflared pod is running
kubectl get pods -n nori-cloud -l app=cloudflare-tunnel

# Check tunnel connection status
kubectl logs -n nori-cloud -l app=cloudflare-tunnel --tail=20
# Look for: "Registered tunnel connection"
```

**Step 2: Configure Route in Cloudflare Dashboard**

1. Navigate to Cloudflare Zero Trust dashboard
2. Go to Access → Tunnels → [Your Tunnel] → Public Hostname
3. Add route:
   - **Public hostname**: `blog.norriswu.me`
   - **Service**: `http://blog-service.nori-cloud.svc.cluster.local:80`
   - **Additional settings**: Configure TLS, HTTP headers, etc.

**Step 3: Deploy Your Application**

```yaml
# /apps/blog/deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: blog-service
  namespace: nori-cloud
spec:
  selector:
    app: blog
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  namespace: nori-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      containers:
        - name: blog
          image: blog:latest
          ports:
            - containerPort: 8080
```

**Step 4: Test Public Access**

```bash
# Test from outside VPN (no Tailscale needed)
curl https://blog.norriswu.me
# Should return your blog homepage

# Check Cloudflare analytics for traffic
# Dashboard → Analytics → Traffic
```

**Important Notes:**

- **No IngressRoute needed**: Cloudflare Tunnel connects directly to Service
- **No TLS certificates needed**: Cloudflare manages TLS at edge
- **Service must use HTTP**: HTTPS not required inside cluster
- **DNS must point to Cloudflare**: Ensure nameservers are Cloudflare's

**Comparison: VPN vs Public Access**

| Aspect | VPN Access (Traefik) | Public Access (Tunnel) |
|--------|---------------------|------------------------|
| **Access Method** | Tailscale VPN required | Public internet (no VPN) |
| **TLS Termination** | Traefik (Let's Encrypt certs) | Cloudflare edge |
| **Routing** | IngressRoute CRD | Cloudflare dashboard config |
| **Security** | VPN authentication | Cloudflare WAF, rate limiting |
| **Protocol Support** | Any (TCP/UDP) | HTTP/HTTPS/WebSocket only |
| **Use Case** | Internal services, admin tools | Public websites, APIs |
| **DDoS Protection** | Limited (VPN layer) | Cloudflare network (robust) |
| **Latency** | VPN overhead (~50-200ms) | CDN optimized (~100-500ms) |
| **Certificate Management** | cert-manager (automated) | Cloudflare (managed) |
| **Configuration** | Kubernetes manifests | Cloudflare dashboard |

---

## Troubleshooting

### Certificate Not Ready

**Symptom**: `kubectl get certificates` shows `READY: False`

```bash
# Check certificate events
kubectl describe certificate <cert-name> -n networking

# Common issues:
# 1. DNS-01 challenge failed
#    → Verify Cloudflare API token has DNS edit permissions
#    → Check cert-manager logs: kubectl logs -n networking -l app=cert-manager

# 2. Rate limit hit
#    → Use staging issuer for testing
#    → Wait 1 week for Let's Encrypt rate limit reset

# 3. Invalid Cloudflare token
#    → Update .env and run: ./script/update-cert-manager-secret.sh
#    → Restart cert-manager: kubectl rollout restart deployment cert-manager -n networking
```

### Certificate Issued But Not Used by Traefik

**Symptom**: Traefik returns wrong certificate or default cert

```bash
# 1. Verify secret exists and is valid
kubectl get secret cluster-certificate-secret -n networking -o yaml

# 2. Check Traefik can read the secret (RBAC)
kubectl auth can-i get secrets -n networking --as=system:serviceaccount:networking:traefik

# 3. Restart Traefik to reload certificates
kubectl rollout restart deployment traefik -n networking

# 4. Check Traefik logs for certificate loading
kubectl logs -n networking -l app.kubernetes.io/name=traefik | grep -i certificate
```

### IngressRoute Not Working

**Symptom**: 404 Not Found or Service Unavailable

```bash
# 1. Verify IngressRoute exists
kubectl get ingressroute -A

# 2. Check IngressRoute syntax
kubectl describe ingressroute <name> -n <namespace>

# 3. Verify backend service exists
kubectl get svc <service-name> -n <namespace>

# 4. Test service directly (bypass Traefik)
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>
curl http://localhost:8080

# 5. Check Traefik logs for routing errors
kubectl logs -n networking -l app.kubernetes.io/name=traefik --tail=100
```

### Tailscale LoadBalancer Not Getting IP

**Symptom**: Traefik service stuck in `<pending>` state

```bash
# Check Tailscale operator status
kubectl get pods -n networking -l app.kubernetes.io/name=tailscale-operator
kubectl logs -n networking -l app.kubernetes.io/name=tailscale-operator

# Verify Tailscale OAuth credentials
kubectl get secret -n networking

# Common fixes:
# 1. Restart Tailscale operator
kubectl rollout restart deployment tailscale-operator -n networking

# 2. Verify OAuth client has correct permissions in Tailscale admin console
#    Required: Devices (Read/Write)
```

### DNS-01 Challenge Timeout

**Symptom**: Certificate stuck in "Waiting for DNS propagation"

```bash
# Check cert-manager logs
kubectl logs -n networking -l app=cert-manager | grep dns01

# Manually verify DNS record
dig _acme-challenge.norriswu.me TXT @1.1.1.1

# Common issues:
# 1. Cloudflare API token lacks DNS edit permissions
# 2. DNS zone not properly configured in ClusterIssuer
# 3. DNS propagation delay (wait 1-2 minutes)

# Force retry
kubectl delete certificaterequest <request-name> -n networking
# cert-manager will create a new request automatically
```

### Check Overall Networking Health

```bash
# Quick health check script
cat << 'EOF' > /tmp/networking-health.sh
#!/bin/bash
echo "=== Networking Health Check ==="
echo ""
echo "1. Tailscale Operator:"
kubectl get pods -n networking -l app.kubernetes.io/name=tailscale-operator
echo ""
echo "2. Traefik:"
kubectl get pods -n networking -l app.kubernetes.io/name=traefik
echo ""
echo "3. cert-manager:"
kubectl get pods -n networking -l app=cert-manager
echo ""
echo "4. Certificates:"
kubectl get certificates -n networking
echo ""
echo "5. IngressRoutes:"
kubectl get ingressroutes -A
echo ""
echo "6. Traefik Service:"
kubectl get svc traefik -n networking
EOF

chmod +x /tmp/networking-health.sh
/tmp/networking-health.sh
```

### Cloudflare Tunnel Not Connecting

**Symptom**: cloudflared pod running but tunnel shows "disconnected" in Cloudflare dashboard

```bash
# Check pod logs
kubectl logs -n nori-cloud -l app=cloudflare-tunnel --tail=100

# Common errors and fixes:

# Error: "Invalid tunnel token"
# → Check secret contains correct TUNNEL_TOKEN
kubectl get secret cloudflare-tunnel-secret -n nori-cloud -o yaml

# Error: "Failed to register tunnel"
# → Verify tunnel exists in Cloudflare dashboard
# → Regenerate tunnel token if needed

# Error: "Connection timeout"
# → Check cluster has outbound internet access
# → Verify firewall allows connections to region1.v2.argotunnel.com:7844

# Restart tunnel pod
kubectl rollout restart deployment cloudflare-tunnel -n nori-cloud
```

### Public Service Returns 502/503

**Symptom**: Cloudflare Tunnel connected but public URL returns error

```bash
# 1. Verify service exists in cluster
kubectl get svc -n nori-cloud

# 2. Check service endpoints are ready
kubectl get endpoints <service-name> -n nori-cloud
# Ensure at least one pod is in Ready state

# 3. Test service directly from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://<service-name>.<namespace>.svc.cluster.local

# 4. Verify Cloudflare route configuration
# Check dashboard: Access → Tunnels → Public Hostname
# Ensure service URL format: http://service-name.namespace.svc.cluster.local:port

# 5. Check cloudflared logs for errors
kubectl logs -n nori-cloud -l app=cloudflare-tunnel | grep -i error
```

### Public Service Only Works on VPN, Not Publicly

**Symptom**: Service accessible via Tailscale but not via Cloudflare Tunnel

```bash
# 1. Verify DNS is pointing to Cloudflare
dig blog.norriswu.me
# Should return Cloudflare IP (104.x.x.x), NOT Tailscale IP (100.x.x.x)

# 2. Check Cloudflare dashboard for route
# Ensure Public Hostname is configured for the domain

# 3. Clear DNS cache
# On client: ipconfig /flushdns (Windows) or sudo dscacheutil -flushcache (macOS)

# 4. Test with explicit DNS server
curl --resolve blog.norriswu.me:443:104.21.x.x https://blog.norriswu.me
# Replace 104.21.x.x with actual Cloudflare IP
```

---

## Additional Resources

### Related Documentation

- **Traefik**: https://doc.traefik.io/traefik/
- **cert-manager**: https://cert-manager.io/docs/
- **Tailscale Operator**: https://tailscale.com/kb/1236/kubernetes-operator
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

### Internal References

- **Cluster Module**: `/home/cluster/` - Namespace discovery
- **System Module**: `/home/system/` - Argo CD, Authentik (system services using certs)
- **Applications**: `/apps/` - Example IngressRoute and application configurations
- **Cloudflare Tunnel**: `/apps/cloudflare-tunnel/` - Tunnel deployment configuration

### Architecture Decisions

**Why dual-access pattern (VPN + Public Tunnel)?**
- **Security by default**: VPN access for sensitive services (admin interfaces, internal tools)
- **Selective public exposure**: Only specific services exposed publicly (blogs, portfolios)
- **Defense in depth**: Multiple security layers (VPN authentication + Cloudflare WAF)
- **Flexibility**: Choose appropriate access method per service

**Why Tailscale instead of public LoadBalancer?**
- Zero public internet exposure for sensitive services (security)
- No need for dynamic DNS or port forwarding
- Built-in authentication via Tailscale ACLs
- Encrypted VPN tunnel (additional security layer)
- No attack surface for internal services

**Why Cloudflare Tunnel instead of direct public exposure?**
- Zero inbound firewall rules needed (tunnel initiates from cluster)
- DDoS protection at Cloudflare edge (prevents attacks from reaching cluster)
- Built-in WAF, rate limiting, and bot protection
- Geographic distribution (low latency worldwide)
- No public IP address needed

**Why DNS-01 instead of HTTP-01 challenges?**
- Enables wildcard certificates (`*.domain.com`)
- Works with VPN-only setup (no public HTTP endpoint needed)
- More reliable for homelab environments
- Single certificate covers all subdomains

**Why duplicate certificates across namespaces?**
- Kubernetes secrets are namespace-scoped
- Standard Ingress resources can't reference cross-namespace secrets
- Traefik IngressRoutes can use cross-namespace secrets, but not all apps use IngressRoutes
- Duplication ensures compatibility with both Ingress and IngressRoute patterns

**Why application-layer tunnel (not Layer 4)?**
- Cloudflare free tier supports HTTP/HTTPS/WebSocket
- Most homelab services are web-based
- Layer 7 enables better security filtering and analytics
- Sufficient for blogs, APIs, web apps (primary public use cases)

---

## Maintenance

### Regular Tasks

**Weekly:**
- Review certificate expiry dates: `kubectl get certificates -A`
- Check Cloudflare Tunnel connectivity: `kubectl logs -n nori-cloud -l app=cloudflare-tunnel --tail=10`

**Monthly:**
- Review Traefik access logs for unusual patterns
- Check Cloudflare analytics for public services (traffic, security events)
- Update Traefik/cert-manager Helm charts if security patches available
- Review public services exposed via Cloudflare Tunnel (verify still needed)

**Quarterly:**
- Rotate Cloudflare API tokens (DNS and Tunnel tokens)
- Review and update Tailscale OAuth client permissions
- Audit Cloudflare WAF rules and rate limiting configurations
- Review Cloudflare Tunnel routes (remove unused public exposures)

### Backup Considerations

**What to backup:**
- Certificate private keys: Stored in Kubernetes secrets
- Cloudflare API tokens: Stored in `.env` file (gitignored)
- Let's Encrypt account key: Stored in `cert-manager-creds` secret
- Cloudflare Tunnel token: Stored in `cloudflare-tunnel-secret` secret
- Cloudflare Tunnel configuration: Stored in Cloudflare dashboard (export regularly)

**Backup commands:**
```bash
# Backup all networking secrets
kubectl get secrets -n networking -o yaml > networking-secrets-backup.yaml

# Encrypt backup (important!)
gpg -c networking-secrets-backup.yaml
rm networking-secrets-backup.yaml

# Store encrypted backup securely (external storage)
```

**Recovery:**
```bash
# Restore secrets
gpg -d networking-secrets-backup.yaml.gpg | kubectl apply -f -

# Certificates will auto-renew if expired
# No manual intervention needed
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-XX | Initial documentation |

---

**Maintained by**: Infrastructure Team
**Last Updated**: 2025-01-XX
**Next Review**: 2025-04-XX
