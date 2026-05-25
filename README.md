# Bloatware-Killer
Mindenféle a rendszerbe települő kéretlen reklám és gyártói felesleges programok, applikációk, stb...


# RTS - Bloatware Killer (v0.1.17)

A RTS (Repair-Toning-Settings) ökoszisztéma moduláris része. Gyártó- és szegmensspecifikus előre telepített szoftverek (bloatware), kéretlen reklámprogramok és felesleges háttér-szolgáltatások automatizált felkutatása, naplózása, kezelése és törlése Windows 7, 10 és 11 rendszereken.

## 📂 A Projekt Struktúrája

```text
Bloatware-Killer/
│
├── Launcher.ps1          # Fő indító, jogosultság-, tápellátás- és verziókezelő
├── .gitignore            # Git szűrőfájl (LOG és ideiglenes fájlok kizárása)
├── README.md             # Szerviz szintű szakmai dokumentáció (ékezetes)
│
├── Data/                 # Gyártói JSON adatbázisok (verziózva)
│   ├── Acer/
│   ├── Asus/
│   ├── Dell/
│   ├── Gigabyte/
│   ├── Hp/
│   ├── Lenovo/
│   └── Msi/
│
└── Scripts/              # PowerShell végrehajtó modulok (.NET alapokon)
    ├── Searching.ps1     # Kereső és kiértékelő modul
    ├── Killer.ps1        # Ellenőrzött, erőszakos törlő és IFEO blokkoló modul
    └── ReInstall.ps1     # Helyreállító modul (IFEO tiltások feloldása)
```

## ⚙️ Működési Elv és Szerviz Logika

A szkriptcsomag szigorúan követi az **"Ellenőrzés -> Naplózás -> Végrehajtás (csak ha szükséges) -> Naplózás"** láncolatot, minimalizálva a felesleges lemezműveleteket és elkerülve az ál-hibaüzenetek generálását a rendszerben.

1. **Jogosultság és Frissítés:** A `Launcher.ps1` .NET alapon UAC jogot emel, majd ellenőrzi a futtatott szkript verzióját a `C:\Windows\Scripts\Bloatware-Killer` mappában található verzióval szemben. Ha újabb verzió van a pendrive-on, automatikusan lefrissíti a helyi tárolót, és a tiszta környezetből indul újra.
2. **Környezetvédelem:** Vizsgálja a hordozható eszközök tápellátását (akkumulátor csekkolás), és a futás idejére .NET API-n keresztül letiltja a Windows elalvási/pihenő módját.
3. **Konzekvens Naplózás:** Minden egyes modul (`Searching`, `Killer`, `ReInstall`) az indulásakor **explicit módon beírja a saját aktuális verziószámát** a központi, napi logfájlba.
4. **Biztonságos Kiértékelés:** A `Killer.ps1` a gyártói uninstaller folyamatok indítása után .NET alapú `$Proc.WaitForExit()` hurokkal megvárja a fizikai törlés végét, majd a summary kiírása előtt 3 másodperces kényszerített pihenőt alkalmaz, így a statisztika mindig a valós idejű registry-állapotot mutatja.

## 🛠️ Szakmai Indoklás és Gyártói Tapasztalatok (Reddit r/sysadmin alapján)

A gyártók komoly pénzeket kapnak az előre telepített szoftverek elhelyezéséért. Szervizelés és karbantartás során ezek eltávolítása kritikus a rendszer stabilitása és sebessége érdekében.

### 💻 Laptop Szegmens

* **HP (Hewlett-Packard):**
  * *HP Support Assistant / HP Insights:* Folyamatosan futnak a háttérben, feleslegesen eszik a CPU-t és a memóriát, miközben instabil driver-frissítésekkel kék halált okozhatnak.
  * *HP Connection Optimizer:* Híres a hálózati telemetria küldéséről és a rejtélyes Wi-Fi/Ethernet szakadások generálásáról.
  * *HP JumpStart Bridge:* Az első indításkor megjelenő kéretlen Dropbox/Adobe felugró reklámok főkezelője.
  * *HP Documentation:* Offline PDF-ek és haszontalan útmutatók, amik csak a helyet foglalják.
* **DELL:**
  * *Dell SupportAssist & Remediation:* Közismerten súlyos háttér-terhelést generálnak. A Remediation modul gyakran okoz rendszerindítási hurokhibákat (Boot Loop).
  * *SmartByte Network Service:* Az egyik legkárosabb szoftver. A hálózati forgalom priorizálásának álcázva képes az internetkapcsolat sávszélességét akár 50-70%-kal is lefojtani.
* **LENOVO:**
  * *Lenovo Vantage Service:* A lakossági verzió tele van akciókkal, reklámokkal és felhős tárhely-ajánlatokkal.
  * *System Interface Foundation (ImController):* Régebben több súlyos biztonsági rést (privilege escalation) is felfedeztek benne a kutatók, felesleges háttér-bejelentkező szoftver.
* **ACER:**
  * *Acer Care Center:* Tisztítónak álcázott bloatware, ami folyamatosan monitorozza a háttértárat, felesleges I/O műveleteket és lassulást generálva.

### 🖥️ Asztali (PC) és Alaplapi Szegmens

An egyedi építésű vagy márkás asztali számítógépeknél (MSI, Gigabyte, ASUS alaplapok) találhatók a legagresszívebb kártevő szoftvercsomagok. Ezeket a rendszergazdák az első helyen törlik, mert instabilitást, felesleges CPU-tüskéket és kék halált okoznak.

* **MSI Desktop Szegmens:**
  * *MSI Center:* Súlyos háttérbeli telemetria, rendkívül instabil RGB- és hardvervezérlő szoftver, ami feleslegesen fut az automatikus indításban.
  * *MSI Driver Utility Installer:* Minden tiszta Windows telepítés és indítás után erőszakosan felugró ablak, ami megpróbálja átvenni a Windows Update szerepét, felesleges vagy elavult szoftvereket erőltetve a felhasználóra. Az r/sysadmin és r/MSI_Gaming közösségek egyöntetű véleménye alapján azonnal eltávolítandó.
* **GIGABYTE Desktop Szegmens:**
  * *GIGABYTE Control Center (GCC) & APP Center:* A Gigabyte asztali alaplapjai a BIOS-ból (WPBT táblán keresztül) injektálják be ezeket a programokat az operációs rendszerbe a felhasználó tudta nélkül. Ezek sokszor hibás, elavult drivereket erőltetnek a gépre, súlyos CPU-terhelést és mikro-szaggatásokat okozva a játékok vagy professzionális munkák alatt.
* **ASUS Desktop Szegmens:**
  * *Armoury Crate:* Az egyik legrosszabbul optimalizált hardverkezelő szoftver a piacon. Telepítéskor több tucat különálló, egymást fojtogató háttérfolyamatra és szolgáltatásra töredezik szét, jelentősen megemelve a rendszer alapjárati fogyasztását és késleltetését (DPC Latency).

## 🛡️ IFEO Újratelepítés Elleni Védelem

Mivel a Windows Update vagy a gyári BIOS-injekciók hajlamosak a szoftvereket a háttérben automatikusan visszatelepíteni, a szkript **IFEO (Image File Execution Options)** registry-alapú futásgátlást alkalmaz a kritikus elemekre. A programok `.exe` fájljaihoz társított `Debugger` kulcsot átirányítja egy azonnal kilépő folyamatra (`cmd.exe /c exit`), így a bloatware-ek abban az esetben sem képesek többé elindulni vagy háttérfolyamatot indítani, ha valami később visszamásolná őket a lemezre.

