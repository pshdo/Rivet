
function New-TempDirectoryTree
{
    <#
    .SYNOPSIS
    Create a directory tree in a temporary directory.

    .DESCRIPTION

    Uses a simple DSL to create a temporary directory tree in the current user's `$env:TEMP` directory.  Here's an example:

        New-TemporaryDirectoryTree -Tree @'
        + Database1
          + Migrations
            * 20130703152600_CreateTable.ps1
        + Database2
          + Migrations
            * 20130703152600_CreateTable.ps1
        '@
    
    Databases are prefixed with `+`.  Files are prefixed with `+`.  To create an item underneath a directory, indent it two spaces further than the parent directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]
        # The directory tree to create.
        $Tree,
        
        [string]
        # An optional prefix for the temporary directory's name.
        $Prefix
    )
    
    $stackName = 'New-TempDirectoryTree'
    
    $optionalParams = @{ }
    if( $Prefix )
    {
        $optionalParams.Prefix = $Prefix
    }
    
    $tempDir = New-TempDirectory @optionalParams
    $startLocation = Get-Location
    Push-Location -Path $tempDir -StackName $stackName
    
    try
    {
        $parent = $tempDir
        $lastDir = $tempDir
        $lastIndent = ''
        
        ($Tree -split "`r?`n") |
            Where-Object { $_ } |
            ForEach-Object {
                if( $_ -notmatch '^((  )+)?(\*|\+) ?(.*)$' )
                {
                    Write-Error ('Invalid line for directory tree: <{0}>' -f $_)
                    return
                }
                $indent = $matches[1]
                if( -not $indent )
                {
                    $indent = ''
                }
                
                $itemType = $matches[3]
                $name = $matches[4]
                
                if( $lastIndent.Length -lt $indent.Length )
                {
                    Push-Location -Path (Join-Path (Get-Location) $lastDir) -StackName $stackName
                }
                elseif( $indent.Length -lt $lastIndent.Length )
                {
                    $levelsUp = (($lastIndent.Length - $indent.Length) / 2) - 1
                    (0..$levelsUp) | ForEach-Object { Pop-Location -StackName $stackName }
                }
                else
                {
                    # Same level.  Do nothing.
                }
                
                if( $itemType -eq '*' )
                {
                    $itemType = 'File'
                    $pathType = 'Leaf'
                }
                else
                {
                    $itemType = 'Directory'
                    $pathType = 'Container'
                    $lastDir = $name
                }
                
                if( -not (Test-Path -Path $name -PathType $pathType) )
                {
                    $null = New-Item -Path $name -ItemType $itemType
                }
                
                $lastIndent = $indent
            }
            
        $tempDir
    }
    finally
    {
        Set-Location $startLocation
    }
}
