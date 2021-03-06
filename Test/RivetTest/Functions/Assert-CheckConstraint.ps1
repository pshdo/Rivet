
function Assert-CheckConstraint
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the constraint.
        $Name,

        [Switch]
        $NotForReplication,

        [Switch]
        $IsDisabled,

        [string]
        $Definition
    )

    $constraint = Get-CheckConstraint -Name $Name

    if( (Test-Pester) )
    {
        $constraint | Should -Not -BeNullOrEmpty -Because ('check constraint ''{0}'' not found' -f $Name)

        $constraint.is_not_for_replication | Should -Be $NotForReplication 

        if( $IsDisabled )
        {
            $constraint.is_disabled | Should -BeTrue
        }
        else
        {
            $constraint.is_disabled | Should -BeFalse
        }

        if( $PSBoundParameters.ContainsKey('Definition') )
        {
            $constraint.definition | Should -Be $Definition 
        }
    }
    else
    {
        Assert-NotNull $constraint ('check constraint ''{0}'' not found' -f $Name)

        Assert-Equal $NotForReplication $constraint.is_not_for_replication

        if( $IsDisabled )
        {
            Assert-True $constraint.is_disabled
        }
        else
        {
            Assert-False $constraint.is_disabled
        }

        if( $PSBoundParameters.ContainsKey('Definition') )
        {
            Assert-Equal $Definition $constraint.definition
        }
    }
}
