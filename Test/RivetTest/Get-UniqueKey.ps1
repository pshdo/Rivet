
function Get-UniqueKey
{
    <#
    .SYNOPSIS
    Gets a unique key.
    #>
    [CmdletBinding()]
    param(
        [string]
        $SchemaName = 'dbo',

        [Parameter(Mandatory=$true)]
        [string]
        # The name of the table whose primary key to get.
        $TableName,

        [string[]]
        # Columns that are part of the key.
        $ColumnName
    )
    
    Set-StrictMode -Version Latest

    $name = New-ConstraintName @PSBoundParameters -UniqueKey

    $query = @'
    select
       SCHEMA_NAME(t.schema_id) schema_name, t.name table_name, i.*
    from 
        sys.indexes i 
        inner join sys.tables t on i.object_id = t.object_id
    where 
        i.is_unique_constraint = 1 and i.name = '{0}'
'@ -f $name
    
    $key = Invoke-RivetTestQuery -Query $query 
    $key | Get-IndexColumn

}