<#
.SYNOPSIS
    Exports contents of specified file types from a target directory to an output file, with optional recursive search.

.DESCRIPTION
    The Export-FileContent function scans a specified directory for files matching one or more predefined extensions.
    For each matching file found, it appends the file's full path as a header followed by its content to a designated output file.
    By default, the function searches only the target directory. When the -Recurse switch is enabled, it includes all subdirectories
    in the search. This organized approach facilitates easy tracking and reviewing of the aggregated file contents.

.EXAMPLE
    Export-FileContent -Path "C:\Projects" -OutputFile "C:\Projects\output.txt" -Extensions "*.ps1", "*.md", "*.yml"

.EXAMPLE
    Export-FileContent -Path "C:\Projects" -OutputFile "C:\Projects\output.txt" -Extensions "*.ps1", "*.md" -Recurse -Verbose

.EXAMPLE
    Get-ChildItem -Path "C:\Scripts" -Filter "*.ps1" | Export-FileContent -OutputFile "C:\Scripts\scripts_output.txt" -Verbose

.INPUTS
    System.String
    System.IO.FileInfo

.OUTPUTS
    None

.NOTES
    - Requires appropriate permissions to read files and write to the output location.
    - The output file will be overwritten if it already exists.
    - Use the -Verbose and -Debug switches to receive detailed execution information.

.COMPONENT
    File Management

.ROLE
    Administrator, Developer

.FUNCTIONALITY
    File Aggregation, Content Export
