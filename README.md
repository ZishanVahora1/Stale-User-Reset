# Stale Profile Cleanup

# 🖥️ Stale Profile Cleanup (Hybrid Detection Script)

## 📌 Overview
This repository contains a PowerShell script **StaleProfileCleanUp.ps1** that detects **stale user profiles** on Windows machines.  
A user profile is considered stale if it has not been active for **90 days** (default, configurable).  

The script uses a **hybrid detection method** for improved reliability:
1. **NTUSER.DAT Last Write Time** – Most reliable indicator of last logoff/login.  
2. **WMI LastUseTime Property** – Falls back if NTUSER.DAT is missing or inaccessible.  
3. **Profile Folder Timestamp** – Last resort check if neither of the above are valid.  

This approach avoids false positives where Windows or background services might refresh WMI timestamps without real user activity.

The script is designed for:
- **Microsoft Intune Proactive Remediations** (exit code `1` = stale profiles found, `0` = none found).  
- **Local IT admins** who want to monitor or clean up unused accounts in shared environments such as **labs, kiosks, or classrooms**.  

---

## ⚙️ How to Use

1. **Copy the script** to your Windows device, e.g.: C:\Scripts\StaleProfileCleanUp.ps1

2. * Run in an elevated PowerShell window** (Administrator):  
PowerShell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass & "C:\Scripts\StaleProfileCleanUp.ps1

## Review output:

A formatted table of stale profiles is shown in the console.

A CSV report is saved under:

C:\ProgramData\StaleProfiles_YYYYMMDD_HHMMSS.csv

Exit codes (important for automation tools like Intune):

0 → No stale profiles

1 → Stale profiles found


## 🧪 Test Case: User-TestCase.ps1

The repository also includes a test script, User-TestCase.ps1, that creates a fake profile folder to simulate a stale account.
This allows safe testing without modifying real user profiles.



Steps:

Run User-TestCase.ps1 to create C:\Users\TestUserOld with a fake NTUSER.DAT set to 120 days ago.

Run the detection script:

& "C:\Scripts\StaleProfileCleanUp.ps1"





## Files
- ScripProfileCleanUp.ps1
- User-TestCase.ps1
