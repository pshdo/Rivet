function New-TimeColumn
{
    <#
    .SYNOPSIS
    Creates a column object representing an Time datatype.

    .DESCRIPTION
    Use this function in the `Column` script block for `Add-Table`:

        Add-Table 'WithTime' {
            Time 'ColumnName'
        }

    ## ALIASES

     * Time

    .EXAMPLE
    Add-Table 'WithTime' { New-TimeColumn 'CreatedAt' 5 -NotNull }

    Demonstrates how to create a required `time` column with a given scale when adding a new table.

    .EXAMPLE
    Add-Table 'WithTime' { Time 'CreatedAt' -Sparse }

    Demonstrate show to create a nullable, sparse `time` column when adding a new table.

    .EXAMPLE
    Add-Table 'WithTime' { Time 'CreatedAt' -NotNull -Default 'convert(`time`, getutcdate())' }
    
    Demonstrates how to create a `time` column with a default value, in this case the current time.  You alwyas use UTC, right?

    .EXAMPLE
    Add-Table 'WithTime' { Time 'CreatedAt' -NotNull -Description 'The `time` the record was created.' }

    Demonstrates how to create a `time` column with a description.
    #>
    [CmdletBinding(DefaultParameterSetName='Null')]
    param(
        [Parameter(Mandatory,Position=0)]
        # The column's name.
        [String]$Name,

        [Parameter(Position=1)]
        [Alias('Precision')]
        # The number of decimal digits for the fractional seconds. SQL Server's default is `7`, or 100 nanoseconds..
        [int]$Scale,

        [Parameter(Mandatory,ParameterSetName='NotNull')]
        # Don't allow `NULL` values in this column.
        [switch]$NotNull,

        [Parameter(ParameterSetName='Null')]
        # Store nulls as Sparse.
        [switch]$Sparse,

        # A SQL Server expression for the column's default value 
        [String]$Default,

        # The name of the default constraint for the column's default expression. Required if the Default parameter is given.
        [String]$DefaultConstraintName,
            
        # A description of the column.
        [String]$Description
    )

    $dataSize = $null
    if( $PSBoundParameters.ContainsKey('Scale') )
    {
        $dataSize = New-Object Rivet.Scale $Scale
    }
    
    $nullable = $PSCmdlet.ParameterSetName
    if( $nullable -eq 'Null' -and $Sparse )
    {
        $nullable = 'Sparse'
    }

    [Rivet.Column]::Time($Name, $dataSize, $nullable, $Default, $DefaultConstraintName, $Description)
}
    
Set-Alias -Name 'Time' -Value 'New-TimeColumn'