$Name = 'Dexter'
write-Verbose "This contains a $env:Computername"
Write-OutPut -InputObject "123"
Get-Process -Name 'notepad'
Write-Warning -message "This is a warning from $host"
Write-Verbose -Message $('this is {0} network' -f 'management')
throw "name is $Name"