#>
[CmdletBinding(DefaultParameterSetName = 'ByPath')]
[OutputType([String])]
Param (
    # The root directory from which to start the search
    [Parameter(ParameterSetName = 'ByPath')]
    $Path,

    # The output file where the aggregated content will be stored
    [Parameter(ParameterSetName = 'ByPath')]
    $OutputFile = "output.txt", 

    # The list of file extensions to include in the search
    [Parameter(ParameterSetName = 'ByPath')]
    [ValidateSet("*.ps1", "*.md", "*.tf", "*.sh", "*.py", "*.bat", "*.yml", IgnoreCase = $true)]
    [string[]]
    $Extensions = @("*.ps1"),

    # Switch to enable recursive search in subdirectories
    [Parameter()]
    [switch]
    $Recurse,

    # Accept pipeline input for FileInfo objects
    [Parameter(ParameterSetName = 'PipelineInput')]
    [System.IO.FileInfo[]]
    $InputObject
)
function Export-FileContent {
    <#
    .SYNOPSIS
        Exports contents of specified file types from a target directory to an output file, with optional recursive search.

    .DESCRIPTION
        The Export-FileContent function scans a specified directory for files matching one or more predefined extensions.
        For each matching file found, it appends the file's full path as a header followed by its content to a designated output file.
        By default, the function searches only the target directory. When the -Recurse switch is enabled, it includes all subdirectories
        in the search. This organized approach facilitates easy tracking and reviewing of the aggregated file contents.

    .EXAMPLE
        Export-FileContent -Path "C:\Projects" -OutputFile "C:\Projects\output.txt" -Extensions "*.ps1", "*.md", "*.yml"

    .EXAMPLE
        Export-FileContent -Path "C:\Projects" -OutputFile "C:\Projects\output.txt" -Extensions "*.ps1", "*.md" -Recurse -Verbose

    .EXAMPLE
        Get-ChildItem -Path "C:\Scripts" -Filter "*.ps1" | Export-FileContent -OutputFile "C:\Scripts\scripts_output.txt" -Verbose

    .INPUTS
        System.String
        System.IO.FileInfo

    .OUTPUTS
        None

    .NOTES
        - Requires appropriate permissions to read files and write to the output location.
        - The output file will be overwritten if it already exists.
        - Use the -Verbose and -Debug switches to receive detailed execution information.

    .COMPONENT
        File Management

    .ROLE
        Administrator, Developer

    .FUNCTIONALITY
        File Aggregation, Content Export
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ByPath',
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        HelpUri = 'https://github.com/PPadgett/Export-FileContent',
        ConfirmImpact = 'Low'
    )]
    [Alias('EFC')]
    [OutputType([String])]

    Param (
        # The root directory from which to start the search
        [Parameter(
            Mandatory = $false,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The root directory to search. Defaults to the current directory.",
            ParameterSetName = 'ByPath'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = ".", 

        # The output file where the aggregated content will be stored
        [Parameter(
            Mandatory = $false,
            Position = 1,
            HelpMessage = "The path to the output file. Defaults to 'output.txt' in the current directory.",
            ParameterSetName = 'ByPath'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputFile = "output.txt", 

        # The list of file extensions to include in the search
        [Parameter(
            Mandatory = $false,
            Position = 2,
            HelpMessage = "An array of file extensions to include in the search. Each extension should start with '*.', e.g., '*.ps1'. Defaults to '*.ps1'.",
            ParameterSetName = 'ByPath'
        )]
        [ValidateSet("*.ps1", "*.md", "*.tf", "*.sh", "*.py", "*.bat", "*.yml", IgnoreCase = $true)]
        [string[]]
        $Extensions = @("*.ps1"),

        # Switch to enable recursive search in subdirectories
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Enable recursive search in all subdirectories."
        )]
        [switch]
        $Recurse,

        # Accept pipeline input for FileInfo objects
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            HelpMessage = "Accepts FileInfo objects from the pipeline."
        )]
        [System.IO.FileInfo[]]
        $InputObject
    )

    Begin {
        Write-Verbose "Initializing Export-FileContent function."

        # Initialize a list to store file paths
        $fileList = @()

        # Resolve and validate the output file path
        Write-Verbose "Resolving output file path: $OutputFile"
        try {
            $outputDirectory = Split-Path -Path $OutputFile -Parent
            if ([string]::IsNullOrEmpty($outputDirectory)) {
                $outputDirectory = Get-Location
                Write-Verbose "No parent directory specified for OutputFile. Using current directory: $outputDirectory"
            }

            $resolvedOutputPath = Resolve-Path -Path $outputDirectory -ErrorAction Stop
            Write-Verbose "Output directory resolved to: $resolvedOutputPath"
        }
        catch {
            Write-Debug "Error resolving output file path: $_"
            Throw "Invalid OutputFile path: $OutputFile. $_"
        }

        # Initialize or clear the output file
        try {
            if (Test-Path -Path $OutputFile) {
                Write-Verbose "Clearing existing output file: $OutputFile"
                Clear-Content -Path $OutputFile -ErrorAction Stop
            }
            else {
                Write-Verbose "Creating new output file: $OutputFile"
                New-Item -Path $OutputFile -ItemType File -Force | Out-Null
            }
        }
        catch {
            Write-Debug "Error initializing output file: $_"
            Throw "Failed to initialize OutputFile: $OutputFile. $_"
        }

        Write-Verbose "Initialization complete."
    }

    Process {
        if ($InputObject) {
            Write-Verbose "Processing pipeline input objects."
            # Processing pipeline input (FileInfo objects)
            $InputObject | ForEach-Object {
                Write-Debug "Evaluating file: $($_.FullName)"
                if ($Extensions -contains "*.$($_.Extension.TrimStart('.'))") {
                    Write-Verbose "Adding file to list: $($_.FullName)"
                    $fileList += $_.FullName
                }
                else {
                    Write-Debug "File extension does not match specified extensions: $($_.FullName)"
                }
            }
        }
        else {
            Write-Verbose "Processing parameters."
            # Processing parameters
            try {
                Write-Verbose "Resolving root path: $Path"
                $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
                Write-Verbose "Root path resolved to: $resolvedPath"

                # Loop through each extension and retrieve matching files using ForEach-Object
                $Extensions | ForEach-Object {
                    $ext = $_
                    Write-Verbose "Searching for files with extension: $ext (Recurse: $($Recurse.IsPresent))"
                    try {
                        Get-ChildItem -Path $resolvedPath -Recurse:$($Recurse.IsPresent) -Filter $ext -File -ErrorAction Stop |
                            ForEach-Object {
                                Write-Debug "Found file: $($_.FullName)"
                                $fileList += $_.FullName
                            }
                    }
                    catch {
                        Write-Debug "Error retrieving files with extension '$ext': $_"
                        Write-Warning "Failed to retrieve files with extension '$ext': $_"
                    }
                }
            }
            catch {
                Write-Debug "Error resolving path '$Path': $_"
                Write-Error "Error resolving path '$Path': $_"
                return
            }
        }
    }

    End {
        Write-Verbose "Finalizing Export-FileContent function."

        if ($fileList.Count -eq 0) {
            Write-Verbose "No files found with the specified extensions: $($Extensions -join ', ')"
            Write-Warning "No files found with the specified extensions: $($Extensions -join ', ')"
            return
        }

        # Remove duplicate file paths using Sort-Object -Unique
        Write-Verbose "Removing duplicate file paths."
        $uniqueFiles = $fileList | Sort-Object -Unique

        Write-Verbose "Processing $($uniqueFiles.Count) unique files."

        $uniqueFiles | ForEach-Object {
            $filePath = $_
            Write-Verbose "Preparing to export content of file: $filePath"

            # Confirm before processing each file if ShouldProcess is enabled
            if ($PSCmdlet.ShouldProcess($filePath, "Exporting content to $OutputFile")) {
                try {
                    # Write the file path as a header
                    $header = "`n`n=== File: $filePath ===`n"
                    Write-Verbose "Writing header for file: $filePath"
                    Add-Content -Path $OutputFile -Value $header -ErrorAction Stop

                    # Read and append the file content using ForEach-Object for better memory management
                    Write-Verbose "Reading content from file: $filePath"
                    Get-Content -Path $filePath -ErrorAction Stop | ForEach-Object {
                        Add-Content -Path $OutputFile -Value $_ -ErrorAction Stop
                    }

                    Write-Verbose "Successfully exported content of file: $filePath"
                }
                catch {
                    Write-Debug "Error processing file '$filePath': $_"
                    Write-Warning "Failed to process file '$filePath': $_"
                    Add-Content -Path $OutputFile -Value "`n# Error reading file content.`n" -ErrorAction Stop
                }
            }
            else {
                Write-Verbose "Skipping file due to ShouldProcess: $filePath"
            }
        }

        Write-Verbose "All specified files have been exported to '$OutputFile'."
    }
}

