<# Remediation Script: Enables DeviceLockdown + KeyboardFilter
   Then blocks specified keyboard shortcuts via WEKF
#>

$Log_File = "C:\ProgramData\DigitalTavle\Logs\Keyboard_Filter_Remediation.log"
$Keyboard_Shortcuts_to_disable = @(
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
    "MediaNextTrack",
    "MediaPrevTrack",
    "MediaStop",
    "MediaPlayPause",
    "Help",
    "Select",
    "Menu",
    "Apps"
)
$wekfNamespace = "root\standardcimv2\embedded"

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

Function Enable-Feature {
    param($Name)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR" "Failed to query feature $Name - $($_.Exception.Message)"
        return
    }

    if ($feature.State -ne "Enabled") {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart -ErrorAction Stop
            Write-Log "SUCCESS" "$Name enabled"
        }
        catch {
            Write-Log "ERROR" "Failed to enable $Name - $_"
        }
    }
    else {
        Write-Log "INFO" "$Name already enabled"
    }
}

Function Block-Shortcut {
    param($KeyID)

    $normalized = Resolve-ShortcutId -Shortcut $KeyID
    if (-not $normalized) {
        Write-Log "WARN" "Skipping invalid shortcut definition '$KeyID'"
        return
    }

    $predefined = Get-WmiObject -Namespace $wekfNamespace -Class WEKF_PredefinedKey -Filter "Id='$normalized'" -ErrorAction SilentlyContinue
    if ($predefined) {
        if ($predefined.Enabled -ne $true) {
            $predefined.Enabled = $true
            try {
                $predefined.Put() | Out-Null
                Write-Log "INFO" "Enabled predefined shortcut: $normalized"
            }
            catch {
                Write-Log "ERROR" "Failed to persist predefined shortcut '$KeyID' (normalized '$normalized') - $($_.Exception.Message)"
            }
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
            # Rule exists.  Just enable it.
            $custom.Enabled = 1;
            $custom.Put() | Out-Null;
            Write-Log "INFO" "Custom shortcut already enabled: $Id";

        }
        else {
            Set-WmiInstance `
                -Class WEKF_CustomKey `
                -Namespace $wekfNamespace `
                -Argument @{ Id = $Id } `
                -ErrorAction SilentlyContinue | Out-Null
            Write-Log "INFO" "Added Custom Filter $Id."
        }
    }
}
try {
    New-Item -Path $Log_File -ItemType File -Force | Out-Null
}
catch {
    $Log_File = Join-Path -Path $env:TEMP -ChildPath "Keyboard_Filter_Remediation.log"
    New-Item -Path $Log_File -ItemType File -Force | Out-Null
    Write-Log "WARN" "Unable to write to C:\Windows\Temp. Using fallback log path '$Log_File'."
}

# Enable required features
Enable-Feature -Name "Client-DeviceLockdown"
Enable-Feature -Name "Client-KeyboardFilter"
Write-Log "INFO" "A system restart is required for keyboard filtering to fully activate"

# After Enable-Feature calls
$wekfClasses = Get-WmiObject -Namespace $wekfNamespace -List -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like 'WEKF_*' }

if (-not $wekfClasses) {
    Write-Log "WARN" "WEKF_* WMI classes not found. A reboot may be required before keyboard filtering can be configured."
    return
}

# Block each shortcut
foreach ($shortcut in $Keyboard_Shortcuts_to_disable) {
    Block-Shortcut -KeyID $shortcut
}



