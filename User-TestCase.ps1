#User-TestCase


# Make a dummy profile folder
$testPath = "C:\Users\TestUserOld"
New-Item -ItemType Directory -Force -Path $testPath | Out-Null

# Create a fake NTUSER.DAT file
$ntuser = Join-Path $testPath "NTUSER.DAT"
New-Item -ItemType File -Path $ntuser -Force | Out-Null

# Change its LastWriteTime to 120 days ago
(Get-Item $ntuser).LastWriteTime = (Get-Date).AddDays(-120)
