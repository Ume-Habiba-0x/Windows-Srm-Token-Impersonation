# ============================================================
# rename-screenshots.ps1
# Place this in the same folder as your image1.png ... image35.png
# Fix typos first: image29png.png → image29.png, image34png.png → image34.png, image35png.png → image35.png
# ============================================================

$base = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── MAPPING: exact filename → (phase-folder, new-filename) ────────────────
$map = @{
    "image1.png"  = @("phase01-environment-setup",     "01-ipconfig-target-ip.png")
    "image2.png"  = @("phase01-environment-setup",     "02-mkdir-netshare-command.png")
    "image3.png"  = @("phase02-sacl-config",           "01-security-properties-authenticated-users.png")
    "image4.png"  = @("phase02-sacl-config",           "02-auditing-entry-all-rights-checked.png")
    "image5.png"  = @("phase02-sacl-config",           "03-pagefile-kernel-lock-error.png")
    "image6.png"  = @("phase03-telemetry-verification","01-event-viewer-windows-logs-overview.png")
    "image7.png"  = @("phase03-telemetry-verification","02-security-log-4663-entries.png")
    "image8.png"  = @("phase04-unauthorized-access",   "01-smbclient-access-denied.png")
    "image9.png"  = @("phase05-forensic-correlation",  "01-event-4663-security-log.png")
    "image10.png" = @("phase05-forensic-correlation",  "02-event-4663-object-access-detail.png")
    "image11.png" = @("phase06-audit-evasion",         "01-auditpol-success-disable.png")
    "image12.png" = @("phase06-audit-evasion",         "02-event-4634-last-before-silence.png")
    "image13.png" = @("phase07-audit-policy-change",   "01-event-4907-policy-change-flood.png")
    "image14.png" = @("phase07-audit-policy-change",   "02-event-4663-at-policy-change.png")
    "image15.png" = @("phase08-anti-forensics",        "01-wevtutil-clear-executed.png")
    "image16.png" = @("phase08-anti-forensics",        "02-event-1102-only-remaining.png")
    "image17.png" = @("phase09-tool-staging",          "01-kali-mimikatz-http-server.png")
    "image18.png" = @("phase10-payload-delivery",      "01-ie-mimikatz-download-dialog.png")
    "image19.png" = @("phase11-token-impersonation",   "01-mimikatz-launch.png")
    "image20.png" = @("phase11-token-impersonation",   "02-privilege-debug-ok.png")
    "image21.png" = @("phase11-token-impersonation",   "03-token-list-output.png")
    "image22.png" = @("phase11-token-impersonation",   "04-token-elevation-confirmed.png")
    "image23.png" = @("phase12-c2-setup",              "01-msfconsole-launch.png")
    "image24.png" = @("phase12-c2-setup",              "02-msfvenom-payload-generated.png")
    "image25.png" = @("phase12-c2-setup",              "03-multihandler-listening.png")
    "image26.png" = @("phase13-sam-dump",              "01-token-whoami-admin-confirmed.png")
    "image27.png" = @("phase13-sam-dump",              "02-lsadump-sam-ntlm-hashes.png")
    "image28.png" = @("phase13-sam-dump",              "03-john-cracked-liverpool.png")
    "image29.png" = @("phase14-reverse-shell",         "01-zoom-setup-uac-prompt.png")
    "image30.png" = @("phase14-reverse-shell",         "02-metasploit-session-opened.png")
    "image31.png" = @("phase14-reverse-shell",         "03-whoami-shell-confirmed.png")
    "image32.png" = @("phase14-reverse-shell",         "04-netstat-established-4444.png")
    "image33.png" = @("phase15-persistence",           "01-net-user-hacker-add.png")
    "image34.png" = @("phase15-persistence",           "02-net-localgroup-admin-add.png")
    "image35.png" = @("phase16-final-cleanup",         "01-event-log-account-creation-events.png")
}

# ── CREATE FOLDERS ─────────────────────────────────────────────────────────
$folders = $map.Values | ForEach-Object { $_[0] } | Sort-Object -Unique
foreach ($f in $folders) {
    $path = Join-Path $base "screenshots\$f"
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "Created: screenshots\$f" -ForegroundColor Cyan
    }
}

# ── MOVE & RENAME ──────────────────────────────────────────────────────────
foreach ($filename in $map.Keys) {
    $src  = Join-Path $base $filename
    $dest = Join-Path $base "screenshots\$($map[$filename][0])\$($map[$filename][1])"

    if (Test-Path $src) {
        Move-Item -Path $src -Destination $dest -Force
        Write-Host "OK  $filename  →  $($map[$filename][0])\$($map[$filename][1])" -ForegroundColor Green
    } else {
        Write-Host "MISSING: $filename — skipped" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done! Now run:" -ForegroundColor Yellow
Write-Host "  git add screenshots/" -ForegroundColor White
Write-Host "  git commit -m `"Add 35 screenshots organized by phase`"" -ForegroundColor White
Write-Host "  git push" -ForegroundColor White