
function Invoke-MigrationOperation
{
    <#
    .SYNOPSIS
    Runs the SQL created by a `Rivet.Migration` object.

    .DESCRIPTION
    All Rivet migrations are described by instances of `Rivet.Migration` objects.  These objects eventually make their way here, at which point they are converted to SQL, and executed.

    .EXAMPLE
    Invoke-Migration -Operation $operation

    This example demonstrates how to call `Invoke-Migration` with a migration object.
    #>
    [CmdletBinding(DefaultParameterSetName='AsReader')]
    param(
        [Alias('Migration')]
        [Parameter(Mandatory=$true)]
        [Rivet.Operations.Operation]
        # The migration object to invoke.
        $Operation,

        [Hashtable]
        # Any parameters to use in the query.
        $Parameter,
        
        [Parameter(Mandatory=$true,ParameterSetName='ExecuteScalar')]
        [Switch]
        $AsScalar,
        
        [Parameter(Mandatory=$true,ParameterSetName='ExecuteNonQuery')]
        [Switch]
        $NonQuery,
        
        [UInt32]
        # The time in seconds to wait for the command to execute. The default is 30 seconds.
        $CommandTimeout = 30
    )

    if( (Test-Path -Path 'function:Start-MigrationOperation') )
    {
        # Protect ourself from poorly written plug-ins that return things.
        $null = Start-MigrationOperation -Operation $Operation
    }

    $query = $Operation.ToQuery()

    Write-Verbose $query
    $cmd = New-Object 'Data.SqlClient.SqlCommand' ($query,$Connection,$Connection.Transaction)
    $cmd.CommandTimeout = $CommandTimeout

    if( $Parameter )
    {
        $Parameter.Keys | ForEach-Object { 
            $name = $_
            $value = $Parameter[$name]
            if( -not $name.StartsWith( '@' ) )
            {
                $name = '@{0}' -f $name
            }
            [void] $cmd.Parameters.AddWithValue( $name, $value )
       }
    }

    try
    {
        if( $pscmdlet.ParameterSetName -eq 'ExecuteNonQuery' )
        {
            $cmd.ExecuteNonQuery()
        }
        elseif( $pscmdlet.ParameterSetName -eq 'ExecuteScalar' )
        {
            $cmd.ExecuteScalar()
        }
        else
        {
            $cmdReader = $cmd.ExecuteReader()
            try
            {
                if( $cmdReader.HasRows )
                {                
                    while( $cmdReader.Read() )
                    {
                        $row = @{ }
                        for ($i= 0; $i -lt $cmdReader.FieldCount; $i++) 
                        { 
                            $name = $cmdReader.GetName( $i )
                            if( -not $name )
                            {
                                $name = 'Column{0}' -f $i
                            }
                            $value = $cmdReader.GetValue($i)
                            if( $cmdReader.IsDBNull($i) )
                            {
                                $value = $null
                            }
                            $row[$name] = $value
                        }
                        New-Object PsObject -Property $row
                    }
                }
            }
            finally
            {
                $cmdReader.Close()
            }
        }
    }
    catch
    {
        $errorMsg = 'Query failed: {0}' -f $query
        Write-RivetError -Message ('Migration {0} failed' -f $migrationInfo.FullName) -CategoryInfo $_.CategoryInfo.Category -ErrorID $_.FullyQualifiedErrorID -Exception $_.Exception -CallStack ($_.ScriptStackTrace) -Query $errorMsg
        throw (New-Object ApplicationException 'Migration failed.',$_.Exception)
    }
    finally
    {
        $cmd.Dispose()
    }

    if( (Test-Path -Path 'function:Complete-MigrationOperation') )
    {
        # Protect ourself from poorly written plug-ins that return things.
        $null = Complete-MigrationOperation -Operation $Operation
    }

}