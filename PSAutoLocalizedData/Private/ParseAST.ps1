Function ParseASTForSingleQuotedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast]$commandAST
    )

    Switch -Exact ($commandAST.GetType().FullName) {

        'System.Management.Automation.Language.CommandAst' {
            $singleQuotedElement = $commandAST.CommandElements | Where -Property StringConstantType -eq SingleQuoted
            break
        }
        'System.Management.Automation.Language.ThrowStatementAst' {
            $singleQuotedElement = $commandAST.Pipeline.PipelineElements.expression | Where -Property StringConstantType -eq SingleQuoted
            break
        }
        Default {
            throw 'Not supported AST element'
        }
    }
   
    $newString = @()
    $newString += $singleQuotedElement.Value
    $lineNo = $singleQuotedElement.Extent.StartLineNumber
    $lineNo, $newString # return the line no and the new string
}

Function ParseASTForDoubleQuotedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast]$commandAST
    )

    Switch -Exact ($commandAST.GetType().FullName) {

        'System.Management.Automation.Language.CommandAst' {
            $doubleQuotedElement = $commandAST.CommandElements | Where -Property StringConstantType -eq DoubleQuoted
            break
        }
        'System.Management.Automation.Language.ThrowStatementAst' {
            $doubleQuotedElement = $commandAST.Pipeline.PipelineElements.expression | Where -Property StringConstantType -eq DoubleQuoted
            break
        }
        Default {
            throw 'Not supported AST element'
        }
    }

    $lineNo = $doubleQuotedElement.Extent.StartLineNumber
    $newString = @()
    $newString += $doubleQuotedElement.Value
                
    # if the Double quoted string has Nested expressions i.e. Variables or Subexpressions in it
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
                $SubExpInUse = @()
                # put logic here to see if the subexpression has a variable
                $SubExpInUse += $nestedExpression.SubExpression.Extent.Text
                $newString[0] = $newString[0].Replace("`$($SubExpInUse)","{$i}") # replace the Var Name with a subscript for the Format operator
                    # replace the $ in the var name

                $newString += "`$($SubExpInUse)"
            }
            $newString[0] = $newString[0].Replace('$','')
        }
    }        
    $lineNo, $newString
}