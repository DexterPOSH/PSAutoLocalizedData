#region Change the file

Function Write-LocalizedDataStringToFileISE {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        # Specify the source file which contains all the un localized messages
        [Parameter(Mandatory)]
        [String]$Source,

        # Path of the destination file which will contain only the locaized messages        
        [Parameter(Mandatory)]
        [String]$Destination,
        
        # pass the output of the Get-LocalizedHashData function here
        [Parameter(ValueFromPipeline)]
        [System.Collections.Specialized.OrderedDictionary]$LocalizedHashData,

                # Use this as a default prefix for all the key names in the localized hash data
        [Parameter()]
        [string]$Prefix
    )
    BEGIN {
        if (-not $host.name.Contains('ISE')) {
            Write-Error -Message 'Run the Script from the ISE'
        }
        
        #Check if the file exists and create it
        if (Test-Path -Path $Destination -PathType Leaf ) {
            Write-Warning -Message "$Destination exists, Script will overwrite it."
        }
        else {
            New-Item -Path $Destination -ItemType File -Force 
        }
        Set-Content -Path $Destination -Value (Get-Content -Path $Source) # copy the contents of the source to destination to begin with
        
        
        # Also if the LocalizedHashData not specified then read it
        if (-not $LocalizedHashData) {
            $LocalizedHashData = Get-LocalizedHashData -Path $Destination
        }

        # open the File in ISE
        $Destination = Resolve-Path -Path $Destination | select -ExpandProperty Path
        $psISE.CurrentPowerShellTab.Files.Add($Destination) > $null
        $file = $psISE.CurrentPowerShellTab.Files | where -Property FullPath -eq $Destination
        $RejectAll = $false;
        $ConfirmAll = $false;
        if ($prefix) {
            $prefixCounter = 1
        }
    }
    PROCESS {

        Foreach ($change in $($LocalizedHashData.GetEnumerator())){
            Write-Verbose -message "Processing $($change.Value)"
            if ($change.Value.Count -eq 1) {
                Write-Verbose -message "Processing the single quoted string"
                # this change is for a single quoted string or double quoted string with no nested expressions
                $regEx1 = [regex]::new("'.*'")
                $regEx2 = [regex]::new('".*"')
                foreach ($regEx in ($regEx1, $regEx2)) {
                    $File.Editor.SetCaretPosition($($change.Name),1)
                    $File.Editor.SelectCaretLine()
                    $oldLine = $file.Editor.SelectedText

                    if ($regEx.IsMatch($oldLine)) {
                        if($prefix) {
                            $keyName = '$localizedData.{0}{1}' -f $prefix, $prefixCounter 
                            $newLine = $regex.Replace($oldLine, $keyName)
                            $prefixCounter++
                        }
                        else {
                            $newLine = $regex.Replace($oldLine, "`$localizedData.$($change.Key)")
                        }
                    }
                    else {
                        continue # continue using the next regex
                    }
                    
                    #Start-Sleep -Seconds 3
                    if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Name)'",
                                       "Change the Line '$($file.Name)'?",
                                       "Changing File" )) {
                      if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line '$($change.Name)' ?", 
                            "Chaning line $($change.Name) with '$($change.Value[0])'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                         $file.Editor.InsertText($newLine)
                         #$newLine
                      }
                   }
                            
                }
            }
            else {
                # this change is for a double quoted string
                Write-Verbose -message "Processing the double quoted string"
                $regEx = [regex]::new('".*"')
                $file.Editor.SetCaretPosition($($change.Name),1)
                $File.Editor.SelectCaretLine()
                $oldLine = $file.Editor.SelectedText
                $newLine = $regex.Replace($oldLine, "`$localizedData.$($change.Key)")
                for ($i=1; $i -lt $($change.Value.Count); $i++){ 
                    if(-not $newLine.Contains('-f')){
                        $newLine += ' -f '
                    }
                    if(($i+1) -eq ($change.Value.Count)) {
                        # This is the last element, no comma after this
                        $newLine += "$($change.Value[$i])"
                    }
                    else {
                        $newLine += "$($change.Value[$i]) ,"
                    }
                }

                if($prefix) {
                    $keyName = '$localizedData.{0}{1}' -f $prefix, $prefixCounter 
                    $newLine = $regex.Replace($oldLine, $keyName)
                    $prefixCounter++
                }
                else {
                    $newLine = $regex.Replace($oldLine, "`$localizedData.$($change.Key)")
                }
                #Start-Sleep -Seconds 3
                if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Name)'",
                                       "Change the Line '$($file.Name)'?",
                                       "Changing File" )) {
                    if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line '$($change.Name)' ?", 
                            "Chaning line $($change.Name) with '$($change.Value[0])'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                        $file.Editor.InsertText($newLine)
                        #$newLine
                    }
                }
            }
        } 
        
    } # end Process
    END {

    }
}