
function Export-Migration
{
    <#
    .SYNOPSIS
    Exports objects from a database as Rivet migrations.

    .DESCRIPTION
    The `Export-Migration` function exports database objects, schemas, and data types as a Rivet migration. By default, it exports *all* non-system, non-Rivet objects, data types, and schemas. You can filter specific objects by passing their full name to the `Include` parameter. Wildcards are supported. Objects are matched on their schema *and* name.

    Extended properties are *not* exported, except table and column descriptions.

    .EXAMPLE
    Export-Migration -SqlServerName 'some\instance' -Database 'database'

    Demonstrates how to export an entire database.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        # The connection string for the database to connect to.
        $SqlServerName,

        [Parameter(Mandatory)]
        [string]
        # The database to connect to.
        $Database,

        [string[]]
        # The names of the objects to export. Must include the schema if exporting a specific object. Wildcards supported.
        #
        # The default behavior is to export all non-system objects.
        $Include
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    $pops = New-Object 'Collections.Generic.Stack[string]'
    $exportedObjects = @{ }
    $exportedSchemas = @{ 
                            'dbo' = $true;
                            'guest' = $true;
                            'sys' = $true;
                            'INFORMATION_SCHEMA' = $true;
                        }
    $exportedTypes = @{ }
    $exportedIndexes = @{ }

    function ConvertTo-SchemaParameter
    {
        param(
            [string]
            $SchemaName
        )

        $parameter = ''
        if( $SchemaName -and $SchemaName -ne 'dbo' )
        {
            $parameter = ' -SchemaName ''{0}''' -f $SchemaName
        }
        return $parameter
    }

    function Get-ChildObject
    {
        param(
            [Parameter(Mandatory)]
            [int]
            $TableID,

            [Parameter(Mandatory)]
            [string]
            $Type
        )

        $query = 'select sys.objects.name as object_name, * from sys.objects where parent_object_id = @table_id and type = @type'
        return Invoke-Query -Query $query -Parameter @{ '@table_id' = $TableID; '@type' = $Type }
    }

    function Export-CheckConstraint
    {
        param(
            [Parameter(Mandatory,ParameterSetName='ByObject')]
            [object]
            $Object,

            [Parameter(Mandatory,ParameterSetName='ByTableID')]
            [int]
            $TableID,

            [Switch]
            $SkipPop
        )

        if( $TableID )
        {
            $Object = Get-ChildObject -TableID $TableID -Type 'C'
            if( -not $Object )
            {
                return
            }
        }

        foreach( $constraintObject in $Object )
        {
            if( $exportedObjects.ContainsKey($Object.object_id) )
            {
                continue
            }

            $query = 'select 
    schema_name(sys.tables.schema_id) as schema_name, sys.tables.name as table_name, sys.check_constraints.name as name, definition 
from 
    sys.check_constraints 
    join 
    sys.tables 
        on sys.check_constraints.parent_object_id = sys.tables.object_id
where
    sys.check_constraints.object_id = @object_id'
            $constraint = Invoke-Query -Query $query -Parameter @{ '@object_id' = $constraintObject.object_id }
            $schema = ConvertTo-SchemaParameter -SchemaName $constraint.schema_name
            '    Add-CheckConstraint{0} -TableName ''{1}'' -Name ''{2}'' -Expression ''{3}''' -f $schema,$constraint.table_name,$constraint.name,$constraint.definition
            if( -not $SkipPop )
            {
                Push-PopOperation ('    Remove-CheckConstraint{0} -TableName ''{1}'' -Name ''{2}''' -f $schema,$constraint.table_name,$constraint.name)
            }
            $exportedObjects[$constraintObject.object_id] = $true
        }
    }

    function Export-DataType
    {
        [CmdletBinding(DefaultParameterSetName='All')]
        param(
            [Parameter(Mandatory,ParameterSetName='ByDataType')]
            [object]
            $Object
        )

        if( $PSCmdlet.ParameterSetName -eq 'All' )
        {
            $query = 'select sys.types.name as type_name, systype.name as from_type_name, schema_name(sys.types.schema_id) as schema_name, * from sys.types join sys.types systype on sys.types.system_type_id = systype.system_type_id and sys.types.system_type_id = systype.user_type_id where sys.types.is_user_defined = 1 and sys.types.is_table_type = 0'
            foreach( $object in (Invoke-Query -Query $query) )
            {
                if( (Test-SkipObject -SchemaName $object.schema_name -Name $object.type_name) )
                {
                    continue
                }
                Export-DataType -Object $object
            }
            return
        }

        if( $exportedTypes.ContainsKey($Object.type_name) )
        {
            Write-Debug ('Skipping   ALREADY EXPORTED  {0}' -f $Object.type_name)
            continue
        }
        
        Export-Schema -Name $Object.schema_name

        $schema = ConvertTo-SchemaParameter -SchemaName $Object.schema_name
        '    Add-DataType{0} -Name ''{1}'' -From ''{2}''' -F $schema,$Object.type_name,$Object.from_type_name
        $pops.Push(('Remove-DataType{0} -Name ''{1}''' -f $schema,$Object.type_name))
        $exportedtypes[$object.type_name] = $true
    }

    function Export-DefaultConstraint
    {
        param(
            [Parameter(Mandatory,ParameterSetName='ByObject')]
            [object]
            $Object,

            [Parameter(Mandatory,ParameterSetName='ByTableID')]
            [int]
            $TableID,

            [Switch]
            $SkipPop
        )

        if( $TableID )
        {
            $Object = Get-ChildObject -TableID $TableID -Type 'D'
            if( -not $Object )
            {
                return
            }
        }

        foreach( $constraintObject in $Object )
        {
            if( $exportedObjects.ContainsKey($Object.object_id) )
            {
                continue
            }

            $query = '
select 
    schema_name(sys.tables.schema_id) as schema_name, sys.tables.name as table_name, sys.default_constraints.name as name, sys.columns.name as column_name, definition 
from 
    sys.objects 
    join sys.tables 
        on sys.objects.parent_object_id = sys.tables.object_id
    join sys.schemas
        on sys.schemas.schema_id = sys.tables.schema_id
    join sys.default_constraints
        on sys.default_constraints.object_id = sys.objects.object_id
	join sys.columns 
		on sys.columns.object_id = sys.default_constraints.parent_object_id
		and sys.columns.column_id = sys.default_constraints.parent_column_id
where
    sys.default_constraints.object_id = @object_id'
            $constraint = Invoke-Query -Query $query -Parameter @{ '@object_id' = $constraintObject.object_id }
            $schema = ConvertTo-SchemaParameter -SchemaName $constraint.schema_name
            '    Add-DefaultConstraint{0} -TableName ''{1}'' -ColumnName ''{2}'' -Name ''{3}'' -Expression ''{4}''' -f $schema,$constraint.table_name,$constraint.column_name,$constraint.name,$constraint.definition
            if( -not $SkipPop )
            {
                Push-PopOperation ('    Remove-DefaultConstraint{0} -TableName ''{1}'' -Name ''{2}''' -f $schema,$constraint.table_name,$constraint.name)
            }
            $exportedObjects[$constraintObject.object_id] = $true
        }
    }

    function Export-Index
    {
        [CmdletBinding(DefaultParameterSetName='All')]
        param(
            [Parameter(Mandatory,ParameterSetName='ByIndex')]
            [object]
            $Object,

            [Parameter(Mandatory,ParameterSetName='ByTable')]
            [int]
            $TableID,

            [Switch]
            $SkipPop
        )

        $query = '
select 
    sys.tables.name as table_name, 
    schema_name(sys.tables.schema_id) as schema_name, 
    sys.indexes.* 
from 
    sys.indexes 
        join 
    sys.tables 
            on sys.indexes.object_id = sys.tables.object_id 
where 
    is_primary_key = 0 and 
    sys.indexes.type != 0 and
    sys.indexes.is_unique_constraint != 1
'
        if( $PSCmdlet.ParameterSetName -eq 'All' )
        {
            foreach( $object in (Invoke-Query -Query $query) )
            {
                if( (Test-SkipObject -SchemaName $Object.schema_name -Name $Object.name) )
                {
                    continue
                }

                Export-Index -Object $object -SkipPop:$SkipPop
                ''
            }
            return
        }
        elseif( $PSCmdlet.ParameterSetName -eq 'ByTable' )
        {
            $query = '{0} and sys.indexes.object_id = @object_id' -f $query
            foreach( $object in (Invoke-Query -Query $query -Parameter @{ '@object_id' = $TableID }) )
            {
                Export-Index -Object $object -SkipPop:$SkipPop
            }
            return
        }

        $indexKey = '{0}_{1}' -f $Object.object_id,$Object.index_id
        if( $exportedIndexes.ContainsKey($indexKey) )
        {
            return
        }

        $query = '
SELECT 
    sys.columns.name as column_name,
    sys.indexes.name as index_name,
	* 
FROM 
	sys.indexes 
		join 
	sys.index_columns 
			on sys.indexes.object_id = sys.index_columns.object_id 
			and sys.indexes.index_id = sys.index_columns.index_id 
		join
	sys.columns
			on sys.indexes.object_id = sys.columns.object_id
			and sys.index_columns.column_id = sys.columns.column_id
where 
    sys.indexes.object_id = @object_id and
    sys.indexes.index_id = @index_id
'
        $unique = ''
        if( $Object.is_unique )
        {
            $unique = ' -Unique'
        }
        $clustered = ''
        if( $Object.type_desc -eq 'CLUSTERED' )
        {
            $clustered = ' -Clustered'
        }
        $where = ''
        if( $Object.has_filter )
        {
            $where = ' -Where ''{0}''' -f $Object.filter_definition
        }
        $columns = Invoke-Query -Query $query -Parameter @{ '@object_id' = $Object.object_id ; '@index_id' = $Object.index_id }
        $columnNames = $columns | Select-Object -ExpandProperty 'column_name'
        $schema = ConvertTo-SchemaParameter -SchemaName $Object.schema_name
        '    Add-Index{0} -TableName ''{1}'' -ColumnName ''{2}'' -Name ''{3}''{4}{5}{6}' -f $schema,$Object.table_name,($columnNames -join ''','''),$Object.name,$clustered,$unique,$where
        if( -not $SkipPop )
        {
            Push-PopOperation ('Remove-Index{0} -TableName ''{1}'' -Name ''{2}''' -f $schema,$Object.table_name,$Object.name)
        }
        $exportedIndexes[$indexKey] = $true
    }

    function Export-PrimaryKey
    {
        param(
            [Parameter(Mandatory,ParameterSetName='ByObject')]
            [object]
            $Object,

            [Parameter(Mandatory,ParameterSetName='ByTableID')]
            [int]
            $TableID,

            [Switch]
            $SkipPop
        )

        if( $TableID )
        {
            $Object = Get-ChildObject -TableID $TableID -Type 'PK'
            if( -not $Object )
            {
                return
            }
        }

        if( $exportedObjects.ContainsKey($Object.object_id) )
        {
            return
        }

        $query = 'select 
	sys.schemas.name as schema_name, sys.tables.name as table_name, sys.columns.name as column_name
from 
    sys.objects 
    join sys.tables 
        on sys.objects.parent_object_id = sys.tables.object_id
    join sys.schemas
        on sys.schemas.schema_id = sys.tables.schema_id
    join sys.indexes
        on sys.indexes.object_id = sys.tables.object_id
	join sys.index_columns 
		on sys.indexes.object_id = sys.index_columns.object_id 
        and sys.indexes.index_id = sys.index_columns.index_id
	join sys.columns 
		on sys.indexes.object_id = sys.columns.object_id 
		and sys.columns.column_id = sys.index_columns.column_id
where
    sys.objects.object_id = @object_id and
	sys.objects.type = ''PK'' and
	sys.indexes.is_primary_key = 1'
        $columns = Invoke-Query -Query $query -Parameter @{ '@object_id' = $Object.object_id }
        $primaryKey = $columns | Select-Object -First 1
        if( $primaryKey )
        {
            $schema = ConvertTo-SchemaParameter -SchemaName $primaryKey.schema_name
            $columnNames = $columns | Select-Object -ExpandProperty 'column_name'
            '    Add-PrimaryKey{0} -TableName ''{1}'' -ColumnName ''{2}'' -Name ''{3}''' -f $schema,$primaryKey.table_name,($columnNames -join ''','''),$object.object_name
            if( -not $SkipPop )
            {
                Push-PopOperation ('Remove-PrimaryKey{0} -TableName ''{1}'' -Name ''{2}''' -f $schema,$primaryKey.table_name,$object.object_name)
            }
            $exportedObjects[$Object.object_id] = $true
        }
    }

    function Export-Schema
    {
        param(
            [Parameter(Mandatory)]
            [string]
            $Name
        )

        if( $exportedSchemas.ContainsKey($Name) )
        {
            return
        }

        $query = 'select sys.schemas.name as name, sys.sysusers.name as owner from sys.schemas join sys.sysusers on sys.schemas.principal_id = sys.sysusers.uid where sys.schemas.name = @schema_name'
        $schema = Invoke-Query -Query $query -Parameter @{ '@schema_name' = $Name }
        if( $schema )
        {
            '    Add-Schema -Name ''{0}'' -Owner ''{1}''' -f $schema.name,$schema.owner
            ''
            $exportedSchemas[$schema.name] = $true
            Push-PopOperation ('Remove-Schema -Name ''{0}''' -f $schema.name)
        }
    }

    function Export-StoredProcedure
    {
        param(
            [Parameter(Mandatory)]
            [object]
            $Object
        )

        $query = 'select definition from sys.sql_modules where object_id = @object_id'
        $definition = Invoke-Query -Query $query -Parameter @{ '@object_id' = $Object.object_id } -AsScalar

        $schema = ConvertTo-SchemaParameter -SchemaName $Object.schema_name
        $createPreambleRegex = '^CREATE\s+procedure\s+\[{0}\]\.\[{1}\]\s+' -f [regex]::Escape($Object.schema_name),[regex]::Escape($Object.object_name)
        if( $definition -match $createPreambleRegex )
        {
            $definition = $definition -replace $createPreambleRegex,''
            '    Add-StoredProcedure{0} -Name ''{1}'' -Definition @''{2}{3}{2}''@' -f $schema,$Object.object_name,[Environment]::NewLine,$definition
        }
        else
        {
            '    Invoke-Ddl -Query @''{0}{1}{0}''@' -f [Environment]::NewLine,$definition
        }
        Push-PopOperation ('Remove-StoredProcedure{0} -Name ''{1}''' -f $schema,$Object.object_name)
    }

    function Export-Table
    {
        param(
            [Parameter(Mandatory)]
            [object]
            $Object
        )

        $schema = ConvertTo-SchemaParameter -SchemaName $Object.schema_name

        Push-PopOperation ('Remove-Table{0} -Name ''{1}''' -f $schema,$object.object_name)

        $description = $Object.description
        if( $description )
        {
            $description = ' -Description ''{0}''' -f $description
        }

        '    Add-Table{0} -Name ''{1}''{2} -Column {{' -f $schema,$object.object_name,$description

        $query = '
select 
    sys.columns.object_id,
    sys.columns.is_nullable,
	sys.types.name as type_name, 
	sys.columns.name as column_name, 
	sys.types.collation_name as type_collation_name, 
	sys.columns.max_length as column_max_length, 
	sys.extended_properties.value as description,
    sys.columns.is_identity,
    sys.identity_columns.increment_value,
    sys.identity_columns.seed_value,
    sys.columns.precision,
    sys.columns.scale,
    sys.types.precision as default_precision,
    sys.types.scale as default_scale,
    sys.columns.is_sparse,
    sys.columns.collation_name,
    serverproperty(''collation'') as default_collation_name,
    sys.columns.is_rowguidcol
from 
	sys.columns 
		inner join 
	sys.types 
			on columns.user_type_id = sys.types.user_type_id  
		left join
	sys.extended_properties
			on sys.columns.object_id = sys.extended_properties.major_id
			and sys.columns.column_id = sys.extended_properties.minor_id
			and sys.extended_properties.name = ''MS_Description''
        left join
    sys.identity_columns
            on sys.columns.object_id = sys.identity_columns.object_id
            and sys.columns.column_id = sys.identity_columns.column_id
where 
    sys.columns.object_id = @object_id'
        foreach( $column in (Invoke-Query -Query $query -Parameter @{ '@object_id' = $object.object_id }) )
        {
            $notNull = ''
            $parameters = & {
                if( $column.type_collation_name )
                {
                    $maxLength = $column.column_max_length
                    if( $column.type_name -like 'n*' )
                    {
                        $maxLength = $maxLength / 2
                    }
                    '-Size {0}' -f $maxLength
                    if( $column.collation_name -ne $column.default_collation_name )
                    {
                        '-Collation'
                        '''{0}''' -f $column.collation_name
                    }
                }
                if( $column.is_rowguidcol )
                {
                    '-RowGuidCol'
                }
                if( $column.precision -ne $column.default_precision )
                {
                    '-Precision'
                    $column.precision
                }
                if( $column.scale -ne $column.default_scale )
                {
                    '-Scale'
                    $column.scale
                }
                if( $column.is_identity )
                {
                    '-Identity'
                    if( $column.seed_value -ne 1 )
                    {
                        '-Seed'
                        $column.seed_value
                    }
                    if( $column.increment_value -ne 1 )
                    {
                        '-Increment'
                        $column.increment_value
                    }
                }
                if( -not $column.is_nullable )
                {
                    if( -not $column.is_identity )
                    {
                        '-NotNull'
                    }
                }
                if( $column.is_sparse )
                {
                    '-Sparse'
                }
                if( $column.description )
                {
                    '-Description ''{0}''' -f $column.description
                }
            }
            if( $parameters )
            {
                $parameters = $parameters -join ' '
                $parameters = ' {0}' -f $parameters
            }
            '        {0} ''{1}''{2}' -f $column.type_name,$column.column_name,$parameters
        }

        '    }'

        Export-PrimaryKey -TableID $Object.object_id -SkipPop
        Export-DefaultConstraint -TableID $Object.object_id -SkipPop
        Export-CheckConstraint -TableID $Object.object_id -SkipPop
        Export-Index -TableID $Object.object_id -SkipPop
        Export-UniqueKey -TableID $Object.object_id -SkipPop
    }

    function Export-UniqueKey
    {
        param(
            [Parameter(Mandatory,ParameterSetName='ByKey')]
            [object]
            $Object,

            [Parameter(Mandatory,ParameterSetName='ForTable')]
            [int]
            $TableID,

            [Switch]
            $SkipPop
        )

        if( $PSCmdlet.ParameterSetName -eq 'ForTable' )
        {
            $query = '
select
    sys.key_constraints.name,
    schema_name(sys.key_constraints.schema_id) as schema_name,
    sys.key_constraints.object_id,
    sys.tables.name as parent_object_name
from
    sys.key_constraints
        join
    sys.tables
            on sys.key_constraints.parent_object_id = sys.tables.object_id
where
    sys.key_constraints.parent_object_id = @table_id
'
            foreach( $object in (Invoke-Query -Query $query -Parameter @{ '@table_id' = $TableID }) )
            {
                Export-UniqueKey -Object $object -SkipPop:$SkipPop
            }
            return
        }

        if( $exportedObjects.ContainsKey($Object.object_id) )
        {
            return
        }

        $query = '
select 
    sys.columns.name,
    sys.indexes.type_desc
from 
	sys.key_constraints 
		join
	sys.indexes
			on sys.key_constraints.parent_object_id = sys.indexes.object_id
			and sys.key_constraints.unique_index_id = sys.indexes.index_id
		join 
	sys.index_columns 
			on sys.indexes.object_id = sys.index_columns.object_id 
			and sys.indexes.index_id = sys.index_columns.index_id 
		join
	sys.columns
			on sys.indexes.object_id = sys.columns.object_id
			and sys.index_columns.column_id = sys.columns.column_id
where 
    sys.key_constraints.object_id = @object_id
'
        $columns = Invoke-Query -Query $query -Parameter @{ '@object_id' = $Object.object_id }
        $columnNames = $columns | Select-Object -ExpandProperty 'name'
        $clustered = ''
        if( ($columns | Select-Object -First 1 | Select-Object -ExpandProperty 'type_desc') -eq 'CLUSTERED' )
        {
            $clustered = ' -Clustered'
        }
        $schema = ConvertTo-SchemaParameter -SchemaName $Object.schema_name
        '    Add-UniqueKey{0} -TableName ''{1}'' -ColumnName ''{2}''{3} -Name ''{4}''' -f $schema,$Object.parent_object_name,($columnNames -join ''','''),$clustered,$Object.name
        Push-PopOperation ('Remove-UniqueKey{0} -TableName ''{1}'' -Name ''{2}''' -f $schema,$Object.parent_object_name,$Object.name)
        $exportedObjects[$Object.object_id] = $true
    }

    function Export-View
    {
        param(
            [Parameter(Mandatory)]
            [object]
            $Object
        )

        $schema = ConvertTo-SchemaParameter -SchemaName $object.schema_name
        $query = 'select definition from sys.sql_modules where object_id = @view_id'
        $view = Invoke-Query -Query $query -Parameter @{ '@view_id' = $Object.object_id } -AsScalar
        $createPreambleRegex = '^CREATE\s+view\s+\[{0}\]\.\[{1}\]\s+' -f [regex]::Escape($Object.schema_name),[regex]::Escape($Object.name)
        if( $view -match $createPreambleRegex )
        {
            $view = $view -replace $createPreambleRegex,''
            '    Add-View{0} -Name ''{1}'' -Definition @''{2}{3}{2}''@' -f $schema,$Object.name,[Environment]::NewLine,$view
        }
        else
        {
            '    Invoke-Ddl -Query @''{0}{1}{0}''@' -f [Environment]::NewLine,$view
        }
        Push-PopOperation ('Remove-View{0} -Name ''{1}''' -f $schema,$Object.name)
    }

    function Push-PopOperation
    {
        param(
            [Parameter(Mandatory)]
            $InputObject
        )

        if( -not ($pops | Where-Object { $_ -eq $InputObject }) )
        {
            $pops.Push($InputObject)
        }
    }

    function Test-SkipObject
    {
        param(
            [Parameter(Mandatory)]
            [string]
            $SchemaName,

            [Parameter(Mandatory)]
            [string]
            $Name
        )

        if( -not $Include )
        {
            return $false
        }

        $fullName = '{0}.{1}' -f $SchemaName,$Name
        foreach( $filter in $Include )
        {
            if( $fullName -like $filter )
            {
                return $false
            }
        }

        Write-Debug ('Skipping   NOT SELECTED      {0}' -f $fullName)
        return $true
    }

    Connect-Database -SqlServerName $SqlServerName -Database $Database -ErrorAction Stop | Out-Null
    try
    {
        'function Push-Migration'
        '{'

            Export-DataType

            $query = '
            select 
                sys.schemas.name as schema_name, 
                sys.objects.name as object_name, 
                sys.objects.name as name,
                sys.schemas.name + ''.'' + sys.objects.name as full_name, 
                sys.extended_properties.value as description,
                parent_objects.name as parent_object_name,
                sys.objects.object_id as object_id,
                sys.objects.type,
                sys.objects.type_desc,
                sys.objects.parent_object_id
            from 
                sys.objects 
                    join 
                sys.schemas 
                        on sys.objects.schema_id = sys.schemas.schema_id 
                    left join
                sys.extended_properties
                        on sys.objects.object_id = sys.extended_properties.major_id 
                        and sys.extended_properties.minor_id = 0
                        and sys.extended_properties.name = ''MS_Description''
                    left join
                sys.objects parent_objects
                    on sys.objects.parent_object_id = parent_objects.object_id
            where 
                sys.objects.is_ms_shipped = 0'
            foreach( $object in (Invoke-Query -Query $query) )
            {
                if( $exportedObjects.ContainsKey($object.object_id) )
                {
                    Write-Debug ('Skipping   ALREADY EXPORTED  {0}' -f $object.full_name)
                    continue
                }

                if( (Test-SkipObject -SchemaName $object.schema_name -Name $object.object_name) )
                {
                    continue
                }

                if( $object.schema_name -eq 'rivet' )
                {
                    continue
                }

                Export-Schema -Name $object.schema_name

                Write-Verbose ('Exporting  {0}' -f $object.full_name)
                switch ($object.type_desc)
                {
                    'CHECK_CONSTRAINT'
                    {
                        Export-CheckConstraint -Object $object
                    }
                    'DEFAULT_CONSTRAINT'
                    {
                        Export-DefaultConstraint -Object $object
                    }
                    'PRIMARY_KEY_CONSTRAINT'
                    {
                        Export-PrimaryKey -Object $object
                    }
                    'SQL_STORED_PROCEDURE'
                    {
                        Export-StoredProcedure -Object $object
                    }
                    'UNIQUE_CONSTRAINT'
                    {
                        Export-UniqueKey -Object $object
                    }
                    'USER_TABLE'
                    {
                        Export-Table -Object $object
                    }
                    'VIEW'
                    {
                        Export-View -Object $object
                    }
                    default
                    {
                        Write-Error -Message ('Unable to export object "{0}": unsupported object type "{1}".' -f $object.full_name,$object.type_desc)
                    }
                }
                $exportedObjects[$object.object_id] = $true
                ''
            }

            Export-Index
        '}'
        ''
        'function Pop-Migration'
        '{'
            $pops | ForEach-Object { '    {0}' -f $_ }
        '}'
    }
    finally
    {
        Disconnect-Database
    }
}
