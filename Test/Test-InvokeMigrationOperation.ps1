function Setup
{
    & (Join-Path -Path $PSScriptRoot -ChildPath 'RivetTest\Import-RivetTest.ps1' -Resolve) -DatabaseName 'AddAdminColumnPlugin' 
    $tempPluginsPath = New-TempDir -Prefix 'AddAdminColumnPlugin'
    $pluginPath = Join-Path -Path $TestDir -ChildPath '..\Rivet\Extras\*-MigrationOperation.ps1' -Resolve
    Copy-Item -Path $pluginPath -Destination $tempPluginsPath
    Start-RivetTest -PluginPath $tempPluginsPath
}

function TearDown
{
    Stop-RivetTest
}

function Test-ShouldRunPlugins
{
    @'
function Push-Migration
{
    Add-Schema 'fubar'
    Add-Table -SchemaName 'fubar' Foobar -Description 'Test' {
        BigInt ID -Description 'Test'
    }
}

function Pop-Migration
{
    
}

'@ | New-Migration -Name 'CompleteAdminPlugin'

    Invoke-Rivet -Push 'CompleteAdminPlugin'

    Assert-Column -Name CreateDate -DataType smalldatetime -NotNull -TableName "Foobar" -SchemaName 'fubar'
    Assert-Column -Name LastUpdated -DataType datetime -NotNull -TableName "Foobar" -SchemaName 'fubar'
    Assert-Column -Name RowGuid -DataType uniqueidentifier -NotNull -RowGuidCol -TableName "Foobar" -SchemaName 'fubar'
    Assert-Column -Name SkipBit -DataType bit -TableName "Foobar" -SchemaName 'fubar'
    Assert-Index -TableName 'Foobar' -ColumnName 'rowguid' -Unique -SchemaName 'fubar'
    Assert-Trigger -Name 'trFoobar_Activity' -SchemaName 'fubar'
}

function Test-PluginsShouldSkipRowGuid
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        uniqueidentifier guid -RowGuidCol -Description 'Test'
    }
}

function Pop-Migration
{
    Remove-Table Foobar
}
'@ | New-Migration -Name 'SkipRowGuid'

    Invoke-Rivet -Push 'SkipRowGuid'

    Assert-Column -Name guid -DataType uniqueidentifier -RowGuidCol -TableName "Foobar"
    Assert-False (Test-Column -TableName 'Foobar' -Name 'rowguid')
}

function Test-ShouldRejectTriggersWithoutNotForReplication
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        int ID -Identity -Description 'Test'
    }
    
    $trigger = @"
ON [dbo].[Foobar]
FOR UPDATE
AS
    RETURN
"@

    Add-Trigger 'trFoobar_Nothing' -Definition $trigger
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue
    Assert-False (Test-Trigger -Name 'trFoobar_Nothing')
    Assert-Error 2 'not for replication'
}

function Test-ShouldRejectBigIntIdentities
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        bigint ID -Identity -Description 'Test'
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue
    Assert-Error -First 'can''t be identity columns'
}

function Test-ShouldRejectSmallIntIdentities
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        smallint ID -Identity -Description 'Test'
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue
    Assert-Error -First 'can''t be identity columns'
}

function Test-ShouldRejectTinyIntIdentities
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        tinyint ID -Identity -Description 'Test'
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue
    Assert-Error -First 'can''t be identity columns'
}

function Test-ShouldMakeIdentitiesNotForReplication
{
    @'
function Push-Migration
{
    Add-Table Foobar -Description 'Test' {
        int ID -Identity -Description 'Test'
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue

    Assert-Table 'Foobar'
    Assert-Column -TableName 'FooBar' -Name 'ID' -DataType 'int' -Seed 1 -Increment 1 -NotForReplication -NotNull
}

function Test-ShouldMakeForeignKeyNotForReplication
{
    @'
function Push-Migration
{
    Add-Table Foo -Description 'Test' {
        int ID -Identity -Description 'Test'
    }
    Add-PrimaryKey 'Foo' 'ID'

    Add-Table Bar -Description 'Test' {
        int ID -Identity -Description 'Test'
    }
    Add-PrimaryKey 'Bar' 'ID'

    Add-ForeignKey -TableName 'Foo' -ColumnName 'ID' -References 'Bar' -ReferencedColumn 'ID'
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations'

    Assert-Table 'Foo'
    Assert-Table 'Bar'
    Assert-ForeignKey -TableName 'Foo' -References 'Bar'  -NotForReplication
}

function Test-ShouldMakeCheckConstraintsNotForReplication
{
   @'
function Push-Migration
{
    Add-Table Foo -Description 'Test' {
        varchar Name -Size '50' -NotNull -Description 'Test'
    }

    Add-CheckConstraint 'Foo' 'CK_Foo_Name' -Expression 'Name = ''Bono'' or Name = ''The Edge'''
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations'

    Assert-Table 'Foo'
    Assert-CheckConstraint 'CK_Foo_Name' '([Name]=''Bono'' or [Name]=''The Edge'')' -NotForReplication
}

function Test-ShouldRequireDescriptionOnNewTables
{
   @'
function Push-Migration
{
    Add-Table Foo {
        varchar Name -Size '50' -NotNull -Description 'Test'
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue

    Assert-Error -First 'Foo.*-Description'

    Assert-False (Test-Table 'Foo')
    
}

function Test-ShouldRequireDescriptionOnNewTableColumns
{
   @'
function Push-Migration
{
    Add-Table Foo -Description 'Test' {
        varchar Name -Size '50' -NotNull
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue

    Assert-Error -First 'Name.*-Description'

    Assert-False (Test-Table 'Foo')
    
}

function Test-ShouldRequireDescriptionOnExistingTableNewColumns
{
   @'
function Push-Migration
{
    Add-Table Foo -Description 'Test' {
        varchar Name -Size '50' -NotNull -Description 'Test'
    }

    Update-Table Foo -AddColumn {
        varchar LastName -Size 100
    }
}

function Pop-Migration
{
}
'@ | New-Migration -Name 'ValidateMigrations'

    Invoke-Rivet -Push 'ValidateMigrations' -ErrorAction SilentlyContinue

    Assert-Error -First 'LastName.*-Description'

    Assert-False (Test-Table 'Foo')
    
}