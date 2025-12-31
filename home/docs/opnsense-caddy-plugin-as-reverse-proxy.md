# Caddy Reverse Proxy Setup on OPNsense

## Overview

This guide documents setting up Caddy as a reverse proxy on OPNsense to expose internal services via HTTPS using a wildcard certificate.

**Goal:** Access internal services on non-standard ports through clean HTTPS URLs.

| External URL                         | Internal Destination     |
| ------------------------------------ | ------------------------ |
| `https://infisical.home.norriswu.me` | `http://10.0.0.241:8080` |
| `https://opnsense.home.norriswu.me`  | `http://10.0.0.1:8443`   |

---

## Components Used

### 1. ACME Plugin (os-acme-client)

**Purpose:** Obtain a wildcard TLS certificate from Let's Encrypt.

**What we did:**

-   Generated a wildcard certificate for `*.home.norriswu.me`
-   Used DNS-01 challenge (required for wildcard certs)
-   Certificate is stored in OPNsense's Trust store and automatically made available to Caddy

**Why wildcard:** A single certificate covers all subdomains, so adding new services doesn't require new certificates.

---

### 2. Caddy Plugin (os-caddy)

**Purpose:** Reverse proxy that terminates TLS and forwards requests to internal services.

**Why Caddy over alternatives:**

| Feature             | Caddy         | Nginx            | HAProxy        |
| ------------------- | ------------- | ---------------- | -------------- |
| Config complexity   | Low           | High             | High           |
| Objects per service | 2             | 4                | 3+             |
| Primary use case    | Reverse proxy | Web server / WAF | Load balancing |

---

## Configuration Steps

### Step 1: Prepare OPNsense

Caddy needs ports 80 and 443, so the OPNsense WebGUI must move to a different port.

**System → Settings → Administration:**

-   TCP Port: `8443`
-   HTTP Redirect: Disabled

**Firewall → Rules → WAN:** _(Optional - only if you want external access)_

-   Allow TCP to `This Firewall` on port `80` (HTTP)
-   Allow TCP/UDP to `This Firewall` on port `443` (HTTPS)

**Firewall → Rules → LAN:**

-   Same rules as WAN (for internal access)

---

### Step 2: Configure Caddy General Settings

**Services → Caddy Web Server → General Settings:**

| Setting    | Value          | Reason                           |
| ---------- | -------------- | -------------------------------- |
| Enabled    | ✓              | Start the service                |
| Auto HTTPS | Off            | Using our own wildcard cert      |
| Email      | your@email.com | Optional, for ACME notifications |

---

### Step 3: Create Wildcard Domain

**Services → Caddy Web Server → Reverse Proxy → Domains:**

| Setting     | Value                                 |
| ----------- | ------------------------------------- |
| Protocol    | `https://`                            |
| Domain      | `*.home.norriswu.me`                  |
| Port        | (empty)                               |
| Certificate | Select wildcard cert from ACME plugin |

---

### Step 4: Create Subdomains

For each service, create a subdomain entry linked to the wildcard parent.

**Services → Caddy Web Server → Reverse Proxy → Domains:**

| Subdomain                    | Parent Domain        |
| ---------------------------- | -------------------- |
| `infisical.home.norriswu.me` | `*.home.norriswu.me` |
| `opnsense.home.norriswu.me`  | `*.home.norriswu.me` |

**Important:** Subdomains must be linked to the wildcard domain so they inherit the TLS certificate.

---

### Step 5: Create Handlers

Handlers route traffic from the frontend (subdomain) to the backend (internal service).

**Services → Caddy Web Server → Reverse Proxy → Handlers:**

**Handler 1: Infisical**

| Setting           | Value                        |
| ----------------- | ---------------------------- |
| Domain            | `*.home.norriswu.me`         |
| Subdomain         | `infisical.home.norriswu.me` |
| Upstream Protocol | `http://`                    |
| Upstream Domain   | `10.0.0.241`                 |
| Upstream Port     | `8080`                       |

**Handler 2: OPNsense WebGUI**

