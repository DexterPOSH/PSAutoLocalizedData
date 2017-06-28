Function Write-VerboseLog {
    param($message)

    Write-Verbose -message "$(Get-Date) $message"
}
write-Verbose "This contains a $env:Computername"
Write-OutPut -InputObject "123"
Get-Process -Name 'notepad'
Write-Warning -message "This is a warning from $host"
    write-VerboseLog -Message "this should work too"
Write-VerboseLog -Message ($LocalizedData.UpdateNetwork -f 'Management') # should not touch
Write-Verbose -Message $('this is {0} network' -f 'management')
throw 'Give me some LocalizedData for this'
