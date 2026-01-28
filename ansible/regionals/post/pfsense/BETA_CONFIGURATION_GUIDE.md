# Beta pfSense Configuration Replication Guide

This guide outlines the key differences between the beta pfSense configuration and the current Ansible templates, and how to replicate the beta setup.

## Key Differences Summary

### 1. System Settings (`templates/pfsense/system/_settings.xml.j2`)

**Missing/Additional Settings:**
- `prefer_ipv4` - Prefer IPv4 over IPv6
- `statepolicy` - Set to `if-bound` (vs default)
- `loginshowhost` - Show hostname on login
- `quietlogin` - Quiet login mode
- `sshdagentforwarding` - SSH agent forwarding enabled
- `dashboardcolumns` - Set to `3` (vs current `2`)
- `max_procs` - Set to `4` (vs current `2`)

**Current template has these, beta doesn't show:**
- `gitsync` section
- `pkg_repo_conf_path`

### 2. Interface Configuration (`templates/pfsense/interfaces/_interfaces.xml.j2`)

**Interface Descriptions:**
- Beta uses: `PUBLIC`, `PRIVATE`, `SCREENED`, `BRANCH`
- Current uses: `WAN`, `LAN`, `CORP`, `DMZ`

**IPv6 Configuration:**
- **WAN (PUBLIC)**: `ipaddrv6: dhcp6`, `dhcp6-ia-pd-len: none`
- **LAN (PRIVATE)**: Static IPv6 `2600:1f26:1d:8b02:ffff:ffff:ffff:fffe/64`
- **opt1 (SCREENED)**: No IPv6
- **opt2 (BRANCH)**: Static IPv6 `2600:1f26:1d:8a02:ffff:ffff:ffff:fffe/64`

**Gateway Names:**
- Beta: `PUBLIC_DHCP` and `PUBLIC_DHCP6`
- Current: `WAN_DHCP` and `WAN_DHCP6`

**VIP Location:**
- Beta: VIP on `lan` interface at `10.0.2.125`
- Current: VIP on `opt2` (DMZ) interface

### 3. Firewall Rules (`templates/pfsense/firewall/_filter.xml.j2`)

**IPv6 Rules:**
- Beta has IPv6 rules (`ipprotocol: inet6`) for:
  - WAN interface (ICMP)
  - LAN interface (allow LAN to any)
  - opt1/SCREENED (allow SCREENED to any)
  - opt2/BRANCH (allow BRANCH to any)

**Management Lockdown Rules:**
- Beta has BLOCK rules preventing access to FirewallManagement ports from:
  - `SCREENED` interface
  - `BRANCH` interface
- These use `ipprotocol: inet46` (both IPv4 and IPv6)

**WAN Rules:**
- Beta has a combined rule using `FirewallManagement` alias for ports 22, 80, 443, 8080
- Current has separate rules for each port

### 4. Aliases (`templates/pfsense/firewall/_aliases.xml.j2`)