| Setting           | Value                       |
| ----------------- | --------------------------- |
| Domain            | `*.home.norriswu.me`        |
| Subdomain         | `opnsense.home.norriswu.me` |
| Upstream Protocol | `http://`                   |
| Upstream Domain   | `10.0.0.1`                  |
| Upstream Port     | `8443`                      |

---

## Resulting Caddyfile

The GUI generates a Caddyfile similar to this:

```caddyfile
*.home.norriswu.me {
    tls /path/to/cert.pem /path/to/key.pem

    @infisical host infisical.home.norriswu.me
    handle @infisical {
        reverse_proxy 10.0.0.241:8080
    }

    @opnsense host opnsense.home.norriswu.me
    handle @opnsense {
        reverse_proxy 10.0.0.1:8443
    }
}
```

---

## Adding New Services

To add a new service:

1. **Create a subdomain** in Domains tab, linked to `*.home.norriswu.me`
2. **Create a handler** pointing the subdomain to the internal IP:port
3. **Apply** changes

No certificate management needed — the wildcard covers all subdomains.

---

## Troubleshooting

### Blank screen or connection refused

1. **Check Caddy is running:** General Settings shows status
2. **View logs:** Services → Caddy Web Server → Log File
3. **Validate config:** Diagnostics → Caddyfile → Validate Caddyfile

### Enable debug logging

**General Settings → Log Settings:**

-   Log Level: `DEBUG`

**Per-domain access logs:**

-   Edit domain → Access → Enable HTTP Access Log
-   Logs appear in `/var/log/caddy/access/`

### Common issues

| Symptom            | Cause                         | Fix                                                                      |
| ------------------ | ----------------------------- | ------------------------------------------------------------------------ |
| Blank screen       | Handler not matching          | Ensure subdomain is linked to wildcard domain                            |
| Certificate error  | Subdomain not inheriting cert | Create subdomain as child of wildcard, not separate domain               |
| 502 Bad Gateway    | Upstream unreachable          | Verify internal service is running; test with `curl` from OPNsense shell |
| Connection timeout | Firewall blocking             | Check WAN/LAN rules allow ports 80/443 to `This Firewall`                |

### Test upstream connectivity

SSH into OPNsense, select option 8 (Shell), then:

```bash
curl -I http://10.0.0.241:8080
```

---

## DNS Configuration

DNS is critical for this setup to work. The configuration differs depending on whether you're accessing services from the internet (external) or from within your network (internal).

---

### External Access (Public Internet)

For services to be accessible from outside your network, your domain's public DNS must point to your OPNsense WAN IP.

**Where to configure:** Your domain registrar or DNS provider (e.g., Cloudflare, Namecheap, Route53)

**Option A: Wildcard DNS record (recommended)**

A single wildcard record covers all subdomains automatically.

| Type | Name     | Value                                |
| ---- | -------- | ------------------------------------ |
| A    | `*.home` | `<Your Public WAN IP>`               |
| AAAA | `*.home` | `<Your Public IPv6>` (if applicable) |

**Option B: Individual records**

Create a record for each service manually.

| Type | Name             | Value                  |
| ---- | ---------------- | ---------------------- |
| A    | `infisical.home` | `<Your Public WAN IP>` |
| A    | `opnsense.home`  | `<Your Public WAN IP>` |

**Dynamic IP considerations:**

If your ISP assigns a dynamic IP, use:

-   Caddy's built-in Dynamic DNS feature (works with Cloudflare)
-   OPNsense's Dynamic DNS service (Services → Dynamic DNS)
-   A CNAME pointing to a DDNS hostname

**How it works:**

```
User (Internet) → DNS lookup "infisical.home.norriswu.me"
                → Returns your WAN IP (e.g., 203.0.113.50)
                → Request hits OPNsense WAN:443
                → Firewall rule allows it through to Caddy
                → Caddy matches subdomain, proxies to internal service
```

---

### Internal Access (LAN/Local Network)

