Function Get-LocalizedHashData {
    [CmdletBinding(DefaultParameterSetName='File')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        # Specify the file to be parsed.
		[Parameter(Mandatory,
                    ValueFromPipelineByPropertyName,
					ParameterSetName='File')]
        [String]$Path,
		
		# Pipe in the string content that needs to be processed.
		[Parameter(Mandatory,
            ValueFromPipeline,
			ParameterSetName='Content')]
        [String]$Content,

        # list of the Command names for which the Localized messages are to be displayed
        [Parameter()]
        [String[]]$CommandName=@('Write-Verbose', 'Write-Warning','Write-VerboseLog', 'throw'),

        # Use this as a default prefix for all the key names in the localized hash data
        [Parameter()]
        [string]$Prefix

    )
    BEGIN {
        $useFulAST = @()
        $localizedDataHash = [ordered]@{}

    }
    PROCESS {
		Switch -exact ($PSCmdlet.ParameterSetName) {
			'File' {
                $path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($path)
				$AST = GetASTFromFile -Path $Path
				break
			}
			'Content' {
				$AST = GetASTFromInput -Content $Content
				break
			}
		}
        
        if ($AST) {
            $CommandAST = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst]}, $true) 
            if ($CommandName -contains 'throw') {
                $useFulAST += $ast.FindAll({$args[0] -is [System.Management.Automation.Language.ThrowStatementAst]}, $true )
            }
        }
        else {
            throw 'AST empty'
        }
        
        # filter out only the AST elements which contain the Command name
        $useFulAST += foreach ($command in $CommandAST) {
                        if ($command.GetCommandName() -in $CommandName) {
                            $command
                        }
                    }
        Remove-Variable -Name AST

        foreach($Command in $useFulAST){
            # Single Quoted Strings logic
            if(($Command.CommandElements | Where -Property StringConstantType -eq SingleQuoted) -or 
                ($command.Pipeline.PipelineElements.expression | Where -Property StringConstantType -eq SingleQuoted ) # throw statment
                ) {
             
                $key, $value = ParseASTForSingleQuotedString -CommandAST $command
                $localizedDataHash.Add($key, $value)
                continue # continue after this, as there is no point in looking for Double quoted strings.
            }

            # Double Quoted strings logic
            if (($doubleQuotedElement =$Command.CommandElements | Where -Property StringConstantType -eq DoubleQuoted) -or 
                 ($doubleQuotedElement = $command.Pipeline.PipelineElements.expression  | Where -Property StringConstantType -eq DoubleQuoted) # throw statement
                 ) {
                $key, $value = ParseASTForDoubleQuotedString -CommandAST $command
                $localizedDataHash.Add($key, $value)
                continue
            }
        } # end foreach($Command in $useFulAST)

    } # end PROCESS

    END {
        Write-Output -InputObject $localizedDataHash
    }
} #end Function