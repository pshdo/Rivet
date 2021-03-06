 function Remove-Row
{
    <#
    .SYNOPSIS
    Removes a row from a table.
        
    .DESCRIPTION
    To specify which columns to insert into the new row, pass a hashtable as a value to the `Column` parameter.  This hashtable should have keys that map to column names, and the value of each key will be used as the value for that column in the row.
        
    .EXAMPLE
    Remove-Row -SchemaName 'rivet' 'Migrations' 'MigrationID=20130913132411'
        
    Demonstrates how to delete a specific set of rows from a table.
        
    .EXAMPLE
    Remove-Row 'Cars' -All
        
    Demonstrates how to remove all rows in a table.        
    #>
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        # The name of the table.
        $TableName,
            
        [Parameter()]
        [string]
        # The schema name of the table.  Default is `dbo`.
        $SchemaName = 'dbo',
            
        [Parameter(Mandatory=$true,Position=1,ParameterSetName='DropSpecificRows')]
        [string]
        # The condition to use for choosing which rows to remove.  This parameter is required, unless you *really* want to 
        $Where,
            
        [Parameter(Mandatory=$true,ParameterSetName='AllRows')]
        [Switch]
        # Drop all the rows in the table.
        $All,
            
        [Parameter(ParameterSetName='AllRows')]
        [Switch]
        # Truncate the table instead to delete all the rows.  This is faster than using a `delete` statement.
        $Truncate
    )

    Set-StrictMode -Version 'Latest'

    if ($PSCmdlet.ParameterSetName -eq 'DropSpecificRows')
    {
        New-Object 'Rivet.Operations.RemoveRowOperation' $SchemaName, $TableName, $Where        
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'AllRows')
    {
        if ($Truncate)
        {
            New-Object 'Rivet.Operations.RemoveRowOperation' $SchemaName, $TableName, $true
        }
        else
        {
            New-Object 'Rivet.Operations.RemoveRowOperation' $SchemaName, $TableName, $false
        }
    }
}