
function Test-View
{
    <#
    .SYNOPSIS
    Tests if a user-defined function exists.
    #>
    [CmdletBinding()]
    param(
        [string]
        $SchemaName = 'dbo',

        [Parameter(Mandatory=$true)]
        [string]
        # The name of the function.
        $Name
    )
    
    Set-StrictMode -Version Latest

    return ((Get-View @PSBoundParameters) -ne $null)
}
