Function GetASTFromFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]$Path
	)
    if (Test-Path -Path $path -PathType Leaf) {
	    $AST = [System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$Null)
	    return $AST
    }
    else {
        throw "$path not found"
    }
}
