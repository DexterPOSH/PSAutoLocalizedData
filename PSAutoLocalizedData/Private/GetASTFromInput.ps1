Function GetASTFromInput {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]$Content
	)
	$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content,[ref]$null,[ref]$Null)
	return $AST
}