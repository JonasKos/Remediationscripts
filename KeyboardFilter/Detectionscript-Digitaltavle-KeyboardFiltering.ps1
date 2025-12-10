<# Detection Script: Keyboard Filtering Status Check
   Checks if DeviceLockdown and KeyboardFilter features are enabled,
   and if specified shortcuts are blocked. Does NOT modify state.
#>

$Log_File = "C:\ProgramData\DigitalTavle\Logs\Keyboard_Filter_Detection.log"
$Keyboard_Shortcuts_to_disable = @(
    # --- System escape & task switching ---
    # --- System escape & task switching ---
    "Ctrl+Alt+Del",       # Secure attention sequence
    "Ctrl+Shift+Esc",     # Task Manager
    "Ctrl+Esc",           # Start menu when Win key is disabled
    "Alt+Tab",            # App switcher
    "Ctrl+Alt+Tab",       # Sticky app switcher
    "Alt+Esc",            # Cycle through windows
    "Win+Tab",            # Task view / desktops
    "Alt+F4",             # Close app
    "Win+L",              # Lock workstation

    # --- Start / Search / Launchers / System panes ---
    # "Windows",            # Windows key alone (opens Start)
    "Win+R",              # Run
    "Win+E",              # File Explorer
    "Win+X",              # Power user menu
    "Win+I",              # Settings
    "Win+S",              # Search
    "Win+Q",              # Search/Copilot entry point
    "Win+C",              # Copilot/Cortana
    "Win+V",              # Clipboard history
    "Win+N",              # Notification Center
    "Win+W",              # Widgets
    "Win+A",              # Quick Settings (Action Center)
    "Win+P",              # Project/Display switcher
    "Win+K",              # Cast/Connect
    "Win+G",              # Xbox Game Bar
    "Win+U",              # Accessibility
    "Win+O",              # Orientation lock
    "Win+H",              # Voice typing / dictation
    "Win+Z",              # Snap layouts
    "Win+T",              # Cycle taskbar apps
    "Win+B",              # Focus notification area
    "Win+Space",          # Switch input language
    "Win+Pause",          # System properties

    # --- Taskbar app launch (1..9) ---
    "Win+1", "Win+2", "Win+3", "Win+4", "Win+5", "Win+6", "Win+7", "Win+8", "Win+9",

    # --- Window management & virtual desktops ---
    "Win+D",              # Show desktop
    "Win+M",              # Minimize all
    "Win+Shift+M",        # Restore minimized
    "Win+Home",           # Minimize all but active
    "Win+Up", "Win+Down", "Win+Left", "Win+Right",          # Snap/maximize/minimize
    "Win+Shift+Left", "Win+Shift+Right",                    # Move window across monitors
    "Win+Shift+Up", "Win+Shift+Down",                       # Vertical resize/restore
    "Win+Ctrl+D", "Win+Ctrl+Left", "Win+Ctrl+Right", "Win+Ctrl+F4",  # Virtual desktops

    # --- Capture & overlays ---
    "Win+Shift+S",    # Screenshots/snipping

    # --- Media keys --- 
    "LaunchMail", 
    "LaunchMediaSelect",
    "LaunchApp1",
    "LaunchApp2",
    "BrowserBack",
    "BrowserForward",
    "BrowserRefresh",
    "BrowserStop",
    "BrowserSearch",
    "BrowserFavorites",
    "BrowserHome",
    "VolumeMute",
    "VolumeDown",
    "VolumeUp",
    "MediaStop",
    "MediaPlayPause",
    "Help",
    "Select"
)
$missingCount = 0
$wekfNamespace = "root\standardcimv2\embedded"
$script:FeatureQueryError = $false

Function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("INFO", "WARN", "WARNING", "ERROR", "SUCCESS")]
        [string]$Type,
        [Parameter(Mandatory)]
        [string]$Message
    )
    $Time = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
    $Line = "[$Time] [$Type] $Message"
    Write-Output $Line
    switch ($Type) {
        "ERROR" { Write-Host $Line -ForegroundColor Red }
        "WARN" { Write-Host $Line -ForegroundColor Yellow }
        "WARNING" { Write-Host $Line -ForegroundColor Yellow }
        default { }
    }
    Add-Content -Path $Log_File -Value $Line
}

Function Resolve-ShortcutId {
    param([string]$Shortcut)

    if ([string]::IsNullOrWhiteSpace($Shortcut)) {
        return $null
    }

    $normalized = $Shortcut.Trim()
    $normalized = $normalized -replace '\s*\+\s*', '+'

    return $normalized
}

Function Get-FeatureState {
    param($Name)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        return [pscustomobject]@{
            Name    = $Name
            Enabled = ($feature.State -eq 'Enabled')
            Error   = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Name    = $Name
            Enabled = $false
            Error   = $_.Exception.Message
        }
    }
}

<# Function Is-ShortcutBlocked {
    param([string]$Shortcut)

    $normalized = Resolve-ShortcutId -Shortcut $Shortcut
    if (-not $normalized) {
        return [pscustomobject]@{
            Shortcut   = $Shortcut
            Normalized = $null
            Recognized = $false
            Blocked    = $false
        }
    }

    foreach ($class in @("WEKF_PredefinedKey", "WEKF_CustomKey")) {
        $entry = Get-WmiObject -Namespace $wekfNamespace -Class $class -Filter "Id='$normalized'" -ErrorAction SilentlyContinue
        if ($entry) {
            return [pscustomobject]@{
                Shortcut   = $Shortcut
                Normalized = $normalized
                Recognized = $true
                Blocked    = ($entry.Enabled -eq $true)
            }
        }
    }

    return [pscustomobject]@{
        Shortcut   = $Shortcut
        Normalized = $normalized
        Recognized = $false
        Blocked    = $false
    }
} #>

