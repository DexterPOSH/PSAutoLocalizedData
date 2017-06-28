
Function Get-LocalizedHashData {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory,
                    ValueFromPipeline)]
        [String]$Path,

        # list of the Command names for which the Localized messages are to be displayed
        [Parameter()]
        [String[]]$CommandName=@('Write-Verbose', 'Write-Warning','Write-VerboseLog')

    )
    BEGIN {
        $useFulAST = @()
        $localizedDataHash = [ordered]@{}
    }
    PROCESS {
        
        $AST = [System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$Null)
        $CommandAST = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst]}, $true) 
        
        # filter out only the AST elements which contain the Command name
        $useFulAST = foreach ($command in $CommandAST) {
                        if ($command.GetCommandName() -in $CommandName) {
                            $command
                        }
                    }
        Remove-Variable -Name AST

        foreach($Command in $useFulAST){
            # Single Quoted Strings logic
            if($singleQuotedElement = $Command.CommandElements | Where -Property StringConstantType -eq SingleQuoted) {
                $newString = @()
                $newString += $singleQuotedElement.Value
                $lineNo = $singleQuotedElement.Extent.StartLineNumber
                $localizedDataHash.Add($lineNo, $newString)
                continue # continue after this, as there is no point in looking for Double quoted strings.
            }

            # Double Quoted strings logic
            if ($doubleQuotedElement =$Command.CommandElements | Where -Property StringConstantType -eq DoubleQuoted) {
                $lineNo = $doubleQuotedElement.Extent.StartLineNumber
                $newString = @()
                $newString += $doubleQuotedElement.Value
                
                # if the Double quoteed string has Nested expressions i.e. Variables or Subexpressions in it
                if($doubleQuotedElement.NestedExpressions){ 
                    for ( $i=0; $i -lt $($doubleQuotedElement.NestedExpressions.Count); $i++){
                        $nestedExpression = $doubleQuotedElement.NestedExpressions[$i]
                        if ($nestedExpression.VariablePath) {
                            $varInUse  = $nestedExpression.VariablePath.ToString()
                            $newString[0] = $newString[0].Replace($varInUse,"{$i}") # replace the Var Name with a subscript for the Format operator
                            #$newString[0] = $newString[0].Replace('$','') # replace the $ in the var name
                            $newString += "`$$varInUse" # add the var to the array
                        }
        
                        if ($nestedExpression.SubExpression) {
                            # put logic here to see if the subexpression has a variable
                            $SubExpInUse += $nestedExpression.SubExpression.Extent.Text
                            $newString[0] = $newString[0].Replace("`$($SubExpInUse)","{$i}") # replace the Var Name with a subscript for the Format operator
                                # replace the $ in the var name

                            $newString += "`$($SubExpInUse)"
                        }
                        $newString[0] = $newString[0].Replace('$','')
                    }
                }        
             $localizedDataHash.Add($lineNo, $newString)
            }
        } # end foreach($Command in $useFulAST)

    } # end PROCESS

    END {
        Write-Output -InputObject $localizedDataHash
    }
} #end Function

#region Generate & Display the String Data
Filter DisplayLocalizedStringData {
    param(
        [String]$Prefix
    )
    if ($Prefix) {
        # if prefix specified then use it in the Key names
        $counter = 1
        foreach ($enum in $PSItem.getEnumerator()){
            if ($enum.Value.Count -eq 1) {
                Write-Host -Object "$($Prefix + $counter)=$($enum.Value)"
            }
            else {
                Write-Host -Object "$($Prefix + $counter)=$($enum.Value[0])"
            }
            $counter++
        }
    }
    else {
        # prefix not specified use the line no
        foreach ($enum in $PSItem.getEnumerator()){
            if ($enum.Value.Count -eq 1) {
                Write-Host -Object "$($enum.key)=$($enum.Value)"
            }
            else {
                Write-Host -Object "$($enum.key)=$($enum.Value[0])"
            }
        }
    }
}

Filter GenerateLocalizedStringData {
    param(
        [String]$Prefix
    )
    if ($Prefix) {
        # if prefix specified then use it in the Key names
        $counter = 1
        foreach ($enum in $PSItem.getEnumerator()){
            if ($enum.Value.Count -eq 1) {
                Write-Output -InputObject "$($Prefix + $counter)=$($enum.Value)"
            }
            else {
                Write-Output -InputObject "$($Prefix + $counter)=$($enum.Value[0])"
            }
            $counter++
        }
    }
    else {
        # prefix not specified use the line no
        foreach ($enum in $PSItem.getEnumerator()){
            if ($enum.Value.Count -eq 1) {
                Write-Output -InputObject "$($enum.key)=$($enum.Value)"
            }
            else {
                Write-Output -InputObject "$($enum.key)=$($enum.Value[0])"
            }
        }
    }
}
#endregion

#region Change the file

Function Write-LocalizedDataStringToFile {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory,
                    ValueFromPipeline)]
        [System.Collections.Specialized.OrderedDictionary]$LocalizedHashData
    )
    BEGIN {
        if (-not $host.name.Contains('ISE')) {
            Write-Error -Message 'Run the Script from the ISE'
        }
        
        # open the File in ISE
        $psISE.CurrentPowerShellTab.Files.Add($Path) > $null
        $file = $psISE.CurrentPowerShellTab.Files | where -Property FullPath -eq $Path
        $RejectAll = $false;
        $ConfirmAll = $false;
    }
    PROCESS {

        Foreach ($change in $($LocalizedHashData.GetEnumerator())){
            Write-Verbose -message "Processing $($change.Value)"
            if ($change.Value.Count -eq 1) {
                Write-Verbose -message ""
                # this change is for a single quoted string or double quoted string with no nested expressions
                $regEx1 = [regex]::new("'.*'")
                $regEx2 = [regex]::new('".*"')
                foreach ($regEx in ($regEx1, $regEx2)) {
                    $File.Editor.SetCaretPosition($($change.Name),1)
                    $File.Editor.SelectCaretLine()
                    $oldLine = $file.Editor.SelectedText

                    if ($regEx.IsMatch($oldLine)) {
                        $newLine = $regex.Replace($oldLine, "`$localizedData.$($change.Key)")
                    }
                    else {
                        continue # continue using the next regex
                    }
        
                    Start-Sleep -Seconds 3
                    if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Name)'",
                                       "Change the Line '$($file.Name)'?",
                                       "Changing File" )) {
                      if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line '$($change.Name)' ?", 
                            "Chaning line $($change.Name) with '$($change.Value[0])'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                         $file.Editor.InsertText($newLine)
                      }
                   }
                            
                }
            }
            else {
                # this change is for a double quoted string
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
                Start-Sleep -Seconds 3
                if($PSCmdlet.ShouldProcess( "Change the Line '$($change.Name)'",
                                       "Change the Line '$($file.Name)'?",
                                       "Changing File" )) {
                    if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change line '$($change.Name)' ?", 
                            "Chaning line $($change.Name) with '$($change.Value[0])'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                        $file.Editor.InsertText($newLine)
                    }
                }
            }
        } 
        
    } # end Process
    END {

    }
}
#endregion Change the file

