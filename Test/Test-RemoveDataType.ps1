function Setup
{
    & (Join-Path -Path $PSScriptRoot -ChildPath 'RivetTest\Import-RivetTest.ps1' -Resolve) -DatabaseName 'RemoveDataType' 
    Start-RivetTest
}

function TearDown
{
    Stop-RivetTest
}

function Test-ShouldRemoveDataTypeByTable
{
    # Yes.  Spaces in names so we check that the names get quoted.
    @'
function Push-Migration
{
    Add-DataType 'Users DT' -AsTable { varchar 'Name' 50 } -TableConstraint 'primary key'
}

function Pop-Migration
{
    Remove-DataType 'Users DT'    
}

'@ | New-Migration -Name 'ByTable'

    Invoke-Rivet -Push 'ByTable'

    $temp = Invoke-RivetTestQuery -Query 'select * from sys.table_types'
    Assert-NotNull $temp
    Assert-Equal $temp.name 'Users DT'

    Invoke-Rivet -Pop 1
    $temp = Invoke-RivetTestQuery -Query 'select * from sys.table_types'
    Assert-Null $temp
}