 function Update-View
 {
    <#
    .SYNOPSIS
    Updates an existing view.

    .DESCRIPTION
    Updates an existing view.

    .EXAMPLE
    Update-View -SchemaName 'rivet' 'ReadMigrations' 'AS select * from rivet.Migrations'

    Updates a view to read all the migrations from Rivet's Migrations table.  Don't do this in real life.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        # The name of the view.
        $Name,
        
        [Parameter()]
        [string]
        # The schema name of the view.  Defaults to `dbo`.
        $SchemaName = 'dbo',
        
        [Parameter(Mandatory=$true,Position=1)]
        [string]
        # The definition of the view.
        $Definition
    )
    
    $op = New-Object Rivet.Operations.UpdateViewOperation $SchemaName,$Name,$Definition
    Write-Host(' =[{0}].[{1}]' -f $SchemaName,$Name)
    Invoke-MigrationOperation -Operation $op
}