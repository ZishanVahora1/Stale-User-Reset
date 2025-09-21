# StaleProfileCleanUp.ps1

# This script identifies user profiles on Windows machines that have not been used
# in the last 90 days. It uses a hybrid method: NTUSER.DAT timestamp (preferred),
# WMI LastUseTime (fallback), or folder timestamp (last resort).
# Exit code 1 = stale profiles found, Exit code 0 = none found.

# Define the cutoff date (90 days ago from now)
$Cutoff = (Get-Date).AddDays(-90)

# List of accounts that should never be considered stale (system, admin, service accounts, etc.)
#  IMPORTANT: CHANGE THESE TO WHAT TO TAILOR YOUR EXLUDED ACCOUNTS!!!

$ExcludeNames = @(
    'LocalService',      # Example service account
    'Administrator',   # Built-in admin account
    'Public',          # Public profile
    'Default',         # Default profile
    'Default User',    # Default user profile
    'WDAGUtilityAccount', # Windows Defender Application Guard account
    'All Users',
    'lapsadmin',       # Local admin managed by LAPS
    'svc_*'            # Any account starting with svc_
)

# Function to determine "last activity" of a profile
function Get-ActivityTime($profile) {
    # 1) Check NTUSER.DAT file timestamp (most reliable indicator of last login/logoff)
    $ntuser = Join-Path $profile.LocalPath 'NTUSER.DAT'
    if (Test-Path $ntuser) {
        try {
            $ntDate = [System.IO.File]::GetLastWriteTime($ntuser)
            if ($ntDate -gt [datetime]'1900-01-01') { return $ntDate }
        } catch { } # Ignore errors and move on
    }

    # 2) If NTUSER.DAT unavailable, fall back to WMI LastUseTime
    if ($profile.LastUseTime) {
        try {
            $wmiDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($profile.LastUseTime)
            if ($wmiDate -gt [datetime]'1900-01-01') { return $wmiDate }
        } catch { } # Ignore invalid values
    }

    # 3) If neither works, fall back to folder last write time
    try {
        $fld = Get-Item $profile.LocalPath -ErrorAction Stop
        return $fld.LastWriteTime
    } catch { return $null } # If folder missing, return null
}

# Get all user profiles from WMI that meet basic eligibility rules
$eligible = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -like 'C:\Users\*' -and              # Must be in C:\Users
    -not $_.Special -and                              # Skip special system profiles
    -not $_.Loaded -and                               # Skip profiles currently loaded (in use)
    $null -ne $_.LocalPath -and                       # Must have a valid path
    ($ExcludeNames -notcontains (Split-Path $_.LocalPath -Leaf)) # Skip excluded accounts
}

# For each eligible profile, determine last activity and filter out those older than cutoff
$stale = foreach ($p in $eligible) {
    $last = Get-ActivityTime $p                       # Get last activity time
    if ($last -and $last -lt $Cutoff) {               # If older than cutoff, mark as stale
        [PSCustomObject]@{
            UserName = Split-Path $p.LocalPath -Leaf  # Extract username from folder path
            LastUse  = $last                          # Last activity date
            Path     = $p.LocalPath                   # Full profile path
            Source   = if (Test-Path (Join-Path $p.LocalPath 'NTUSER.DAT')) { 
                          'NTUSER.DAT'                # Note if NTUSER.DAT was used
                       } else { 
                          'Fallback'                  # Otherwise WMI or folder time
                       }
        }
    }
}

# If stale profiles were found, display and export results
if ($stale) {
    $stale | Sort-Object LastUse | Format-Table -AutoSize   # Show sorted table on screen
    $csv = "C:\ProgramData\StaleProfiles_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date) # Filename
    $stale | Export-Csv -NoTypeInformation -Path $csv       # Export report to CSV
    Write-Host "`nSaved report to: $csv"                    # Tell user where report is saved
    exit 1   # Signal "non-compliant" (stale profiles exist)
} else {
    Write-Host "No stale profiles older than 90 days (hybrid check)." # Nothing found
    exit 0   # Signal "compliant" (no stale profiles)
}
