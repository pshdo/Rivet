
function Invoke-WhiskeyRobocopy
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Source,

        [Parameter(Mandatory=$true)]
        [string]
        $Destination,

        [string[]]
        $WhiteList,

        [string[]]
        $Exclude,

        [string]
        $LogPath
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $numRobocopyThreads = Get-CimInstance -ClassName 'Win32_Processor' | Select-Object -ExpandProperty 'NumberOfLogicalProcessors' | Measure-Object -Sum | Select-Object -ExpandProperty 'Sum'
    $numRobocopyThreads *= 2

    $logParam = ''
    if ($LogPath)
    {
        $logParam = '/LOG:{0}' -f $LogPath
    }

    $excludeParam = $Exclude | ForEach-Object { '/XF' ; $_ ; '/XD' ; $_ }
    robocopy $Source $Destination '/PURGE' '/S' '/NP' '/R:0' '/NDL' '/NFL' '/NS' ('/MT:{0}' -f $numRobocopyThreads) $WhiteList $excludeParam $logParam
}