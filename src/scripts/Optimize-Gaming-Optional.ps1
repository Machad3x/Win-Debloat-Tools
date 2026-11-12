Import-Module -DisableNameChecking "$PSScriptRoot\..\utils\Gaming-Aggressive-Tweaks.psm1"

function Optimize-Gaming-Optional() {
    [CmdletBinding()]
    param(
        [Switch] $Revert
    )
    $TweakType = "GamingOptional"

    Write-Title "Optional Aggressive Gaming Tweaks"

    Write-Status -Types "@", $TweakType -Status "These tweaks are aggressive and may reduce security/stability. Revert anytime via Undo." -Warning

    $bases = @(
        "MemoryIntegrityOptimization",
        "VirtualizationPlatformOptimization",
        "CpuMitigationsOptimization",
        "MpoOptimization",
        "GpuPreemptionOptimization",
        "GpuPowerSavingOptimization",
        "NvidiaPstateOptimization",
        "UlpsOptimization",
        "UnlockAllCoresOptimization",
        "DefenderRealtimeOptimization",
        "UsbSelectiveSuspendOptimization",
        "AudioEnhancementsOptimization",
        "GameBarCompleteOptimization",
        "WindowsSearchOptimization",
        "SysMainOptimization",
        "AnimationsTransparencyOptimization",
        "RecallCopilotWidgetsOptimization",
        "MpoMinFpsOptimization",
        "DisableAllOverlaysOptimization",
        "NagleAlgorithmOptimization",
        "VrrOptimization",
        "AutoHdrOptimization",
        "NvidiaSharpeningOptimization",
        "AutoColorManagementOptimization",
        "AutostartDelayOptimization",
        "BackgroundAppsOptimization",
        "MouseHoverTimeOptimization",
        "MenuShowDelayOptimization"
    )

    foreach ($b in $bases) {
        If (!$Revert) {
            & "Enable-$b"
        } Else {
            & "Disable-$b"
        }
    }

    Write-Status -Types "@", $TweakType -Status "Optional aggressive tweaks done. Reboot recommended." -Warning
}

If (!$Revert) {
    Optimize-Gaming-Optional
} Else {
    Optimize-Gaming-Optional -Revert
}
