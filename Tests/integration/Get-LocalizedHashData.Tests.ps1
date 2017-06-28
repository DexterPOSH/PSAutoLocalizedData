$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\..\PSAutoLocalizedData -Force


Describe 'Get-LocalizedHashData' -Tag Integration {

$Script = @'
$Name = 'Dexter'
write-Verbose "This contains a $env:Computername"
Write-OutPut -InputObject "123"
Get-Process -Name 'notepad'
Write-Warning -message "This is a warning from $host"
Write-Verbose -Message $('this is {0} network' -f 'management')
throw "name is $Name"
'@
    # Create a dummy file in the test drive
    $Script | Out-File -FilePath TestDrive:\WithoutLocalizedData.ps1
    $Path = Resolve-Path "TestDrive:\WithoutLocalizedData.ps1" | Select-Object -ExpandProperty ProviderPath
        
    Context "Non existent file specified as input" {

        # Act & assert
        It 'Should throw an error' {
            { Get-LocalizedHashData -Path 'Z:\thisfileshouldnotexist.ps1' } | 
                Should throw 'Z:\thisfileshouldnotexist.ps1 not found'
        }
    }

    Context '.ps1 file used as input, only Write-Verbose statements to be localized' {
        $localizedHashData = Get-LocalizedHashData -Path $Path -CommandName 'Write-Verbose'  
        
        It 'Should return a orderedDictionary back' {
            $localiedHashData.GetType().FullName | 
                Should be 'System.Collections.Specialized.OrderedDictionary'
        }

        It 'Should parse the write-Verbose messages only' {
            $localizedHashData.Keys.Count | Should be 1
        }

        It 'Should use the line number as the key in the returned output' {
            $localizedHashData.Keys | Should be 2
        }

        It 'Should have the value as localized data' {

        }
    }

    Context '.ps1 file used as input, default commanName set' {
        $localizedHashData = Get-LocalizedHashData -Path $Path -CommandName 'Write-Verbose'  
        
        It 'Should return a orderedDictionary back' {
            $localiedHashData.GetType().FullName | 
                Should be 'System.Collect$ions.Specialized.OrderedDictionary'
        }

        It 'Should parse the write-Verbose messages only' {
            $localizedHashData.Keys.Count | Should be 1
        }

        It 'Should use the line number as the key in the returned output' {
            $localizedHashData.Keys | Should be 2
        }

        It 'Should have the value as localized data' {

        }

    }

}