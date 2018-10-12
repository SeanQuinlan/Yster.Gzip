function Resolve-DestinationPath {
    <#
    .SYNOPSIS
        Validates the DestinationPath variable.
    #>
    [CmdletBinding()]
    param(
        # The path to resolve
        [String]
        $Path
    )

    # Validation for null/empty is done at a higher level
    if ($Path.Trim() -eq [String]::Empty) {
        Write-Verbose ('DestinationPath not provided, will use folder from source Path')
        $DestinationPath = $null
    } else {
        $Check_for_Path = Test-Path -Path $Path -PathType 'Container'
        if ($Check_for_Path) {
            Write-Verbose ('DestinationPath exists: {0}' -f $Path)
        } else {
            Write-Verbose ('DestinationPath does not exist. Attempting to create.')
            try {
                $null = New-Item -ItemType 'Directory' -Path $Path -ErrorAction 'Stop'
            }
            catch {
                Write-Error ('Unable to create folder: {0}' -f $Path)
            }
        }

        $Resolve_Path = Resolve-Path -Path $Path
        if ($Resolve_Path.Count -gt 1) {
            Write-Error 'DestinationPath cannot be more than 1 path' -ErrorAction 'Stop'
        } elseif ($Resolve_Path.Provider.Name -ne 'FileSystem') {
            Write-Error ('DestinationPath not a FileSystem path: {0}' -f $Path) -ErrorAction 'Stop'
        } else {
            $DestinationPath = $Resolve_Path.ProviderPath
            Write-Verbose ('Final DestinationPath: {0}' -f $DestinationPath)
        }
    }

    # Return the DestinationPath
    $DestinationPath
}