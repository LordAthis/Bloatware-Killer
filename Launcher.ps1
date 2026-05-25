# 
# Aktuális Fájl: Launcher.ps1
# Bloatware Killer Launcher - Az RTS ökoszisztéma része.
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.2
#


# --- 1. JOGOSULTSÁG EMELÉS .NET ALAPON ---
$Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
$IsAdmin = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    $SelfProcess = New-Object System.Diagnostics.ProcessStartInfo
    $SelfProcess.FileName = "powershell.exe"
    $SelfProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $SelfProcess.Verb = "runas"
    [System.Diagnostics.Process]::Start($SelfProcess) | Out-Null
    Exit
}

# --- KÖRNYEZETI VÁLTOZÓK ---
$TargetDir = "C:\Windows\RTS-Scripts"
$LogDir = [System.IO.Path]::Combine($TargetDir, "LOG")
$TimeStamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$LogFile = [System.IO.Path]::Combine($LogDir, "BloatwareKiller_$TimeStamp.log")

if (-not [System.IO.Directory]::Exists($LogDir)) {
    [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null
}

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Bloatware Killer v0.1 elinditva."

# --- 2. TÁPELLÁTÁS ÉS AKKUMULÁTOR ELLENŐRZÉS ---
try {
    $PowerStatus = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($PowerStatus.BatteryChargeStatus -ne "NoBattery") {
        Write-Log "Hordozhato eszkoz detektalva. Tapellatas ellenorzese..."
        if ($PowerStatus.PowerLineStatus -eq "Offline") {
            Write-Log "FIGYELMEZTETES: A gep akkumulatorrol uzemel! Csatlakoztasd a toltot!" "WARN"
        } else {
            Write-Log "Tapkabel csatlakoztatva."
        }
    }
} catch {
    Write-Log "Nem sikerult a .NET tapellatas-ellenorzes, atugras..." "WARN"
}

# --- 3. PIHENŐ MÓD MEGGÁTLÁSA (TÍPUSKONVERZIÓS HIBA JAVÍTVA) ---
Write-Log "Alvo allapot letiltasa a script futasanak idejere..."
$Signature = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$Win32Sleep = Add-Type -MemberDefinition $Signature -Name "Win32Sleep" -Namespace "Win32" -PassThru

# Explicit [uint32] konverzió alkalmazása a túlcsordulás megelőzésére
[uint32]$Flags = 0x80000001
$Win32Sleep::SetThreadExecutionState($Flags) | Out-Null

# --- 4. TELEPÍTÉS ELLENŐRZÉSE ÉS SZINKRONIZÁLÁS ---
Write-Log "Telepitesi kornyezet ellenorzese itt: $TargetDir"
if ($PSScriptRoot -ne $TargetDir) {
    Write-Log "A script nem a rendszerszintu mappabol fut. Masolas es szinkronizalas..."
    if (-not [System.IO.Directory]::Exists($TargetDir)) { [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null }
    
    Copy-Item -Path "$PSScriptRoot\*" -Destination $TargetDir -Recurse -Force
    Write-Log "Szkriptek atmasolva. Ujrainditas a rendszerszintu kornyezetbol..."
    
    $RtsProcess = New-Object System.Diagnostics.ProcessStartInfo
    $RtsProcess.FileName = "powershell.exe"
    $RtsProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetDir\Launcher.ps1`""
    [System.Diagnostics.Process]::Start($RtsProcess) | Out-Null
    Exit
}

# --- 5. RENDSZER- ÉS GYÁRTÓ DETEKTÁLÁS ---
$OSVersion = [System.Environment]::OSVersion.Version.Major
if ($OSVersion -eq 10 -and [System.Environment]::OSVersion.Version.Build -ge 22000) { $OSVersion = 11 }

$ComputerVendor = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
Write-Log "Rendszer: Windows $OSVersion | Gyarto: $ComputerVendor"

# --- 6. KERESŐ MODUL MEGHÍVÁSA ---
$SearchingScript = [System.IO.Path]::Combine($TargetDir, "Scripts", "Searching.ps1")
if ([System.IO.File]::Exists($SearchingScript)) {
    . $SearchingScript
} else {
    Write-Log "Hiba: A Searching.ps1 nem talalhato!" "ERROR"
    Exit
}

# --- ALVÁS VISSZAÁLLÍTÁSA ---
[uint32]$ResetFlags = 0x80000000
$Win32Sleep::SetThreadExecutionState($ResetFlags) | Out-Null
Write-Log "Bloatware Killer v0.1 futasa befejezodott."
