Function ChangeContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object[]]$content,

        [Parameter(Mandatory)]
        [int]$lineNo,

        [Parameter()]
        [String]$value
    )
    $lineNo-- # decrement the value by 1 (indexing from 0)

    $content[$lineNo] = $value

    return $content
}

Function Write-LocalizedDataStringToFileConsole {
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
        $RejectAll = $false;
        $ConfirmAll = $false;
        #Check if the file exists and create it
        if (Test-Path -Path $Destination -PathType Leaf ) {
            Write-Warning -Message "$Destination exists, Script will overwrite it."
        }
        else {
            New-Item -Path $Destination -ItemType File -Force 
        }
        $content = Get-Content -Path $Source # copy the contents of the source in the memory
        
        
        # Also if the LocalizedHashData not specified then read it
        if (-not $LocalizedHashData) {
            $LocalizedHashData = Get-LocalizedHashData -Path $Source
        }

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
                    $contentLine = $change.Key - 1
                    $oldLine = $content[$contentLine]
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
                       # continue using the next regex  
                    }
                    
                    if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Extent.text)'",
                                       "Change the Line no '$($change.Extent.StartLineNumber)'?",
                                       "Changing line" )) {
                      if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line no $($change.Extent.StartLineNumber)'' ?", 
                            "Changing line $($change.Extent.text) with '$newLine'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                            $content = ChangeContent -Content $Content -LineNo ($change.key) -value $newLine
                         #$newLine
                      }
                   }
                } # foreach regex 
            }
            else {
                # this change is for a double quoted string
                Write-Verbose -message "Processing the double quoted string"
                $regEx = [regex]::new('".*"')
                $contentLine = $change.Key - 1
                $oldLine = $content[$contentLine]
                if($prefix) {
                    $keyName = '$localizedData.{0}{1}' -f $prefix, $prefixCounter 
                    $newLine = $regex.Replace($oldLine, $keyName)
                    $prefixCounter++
                }
                else {
                    $newLine = $regex.Replace($oldLine, "`$localizedData.$($change.Key)")
                }
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


                #Start-Sleep -Seconds 3
                if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Extent.text)'",
                                       "Change the Line no '$($change.Extent.StartLineNumber)'?",
                                       "Changing line" )) {
                      if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line no $($change.Extent.StartLineNumber)'' ?", 
                            "Chaning line $($change.Extent.text) with '$newLine'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                            $content = ChangeContent -Content $Content -LineNo ($change.key) -value $newLine
                         #$newLine
                      }
                   }
            }
        }
    }
    END {
        # write the content to the file
        Set-Content -Path $destination -Value $Content
    }
}

