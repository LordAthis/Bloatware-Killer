# 
# Aktuális Fájl: Launcher.ps1
# Bloatware Killer Launcher - Az RTS ökoszisztéma része.
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.5
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

# --- KÖRNYEZETI VÁLTOZÓK (JAVÍTVA A KÉRT REPO ÚTVONALRA) ---
$TargetDir = "C:\Windows\Scripts\Bloatware-Killer"
$TargetLauncher = [System.IO.Path]::Combine($TargetDir, "Launcher.ps1")
$LogDir = [System.IO.Path]::Combine($TargetDir, "LOG")
$TimeStamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$LogFile = [System.IO.Path]::Combine($LogDir, "BloatwareKiller_$TimeStamp.log")

# Rendszermappák létrehozása .NET alapon
if (-not [System.IO.Directory]::Exists($TargetDir)) { [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null }
if (-not [System.IO.Directory]::Exists($LogDir)) { [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null }

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Bloatware Killer v0.1.5 elinditva."

# --- 2. INTENSÍV VERZIÓELLENŐRZÉS ÉS FRISSÍTÉSI LOGIKÁK ---
Function Get-ScriptVersion {
    Param([string]$FilePath)
    if (-not [System.IO.File]::Exists($FilePath)) { return "0.0.0" }
    $Header = Get-Content -Path $FilePath -TotalCount 10
    foreach ($Line in $Header) {
        if ($Line -match "Verzió\s+v?(\d+\.\d+\.\d+)") {
            return $Matches[1]
        }
    }
    return "0.0.0"
}

$CurrentVersionString = Get-ScriptVersion -FilePath $PSCommandPath
$InstalledVersionString = Get-ScriptVersion -FilePath $TargetLauncher

$CurrentVersion = [System.Version]$CurrentVersionString
$InstalledVersion = [System.Version]$InstalledVersionString

Write-Log "Futasi verzio: $CurrentVersionString | Telepitett korabbi verzio: $InstalledVersionString"

# Ha külső helyről futunk, VAGY frissebb verziót hoztunk a gépre
if ($PSScriptRoot -ne $TargetDir -or $CurrentVersion -gt $InstalledVersion) {
    try {
        if ($CurrentVersion -gt $InstalledVersion) {
            Write-Log "Ujabb verzio detektalva ($CurrentVersionString > $InstalledVersionString). Masolas..."
        } else {
            Write-Log "Elso telepites a megadott RTS mappaba ($TargetDir)..."
        }

        # Forrásfájlok átmásolása a központi mappába
        Copy-Item -Path "$PSScriptRoot\*" -Destination $TargetDir -Recurse -Force
        Write-Log "A masolas es a fajlok elhelyezese sikeresen megtortent."
        
    } catch {
        Write-Log "HIBA a masolas kozben: $_" "ERROR"
        Write-Host "[!] Hiba tortent a szinkronizalas soran. Ellenorizd a jogokat!" -ForegroundColor Red
    }

    # Megnyitjuk a frissítési naplót ellenőrzésre, hogy a szervizes lássa mi történt
    Write-Log "Frissitesi log automatikus megnyitasa ellenorzesre..."
    [System.Diagnostics.Process]::Start("notepad.exe", $LogFile) | Out-Null

    Write-Host "`n[FRISSÍTÉS] A szkriptek frissitve lettek a kozponti RTS mappaba!" -ForegroundColor Green
    Write-Host "A frissitesi naplo megnyilt a hatterben." -ForegroundColor Gray
    Write-Host "Nyomj meg egy gombot az uj verzio elinditasahoz..." -ForegroundColor Cyan
    [System.Console]::ReadKey($true) | Out-Null

    # Új verzió indítása a végleges helyéről
    $RtsProcess = New-Object System.Diagnostics.ProcessStartInfo
    $RtsProcess.FileName = "powershell.exe"
    $RtsProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetLauncher`""
    [System.Diagnostics.Process]::Start($RtsProcess) | Out-Null
    Exit
}

# --- 3. TÁPELLÁTÁS ÉS AKKUMULÁTOR ELLENŐRZÉS ---
try {
    $PowerStatus = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($PowerStatus.BatteryChargeStatus -ne "NoBattery") {
        Write-Log "Hordozhato eszkoz detektalva. Tapellatas ellenorzese..."
        if ($PowerStatus.PowerLineStatus -eq "Offline") {
            Write-Log "FIGYELMEZTETES: A gep akkumulatorrol uzemel! Csatlakoztasd a toltot!" "WARN"
            Write-Host "[!] FIGYELMEZTETES: A gep akkumulatorrol uzemel!" -ForegroundColor Yellow
        } else {
            Write-Log "Tapkabel csatlakoztatva."
        }
    }
} catch {
    Write-Log "Nem sikerult a .NET tapellatas-ellenorzes, atugras..." "WARN"
}

# --- 4. PIHENŐ MÓD MEGGÁTLÁSA ---
Write-Log "Alvo allapot letiltasa a script futasanak idejere..."
$Signature = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$Win32Sleep = Add-Type -MemberDefinition $Signature -Name "Win32Sleep" -Namespace "Win32" -PassThru

[uint32]$Flags = 0x80000001
$Win32Sleep::SetThreadExecutionState($Flags) | Out-Null

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
    Write-Log "Hiba: A Searching.ps1 nem talalhato itt: $SearchingScript" "ERROR"
    Write-Host "[!] Kritikus hiba: A Searching.ps1 hianyzik!" -ForegroundColor Red
}

# --- ALVÁS VISSZAÁLLÍTÁSA ---
[uint32]$ResetFlags = 0x80000000
$Win32Sleep::SetThreadExecutionState($ResetFlags) | Out-Null
Write-Log "Bloatware Killer v0.1.5 futasa sikeresen befejezodott."

# --- AZ ABLAK BEZÁRÁSÁNAK ABSZOLÚT MEGGÁTLÁSA ---
Write-Host "`n[VEGZETT] A folyamat befejezodott." -ForegroundColor Green
Write-Host "Nyomj meg egy gombot a konzolablak bezarasahoz..." -ForegroundColor Cyan
Write-Log "Szkript megallitva a Launcher vegen, varakozas a gombnyomasra..."
[System.Console]::ReadKey($true) | Out-Null