When accessing services from inside your network, you have a problem: if DNS returns your public WAN IP, the traffic goes out to your router and tries to come back in. This is called "NAT hairpinning" or "NAT reflection" and doesn't work reliably on all setups.

**The solution: Split-horizon DNS (also called split-brain DNS)**

Internal clients get a different DNS response pointing to OPNsense's LAN IP instead of the WAN IP.

---

#### Configuring Unbound DNS on OPNsense

OPNsense uses Unbound as its built-in DNS resolver. You can add host overrides so internal clients resolve your domains to the LAN IP.

**Services → Unbound DNS → Host Overrides**

**Option A: Individual host overrides**

Add an override for each subdomain:

| Host      | Domain           | Type | Value    |
| --------- | ---------------- | ---- | -------- |
| infisical | home.norriswu.me | A    | 10.0.0.1 |
| opnsense  | home.norriswu.me | A    | 10.0.0.1 |

_Note: The IP should be OPNsense's LAN IP (where Caddy is listening), not the internal service IP._

**Option B: Wildcard override (requires custom config)**

Unbound's GUI doesn't support wildcard overrides directly. To add one:

1. Go to **Services → Unbound DNS → Advanced Settings**
2. Enable **Custom Options**
3. Add the following:

```
local-zone: "home.norriswu.me." redirect
local-data: "home.norriswu.me. A 10.0.0.1"
```

This redirects ALL queries for `*.home.norriswu.me` to `10.0.0.1`.

4. **Apply** and restart Unbound

---

#### How internal resolution works

```
User (LAN) → DNS query to OPNsense (10.0.0.1:53)
           → Unbound checks host overrides
           → Returns 10.0.0.1 (LAN IP)
           → Request goes to OPNsense LAN:443
           → Caddy matches subdomain, proxies to internal service
```

**Without split-horizon DNS:**

```
User (LAN) → DNS query → Returns WAN IP (203.0.113.50)
           → Request tries to go to WAN IP
           → NAT hairpin fails or adds latency
           → Connection times out or fails
```

---

### Ensuring Clients Use OPNsense for DNS

For Unbound overrides to work, LAN clients must use OPNsense as their DNS server.

**Check DHCP settings:**

Go to **Services → DHCPv4 → [LAN]**

Ensure **DNS servers** is either:

-   Empty (defaults to OPNsense IP), or
-   Explicitly set to OPNsense's LAN IP (e.g., `10.0.0.1`)

If clients use external DNS (like `8.8.8.8` or `1.1.1.1`), they'll bypass Unbound and split-horizon won't work.

---

### Testing DNS Resolution

**From a LAN client (Windows):**

```cmd
nslookup infisical.home.norriswu.me
```

**From a LAN client (Linux/Mac):**

```bash
dig infisical.home.norriswu.me
# or
host infisical.home.norriswu.me
```

**Expected result for internal clients:**

```
infisical.home.norriswu.me → 10.0.0.1
```

**Expected result for external clients:**

```
infisical.home.norriswu.me → 203.0.113.50 (your WAN IP)
```

---

### DNS Configuration Summary

| Access From | DNS Provider                  | Points To         |
| ----------- | ----------------------------- | ----------------- |
| Internet    | Public DNS (Cloudflare, etc.) | WAN IP            |
| LAN         | Unbound (OPNsense)            | LAN IP (10.0.0.1) |
| VPN clients | Depends on VPN DNS settings   | LAN IP preferred  |

---

## Security Considerations

-   **Restrict access:** Use Access Lists in Caddy to limit access by IP range
-   **Internal-only services:** Create an access list with private IP ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
-   **Basic auth:** Add username/password protection per domain if needed
-   **CrowdSec integration:** Caddy supports CrowdSec for dynamic IP banning

---

## References

-   [OPNsense Caddy Documentation](https://docs.opnsense.org/manual/how-tos/caddy.html)
-   [Caddy Official Documentation](https://caddyserver.com/docs/)
-   [OPNsense ACME Client Documentation](https://docs.opnsense.org/manual/how-tos/acme.html)
