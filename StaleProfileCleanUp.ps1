# --- StaleProfileCleanUp.ps1 ---
# Detects stale user profiles on Windows systems.
# Exit code 1 = stale profiles found, Exit code 0 = none found.
# -------------------------------------------------------------

# Change this cutoff value for testing vs. production:
#   (Get-Date).AddDays(-0)   → forces ALL profiles to look stale (TEST mode)
#   (Get-Date).AddDays(-90)  → real 90-day stale detection (PRODUCTION mode)
$Cutoff = (Get-Date).AddDays(-0)   # <<-- CHANGE HERE

# Excluded accounts that should never be flagged
$ExcludeNames = @(
    'Administrator','Public','Default','Default User',
    'WDAGUtilityAccount','All Users','lapsadmin','svc_*'
)

function Get-ActivityTime($profile) {
    $ntuser = Join-Path $profile.LocalPath 'NTUSER.DAT'
    if (Test-Path $ntuser) {
        try { return [System.IO.File]::GetLastWriteTime($ntuser) } catch {}
    }
    if ($profile.LastUseTime) {
        try { return [System.Management.ManagementDateTimeConverter]::ToDateTime($profile.LastUseTime) } catch {}
    }
    try { return (Get-Item $profile.LocalPath).LastWriteTime } catch { return $null }
}

$eligible = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -like 'C:\Users\*' -and
    -not $_.Special -and
    -not $_.Loaded -and
    $null -ne $_.LocalPath -and
    ($ExcludeNames -notcontains (Split-Path $_.LocalPath -Leaf))
}

$stale = foreach ($p in $eligible) {
    $last = Get-ActivityTime $p
    if ($last -and $last -lt $Cutoff) {
        [PSCustomObject]@{
            UserName = Split-Path $p.LocalPath -Leaf
            LastUse  = $last
            Path     = $p.LocalPath
            Source   = if (Test-Path (Join-Path $p.LocalPath 'NTUSER.DAT')) { 'NTUSER.DAT' } else { 'Fallback' }
        }
    }
}

if ($stale) {
    $stale | Sort-Object LastUse | Format-Table -AutoSize
    $csv = "C:\ProgramData\StaleProfiles_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date)
    $stale | Export-Csv -NoTypeInformation -Path $csv
    Write-Host "`nSaved report to: $csv"
    exit 1
} else {
    Write-Host "No stale profiles older than cutoff."
    exit 0
}