# Check if the script is being executed directly with parameters, if not is assumed to be dot-sourced for testing
# if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript' -and $MyInvocation.MyCommand.Name -and $PSBoundParameters.Count -gt 0) {
#     try {
#         # Execute the function based on the parameter set used
#         switch ($PSCmdlet.ParameterSetName) {
#             'ByPath' {
#                 Write-Verbose "Executing Export-FileContent function based on parameter set 'ByPath'"
#                 Export-FileContent @PSBoundParameters
#                 Write-Warning "PSBoundParameters:`n$($PSBoundParameters | Format-List | Out-String)"
#                 $paramValue = $MyInvocation.MyCommand.Parameters.pipelineVariable #.ParameterSets
#                 Write-Warning "MyInvocation.MyCommand.Parameters:$($paramValue | Out-String)"

#             }
#             'PipelineInput' {
#                 Write-Verbose "Executing Export-FileContent function based on parameter set 'Pipeline'"
#                 Export-FileContent @PSBoundParameters
#             }
#             default {
#                 Write-Warning "Unhandled parameter set: $paramSetName. Export-FileContent not executed."
#             }
#         }
#     }
#     catch {
#         Write-Error "An error occurred while executing Export-FileContent: $_"
#     }
# }
# else {
#     Write-Verbose "Skipping function execution due to the absence of required execution context or parameters. Script Function has been dot-sourced for testing."
# }

# Check if the script is being executed directly with parameters, if not is assumed to be dot-sourced for testing
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript' -and $MyInvocation.MyCommand.Name -and $PSBoundParameters.Count -gt 0) {
    Write-Verbose "Identified parameter set: $($PSCmdlet.ParameterSetName)"

    # Execute the function based on the parameter set used passed to the script.
    switch ($PSCmdlet.ParameterSetName) {
        '__AllParameterSets' {
            Write-Verbose "Executing Export-FileContent function based on parameter set"
            Invoke-ReadmeAnalyzer @PSBoundParameters
        }
        'PipelineInput' {
            Write-Verbose "Executing Export-FileContent function based on parameter set 'Pipeline'"
            Export-FileContent @PSBoundParameters
        }
        'ByPath' {
            Write-Verbose "Executing Export-FileContent function based on parameter set 'ByPath'"
            Export-FileContent @PSBoundParameters
        }
    }
}
else {
    Write-Verbose "Skipping function execution due to the absence of required execution context or parameters. Script Function has been dot-sourced"
}