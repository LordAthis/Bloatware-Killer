# Bloatware Killer Launcher - Az RTS ökoszisztéma része.
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1
#

# --- 1. JOGOSULTSÁG EMELÉS (UAC) ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- KÖRNYEZETI VÁLTOZÓK ÉS UTASÍTÁSOK ---
$TargetDir = "C:\Windows\RTS-Scripts"
$LogDir = "$TargetDir\LOG"
$LogFile = "$LogDir\BloatwareKiller_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Type] $Message"
    Write-Host $LogLine
    Add-Content -Path $LogFile -Value $LogLine
}

Write-Log "Bloatware Killer v0.1 elinditva."

# --- 2. TÁPELLÁTÁS ÉS AKKUMULÁTOR ELLENŐRZÉS ---
$Battery = Get-CimInstance -ClassName Win32_Battery
if ($Battery) {
    $Status = Get-CimInstance -ClassName Win32_PortableBattery
    $ChargeStatus = (Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus).RemainingCapacity
    Write-Log "Hordozhato eszkoz detektalva. Akkumulator toltottseg ellenorzese..."
    
    # Egyszerűbb ellenőrzés a hálózati tápra
    $PowerLine = (Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus).PowerOnline
    if (-not $PowerLine) {
        Write-Log "FIGYELMEZTETES: A gep akkumulatorrol uzemel! Csatlakoztasd a toltot!" "WARN"
    } else {
        Write-Log "Tapkabel csatlakoztatva."
    }
}

# --- 3. PIHENŐ MÓD (ALVÁS) MEGGÁTLÁSA ---
Write-Log "Alvo allapot letiltasa a script futasanak idejere..."
$Signatures = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$CoreHook = Add-Type -MemberDefinition $Signatures -Name "Win32SleepPreventer" -Namespace "Win32" -PassThru
# ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001)
$CoreHook::SetThreadExecutionState(0x80000001)

# --- 4. TELEPÍTÉS ELLENŐRZÉSE / SZINKRONIZÁLÁS ---
Write-Log "Telepitesi kornyezet ellenorzese itt: $TargetDir"
if ($PSScriptRoot -ne $TargetDir) {
    Write-Log "A script nem a rendszerszintu mappaból fut. Masolas es szinkronizalas..."
    Copy-Item -Path "$PSScriptRoot\*" -Destination $TargetDir -Recurse -Force
    Write-Log "Szkriptek atmasolva. Ujrainditas a rendszerszintu kornyezetbol..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\Launcher.ps1`""
    Exit
}

# --- 5. RENDSZER- ÉS GYÁRTÓ DETEKTÁLÁS ---
$OSVersion = [Environment]::OSVersion.Version.Major
$ComputerVendor = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
Write-Log "Rendszer: Windows $OSVersion | Gyarto: $ComputerVendor"

# --- 6. KERESŐ MODUL MEGHÍVÁSA (Searching.ps1) ---
$ScriptPath = "$TargetDir\Scripts\Searching.ps1"
if (Test-Path $ScriptPath) {
    . $ScriptPath
} else {
    Write-Log "Hiba: A Searching.ps1 nem talalhato!" "ERROR"
    Exit
}

# --- PIHENŐ MÓD VISSZAÁLLÍTÁSA ---
$CoreHook::SetThreadExecutionState(0x80000000)
Write-Log "Bloatware Killer v0.1 futasa befejezodott."
