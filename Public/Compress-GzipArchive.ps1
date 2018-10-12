function Compress-GzipArchive {
    <#
    .SYNOPSIS
        Compress a file with Gzip.
    .DESCRIPTION
        Compresses a Gzipped file to the specified directory. If no destination directory is specified, compress to the same folder as the source.
    .EXAMPLE
        Compress-GzipArchive -Path C:\Temp\File.txt
    .EXAMPLE
        Compress-GzipArchive -Path C:\Temp\File.txt -DestinationPath C:\Windows\Temp -Force
    .EXAMPLE
        @('C:\Temp\File1.txt','C:\Temp\Archive*.log') | Compress-GzipArchive
    .INPUTS
        [String[]]
        A list of paths to the files that will be compressed.
    .NOTES
        Author: Sean Quinlan
        Email: sean@yster.org
    #>

    [CmdletBinding()]
    param(
        # Specifies the path to the file or files that you want to compress. Wildcards are allowed.
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Path,

        # Specifies the folder that the compressed file will be output to. If omitted, will default to same folder as the source.
        [ValidateNotNullOrEmpty()]
        [String]
        $DestinationPath,

        # The level of compression to use.
        [ValidateSet('Fastest','NoCompression','Optimal')]
        [String]
        $CompressionLevel = 'Optimal',

        # The file extension to use.
        [ValidateSet('gz','gzip')]
        [String]
        $Extension = 'gz',

        # Overwrite any files in the DestinationPath if they already exist.
        [Switch]
        $Force
    )

    begin {
        Write-Verbose ('Function: {0} [begin]' -f (Get-Variable MyInvocation -Scope 0).Value.MyCommand.Name)
        $PSBoundParameters.GetEnumerator() | ForEach-Object { Write-Verbose ('- Arguments: {0} - {1}' -f $_.Key,($_.Value -join ' ')) }

        if ($PSBoundParameters.ContainsKey('DestinationPath')) {
            $DestinationPath = Resolve-DestinationPath -Path $DestinationPath
        }

        $Input_Paths = New-Object -TypeName System.Collections.ArrayList
    }

    process {
        Write-Verbose ('Function: {0} [process]' -f (Get-Variable MyInvocation -Scope 0).Value.MyCommand.Name)

        if (-not $PSBoundParameters.ContainsKey('Path')) {
            $Path = $_
        }

        Write-Verbose ('Validating paths...')
        $Path | ForEach-Object {
            $Resolved_Path = $_ | Resolve-Path
            if (-not $Resolved_Path) {
                Write-Error ('Path "{0}" resolves to an empty set' -f $_)
            } else {
                $Resolved_Path | ForEach-Object {
                    if ([System.IO.File]::Exists($_)) {
                        Write-Verbose ('- Adding path: {0}' -f $_)
                        [void]$Input_Paths.Add($_.ProviderPath)
                    } else {
                        Write-Error ('Cannot find file "{0}" because it does not exist' -f $_) -ErrorAction 'Stop'
                    }
                }
            }
        }
        Write-Verbose ('Finished validating paths')

        foreach ($Input_Path in $Input_Paths) {
            Write-Verbose ('Compressing file: {0}' -f $Input_Path)
            if ($DestinationPath -eq [String]::Empty) { $DestinationPath = Split-Path -Path $Input_Path -Parent }

            $Input_File = Split-Path -Path $Input_Path -Leaf
            $Output_File = '{0}.{1}' -f $Input_File,$Extension
            $Output_Path = Join-Path -Path $DestinationPath -ChildPath $Output_File

            if ((Test-Path -Path $Output_Path) -and (-not $Force)) {
                Write-Error ('Destination file "{0}" already exists. Use -Force in order to overwrite existing files.' -f $Output_Path)
                continue
            }

            try {
                # From: https://docs.microsoft.com/en-us/dotnet/api/system.io.filestream.-ctor?view=netframework-4.7.2
                $Input_FileStream_Args = @(
                    $Input_Path                 # Path to file
                    [IO.FileMode]::Open         # FileMode
                    [IO.FileAccess]::Read       # FileAccess
                )
                $Input_FileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Input_FileStream_Args
                $Ouput_FileStream_Args = @(
                    $Output_Path                # Path to archive file
                    [IO.FileMode]::Create       # FileMode
                    [IO.FileAccess]::Write      # FileAccess
                )
                $Output_FileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Ouput_FileStream_Args
                # From: https://docs.microsoft.com/en-us/dotnet/api/system.io.compression.gzipstream?view=netframework-4.7.2
                $Gzip_Compress_Stream_Args = @(
                    $Output_FileStream                                      # Stream
                    [IO.Compression.CompressionLevel]::$CompressionLevel    # CompressionLevel
                )
                $Gzip_Compress_Stream = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $Gzip_Compress_Stream_Args

                try {
                    Write-Verbose ('Starting gzip compress stream')
                    $Buffer_Size = 1024
                    $Buffer = New-Object Byte[] $Buffer_Size

                    while ($Bytes_Read = $Input_FileStream.Read($Buffer,0,$Buffer_Size)) {
                        $Gzip_Compress_Stream.Write($Buffer,0,$Bytes_Read)
                        $Gzip_Compress_Stream.Flush()
                    }
                    Write-Verbose ('Completed gzip compress stream. File compressed to: {0}' -f $Output_Path)
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            finally {
                Write-Verbose ('Closing Filestream objects')
                if ($null -ne $Gzip_Compress_Stream) {
                    $Gzip_Compress_Stream.Close()
                    $Gzip_Compress_Stream.Dispose()
                }
                if ($null -ne $Input_FileStream) {
                    $Input_FileStream.Close()
                    $Input_FileStream.Dispose()
                }
                if ($null -ne $Output_FileStream) {
                    $Output_FileStream.Close()
                    $Output_FileStream.Dispose()
                }
            }
        }
    }
}