**Network Aliases (Beta has these, current doesn't):**
```xml
<alias>
    <name>NET_Private</name>
    <type>network</type>
    <address>10.0.2.0/25</address>
    <descr>Tier 1: Private (IPv4)</descr>
</alias>
<alias>
    <name>NET_Private_v6</name>
    <type>network</type>
    <address>2600:1f26:1d:8b02::/64</address>
    <descr>Tier 1: Private (IPv6)</descr>
</alias>
<alias>
    <name>NET_Screened</name>
    <type>network</type>
    <address>10.0.2.128/26</address>
    <descr>Tier 2: Screened DMZ</descr>
</alias>
<alias>
    <name>NET_Branch</name>
    <type>network</type>
    <address>10.0.2.192/27</address>
    <descr>Tier 3: Branch (IPv4)</descr>
</alias>
<alias>
    <name>NET_Branch_v6</name>
    <type>network</type>
    <address>2600:1f26:1d:8a02::/64</address>
    <descr>Tier 3: Branch (IPv6)</descr>
</alias>
```

### 5. Unbound DNS (`templates/pfsense/dns/_unbound.xml.j2`)

**Additional Features:**
- `dns64` enabled
- `domainoverrides` for `chefops.local` pointing to `10.0.2.120`
- `hosts` entries with dual-stack IPs:
  - `windows-ad`: `10.0.2.120,2600:1f26:001d:8b02:ab57:8ef2:ce6:42c1`
  - `windows-pos`: `10.0.2.220,2600:1f26:001d:8a02::cafe:0`
  - `windows-adfs`: `10.0.2.110,2600:1f26:001d:8b02::adf5:0`
- `acls` with IPv4 and IPv6 entries (`0.0.0.0/0` and `::0/0`)

**Custom Options (base64 encoded):**
Contains DNS zones and local-data entries for:
- `2.chefops.tech` → `10.0.2.125`
- `teleport.2.chefops.tech` → `10.0.2.148`
- `falco.2.chefops.tech` → `10.0.2.100` (IPv4) and `2600:1f26:001d:8b02::fa1c:0` (IPv6)

### 6. Variables (`vars/main.yaml`)

**Interface Naming:**
- Update interface descriptions to match beta naming convention
- Add IPv6 configuration variables for each interface

**VIP Configuration:**
- Change VIP interface from `opt2` (DMZ) to `lan` (PRIVATE)

## Implementation Steps

### Step 1: Update System Settings

Add to `templates/pfsense/system/_settings.xml.j2`:
```xml
<prefer_ipv4></prefer_ipv4>
<statepolicy><![CDATA[if-bound]]></statepolicy>
<loginshowhost></loginshowhost>
<quietlogin></quietlogin>
```

Update SSH section:
```xml
<ssh>
    <enable>enabled</enable>
    <port>22</port>
    <sshdagentforwarding>enabled</sshdagentforwarding>
</ssh>
```

Update webgui:
```xml
<dashboardcolumns>3</dashboardcolumns>
<max_procs>4</max_procs>
```

### Step 2: Update Interface Configuration

1. **Change interface descriptions** in `vars/main.yaml`:
   - `public.descr: PUBLIC`
   - `lan.descr: PRIVATE`
   - `corp.descr: SCREENED`
   - `dmz.descr: BRANCH`

2. **Update gateway names** in `templates/pfsense/interfaces/_interfaces.xml.j2`:
   - `WAN_DHCP` → `PUBLIC_DHCP`
   - `WAN_DHCP6` → `PUBLIC_DHCP6`

3. **Configure IPv6** (already done in previous changes):
   - WAN: `dhcp6`
   - LAN: static (needs IPv6 address variable)
   - opt2/BRANCH: static (needs IPv6 address variable)

4. **Update VIP** in `templates/pfsense/interfaces/_interfaces.xml.j2`:
   - Change from `opt2` to `lan`
   - Update subnet_bits to match LAN subnet

### Step 3: Add IPv6 Firewall Rules

Add IPv6 rules for each interface in `templates/pfsense/firewall/_filter.xml.j2`:
- WAN IPv6 ICMP rule
- LAN IPv6 allow rule
- opt1/SCREENED IPv6 allow rule
- opt2/BRANCH IPv6 allow rule

### Step 4: Add Management Lockdown Rules

Add BLOCK rules before the allow rules:
```xml
<rule>
    <type>block</type>
    <interface>opt1</interface>  <!-- SCREENED -->
    <ipprotocol>inet46</ipprotocol>
    <protocol>tcp/udp</protocol>
    <source><any></any></source>
    <destination>
        <network>(self)</network>
        <port>FirewallManagement</port>
    </destination>
    <descr>BLOCK FirewallManagement to restrict firewall web access on SCREENED</descr>
</rule>
```

Same for `opt2` (BRANCH).

### Step 5: Add Network Aliases

Add network aliases to `templates/pfsense/firewall/_aliases.xml.j2`:
- NET_Private (IPv4)
- NET_Private_v6 (IPv6)
- NET_Screened
- NET_Branch (IPv4)
- NET_Branch_v6 (IPv6)

### Step 6: Update Unbound DNS

1. Enable DNS64
2. Add domain overrides
3. Add host entries with dual-stack IPs
4. Update ACLs to include IPv6
5. Update custom_options to include IPv6 AAAA records

### Step 7: Update Variables

Add to `vars/main.yaml`:
```yaml
interfaces:
  public:
    descr: PUBLIC
    ipv6_type: dhcp6
  lan:
    descr: PRIVATE
    ipv6_type: static
    ipv6_address: '{{ team_address.firewall_private_ipv6 }}'
  corp:
    descr: SCREENED
  dmz:
    descr: BRANCH
    ipv6_type: static
    ipv6_address: '{{ team_address.firewall_dmz_ipv6 }}'

vip:
  interface: lan  # Changed from opt2
  address: '{{ team_address.firewall_vip }}'
```

## Notes

- The beta configuration uses interface names that match the security tier model (PRIVATE, SCREENED, BRANCH)
- IPv6 is fully configured with both DHCPv6 on WAN and static addresses on internal interfaces
- Management access is restricted from lower-tier networks (SCREENED and BRANCH)
- DNS64 is enabled for IPv6-to-IPv4 translation
- The VIP is on the PRIVATE/LAN interface, not the DMZ

## Testing Checklist

- [ ] Verify IPv6 connectivity on all interfaces
- [ ] Test management access restrictions from SCREENED and BRANCH
- [ ] Verify DNS resolution for dual-stack hosts
- [ ] Test HAProxy with IPv6 frontends
- [ ] Verify firewall rules for both IPv4 and IPv6
- [ ] Test VIP accessibility on LAN interface