try {
    New-Item -Path $Log_File -ItemType File -Force | Out-Null
}
catch {
    $Log_File = Join-Path -Path $env:TEMP -ChildPath "Keyboard_Filter_Detection.log"
    New-Item -Path $Log_File -ItemType File -Force | Out-Null
    Write-Log "WARN" "Unable to write to C:\ProgramData\DigitalTavle\Logs. Using fallback log path '$Log_File'."
}

# Feature checks
$features = @("Client-DeviceLockdown", "Client-KeyboardFilter")
$featuresMissing = 0
foreach ($feature in $features) {
    $featureState = Get-FeatureState -Name $feature
    if ($featureState.Error) {
        $script:FeatureQueryError = $true
        Write-Log "ERROR" "Failed to query feature $feature - $($featureState.Error)"
    }
    if ($featureState.Enabled) {
        Write-Log "INFO" "$feature is enabled"
    }
    else {
        Write-Log "INFO" "$feature is NOT enabled"
        $featuresMissing++
    }
}
$missingCount += $featuresMissing

# Shortcut checks
if ($featuresMissing -eq 0 -and -not $script:FeatureQueryError) {
    <# foreach ($shortcut in $Keyboard_Shortcuts_to_disable) {
        $state = Is-ShortcutBlocked -Shortcut $shortcut
        if (-not $state.Recognized) {
            if ($state.Normalized) {
                Write-Log "WARN" "Shortcut '$shortcut' (normalized '$($state.Normalized)') is not recognized by keyboard filter"
            }
            else {
                Write-Log "WARN" "Shortcut '$shortcut' is not a valid shortcut definition"
            }
            $missingCount++
            continue
        }

        if (-not $state.Blocked) {
            Write-Log "INFO" "Shortcut '$shortcut' is NOT blocked"
            $missingCount++
        }
        else {
            Write-Log "INFO" "Shortcut '$shortcut' is blocked"
        }
    } #>
    foreach ($shortcut in $Keyboard_Shortcuts_to_disable) {
        $KeyID = $shortcut

        $normalized = Resolve-ShortcutId -Shortcut $KeyID
        if (-not $normalized) {
            Write-Log "WARN" "Skipping invalid shortcut definition '$KeyID'"
            continue
        }

        $predefined = Get-WmiObject -Namespace $wekfNamespace -Class WEKF_PredefinedKey -Filter "Id='$normalized'" -ErrorAction SilentlyContinue
        if ($predefined) {
            if ($predefined.Enabled -ne $true) {
                $missingCount++
                Write-Log "INFO" "Shortcut '$shortcut' is NOT blocked"
                <# $predefined.Enabled = $true
                try {
                    $predefined.Put() | Out-Null
                    Write-Log "INFO" "Enabled predefined shortcut: $normalized"
                }
                catch {
                    Write-Log "ERROR" "Failed to persist predefined shortcut '$KeyID' (normalized '$normalized') - $($_.Exception.Message)"
                } #>
            }
            else {
                Write-Log "INFO" "Predefined shortcut already enabled: $normalized"
            }
        }
        else {
            <# $custom = Get-WmiObject -Namespace $wekfNamespace -Class WEKF_CustomKey -Filter "Id='$normalized'" -ErrorAction SilentlyContinue
        if (-not $custom) {
            try {
                $custom = ([WMIClass]"\\.\$wekfNamespace:WEKF_CustomKey").CreateInstance()
                $custom.Id = $normalized
            } catch {
                Write-Log "ERROR" "Failed to create custom shortcut '$KeyID' (normalized '$normalized') - $($_.Exception.Message)"
                return
            }
        }
        $custom.Enabled = $true
        try {
            $custom.Put() | Out-Null
            Write-Log "INFO" "Enabled custom shortcut: $normalized"
        } catch {
            Write-Log "ERROR" "Failed to persist custom shortcut '$KeyID' (normalized '$normalized') - $($_.Exception.Message)"
        } #>
            $Id = $normalized;
            $custom = Get-WMIObject -class WEKF_CustomKey -Namespace $wekfNamespace -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Id -eq "$Id"
            };

            if ($custom) {
                # Rule exists.  inform that it's already enabled.
                #Write-Log "INFO" "Custom shortcut already enabled: $Id";
                #check enabled state
                if ($custom.Enabled -eq $true){
                    Write-Log "INFO" "Shortcut '$shortcut' is blocked"
                }
                else {
                    $missingCount++
                    Write-Log "INFO" "Shortcut '$shortcut' is NOT blocked"
                }

            }
            else {
                # Rule does not exist.  inform that it's NOT blocked and increase missing count.
                $missingCount++
                Write-Log "INFO" "Shortcut '$shortcut' is NOT blocked"
            }
        }
    }
}
elseif ($featuresMissing -gt 0) {
    Write-Log "WARN" "Skipping shortcut evaluation because required features are missing"
}
elseif ($script:FeatureQueryError) {
    Write-Log "WARN" "Skipping shortcut evaluation because feature status could not be verified"
}

if ($missingCount -gt 0) {
    Exit 1
}
else {
    Exit 0
}
