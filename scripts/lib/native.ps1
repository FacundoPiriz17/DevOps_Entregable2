function Invoke-PlayHubNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    $null = Get-Command $Command -ErrorAction Stop
    $outputFile = [System.IO.Path]::GetTempFileName()
    $errorFile = [System.IO.Path]::GetTempFileName()
    $previousPreference = $ErrorActionPreference
    $previousWhatIf = $WhatIfPreference
    try {
        $ErrorActionPreference = 'Continue'
        $WhatIfPreference = $false
        & $Command @Arguments 1> $outputFile 2> $errorFile
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        $output = [System.IO.File]::ReadAllText($outputFile)
        $errorOutput = [System.IO.File]::ReadAllText($errorFile)
        [pscustomobject]@{
            ExitCode = [int]$exitCode
            Output = $output.TrimEnd([char[]]"`r`n")
            ErrorOutput = $errorOutput.TrimEnd([char[]]"`r`n")
        }
    }
    finally {
        $ErrorActionPreference = $previousPreference
        $WhatIfPreference = $previousWhatIf
        Remove-Item -LiteralPath $outputFile, $errorFile -Force -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false
    }
}
