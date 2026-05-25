# 
# Aktuális Fájl: Launcher.ps1
# Bloatware Killer Launcher - Az RTS ökoszisztéma része.
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.9
#

# --- 1. JOGOSULTSÁG EMELÉS .NET ALAPON ---
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $SelfProcess = New-Object System.Diagnostics.ProcessStartInfo
    $SelfProcess.FileName = "powershell.exe"
    $SelfProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $SelfProcess.Verb = "runas"
    [System.Diagnostics.Process]::Start($SelfProcess) | Out-Null
    Exit
}

# --- KÖRNYEZETI VÁLTOZÓK ---
$TargetDir = "C:\Windows\Scripts\Bloatware-Killer"
$TargetLauncher = [System.IO.Path]::Combine($TargetDir, "Launcher.ps1")
$LogDir = [System.IO.Path]::Combine($TargetDir, "LOG")

$DailyStamp = [System.DateTime]::Now.ToString("yyyyMMdd")
$LogFile = [System.IO.Path]::Combine($LogDir, "BloatwareKiller_$DailyStamp.log")

$OldWrongDir = "C:\Windows\RTS-Scripts"

if (-not [System.IO.Directory]::Exists($TargetDir)) { [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null }
if (-not [System.IO.Directory]::Exists($LogDir)) { [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null }

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "--------------------------------------------------"
Write-Log "Launcher v0.1.9 elinditva."

if ([System.IO.Directory]::Exists($OldWrongDir)) {
    try {
        Write-Log "Regi, hibas mappa detektalva ($OldWrongDir). Automatikus torles..."
        Remove-Item -Path $OldWrongDir -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "A regi mappa sikeresen felszamolva."
    } catch { Write-Log "Nem sikerult a regi mappa torlese: $_" "WARN" }
}

# --- 2. VERZIÓELLENŐRZÉS ÉS BIZTONSÁGOS FRISSÍTÉS ---
Function Get-ScriptVersion {
    Param([string]$FilePath)
    if (-not [System.IO.File]::Exists($FilePath)) { return "0.0.0" }
    $Header = Get-Content -Path $FilePath -TotalCount 10
    foreach ($Line in $Header) {
        if ($Line -match "Verzió\s+v?(\d+\.\d+\.\d+)") { return $Matches }
    }
    return "0.0.0"
}

$CurrentVersionString = Get-ScriptVersion -FilePath $PSCommandPath
$InstalledVersionString = Get-ScriptVersion -FilePath $TargetLauncher

$CurrentVersion = [System.Version]$CurrentVersionString
$InstalledVersion = [System.Version]$InstalledVersionString

Write-Log "Futasi verzio: $CurrentVersionString | Telepitett korabbi verzio: $InstalledVersionString"

if ($PSScriptRoot -ne $TargetDir -or $CurrentVersion -gt $InstalledVersion) {
    try {
        if ($CurrentVersion -gt $InstalledVersion) {
            Write-Log "Ujabb verzio detektalva ($CurrentVersionString > $InstalledVersionString). Masolas..."
        } else {
            Write-Log "Elso telepites az RTS mappaba ($TargetDir)..."
        }

        Copy-Item -Path "$PSScriptRoot\*" -Destination $TargetDir -Recurse -Force
        Write-Log "A masolas es a fajlok elhelyezese sikeresen megtortent."
    } catch {
        Write-Log "KRITIKUS HIBA a masolas kozben: $_" "ERROR"
        Write-Host "[!] Hiba tortent a szinkronizalas soran!" -ForegroundColor Red
    }

    Write-Log "Frissitesi folyamat kesz. Log megnyitasa es konzol megallitasa..."
    [System.Diagnostics.Process]::Start("notepad.exe", $LogFile) | Out-Null

    Write-Host "`n[FRISSÍTÉS] A szkriptek frissitve lettek a vegleges helyre!" -ForegroundColor Green
    Write-Host "A frissitesi naplo megnyilt ellenorzesre." -ForegroundColor Gray
    Write-Host "Nyomj meg egy gombot az uj verzio tiszta inditasahoz..." -ForegroundColor Cyan
    [System.Console]::ReadKey($true) | Out-Null

    $RtsProcess = New-Object System.Diagnostics.ProcessStartInfo
    $RtsProcess.FileName = "powershell.exe"
    $RtsProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetLauncher`""
    [System.Diagnostics.Process]::Start($RtsProcess) | Out-Null
    Exit
}

# --- 3. TÁPELLÁTÁS ÉS ALVÁSKEZELÉS ---
try {
    $PowerStatus = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($PowerStatus.BatteryChargeStatus -ne "NoBattery") {
        if ($PowerStatus.PowerLineStatus -eq "Offline") {
            Write-Log "A gep akkumulatorrol uzemel!" "WARN"
            Write-Host "[!] FIGYELMEZTETES: A gep akkumulatorrol uzemel!" -ForegroundColor Yellow
        }
    }
} catch { Write-Log "Nem sikerult a .NET tapellatas-ellenorzes." "WARN" }

$Signature = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$Win32Sleep = Add-Type -MemberDefinition $Signature -Name "Win32Sleep" -Namespace "Win32" -PassThru
[uint32]$Flags = 0x80000001
$Win32Sleep::SetThreadExecutionState($Flags) | Out-Null

# --- 4. HARDVER DETEKTÁLÁS ---
$OSVersion = [System.Environment]::OSVersion.Version.Major
if ($OSVersion -eq 10 -and [System.Environment]::OSVersion.Version.Build -ge 22000) { $OSVersion = 11 }
$ComputerVendor = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
Write-Log "Rendszer vizsgalat: Windows $OSVersion | Gyarto: $ComputerVendor"

# --- 5. KERESŐ MEGHÍVÁSA ---
$SearchingScript = "$TargetDir\Scripts\Searching.ps1"
if ([System.IO.File]::Exists($SearchingScript)) {
    . $SearchingScript
} else {
    Write-Log "Kritikus hiba: A Searching.ps1 hianyzik: $SearchingScript" "ERROR"
    Write-Host "[!] Kritikus hiba: A Searching.ps1 hianyzik!" -ForegroundColor Red
}

# --- LEZÁRÁS ÉS AUTOMATIKUS LOG MEGNYITÁS ---
# JAVÍTVA: [uint32] helyett direkt C# bitmaszk tiszta átadással a túlcsordulási hiba ellen
$Win32Sleep::SetThreadExecutionState([uint32]0x80000000) | Out-Null
Write-Log "Bloatware Killer v0.1.9 futasa befejezodott."

Write-Log "Minden folyamat lezárult. Vegleges logfajl megnyitasa..."
[System.Diagnostics.Process]::Start("notepad.exe", $LogFile) | Out-Null

Write-Host "`n[VEGZETT] A folyamat befejezodott. A logfajl megnyilt a hatterben." -ForegroundColor Green
Write-Host "Nyomj meg egy gombot a konzol bezarasahoz..." -ForegroundColor Cyan
[System.Console]::ReadKey($true) | Out-Null
