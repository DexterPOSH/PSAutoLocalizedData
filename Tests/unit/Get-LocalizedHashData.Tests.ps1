$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\..\PSAutoLocalizedData -Force

InModuleScope -ModuleName PSAutoLocalizedData {

    Describe 'Get-LocalizedHashData' -Tags UnitTest {

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
    
        Context "File as an Input" {
            
            It 'Should fail if the file does not exist' {
                {Get-LocalizedHashData -Path 'F:\doesnotExist.ps1' } | Should throw 
            }
            
            It "Should try to parse the Script file" {
                Mock -CommandName GetASTFromFile  -MockWith {throw 'dummy'}
                {Get-LocalizedHashData -Path $Path} | Should throw 'dummy'
                Assert-MockCalled -Command GetASTFromFile -Scope It
            }
            
            It 'Should fail if no AST Object returned' {
                Mock -CommandName GetASTFromFile
                {Get-LocalizedHashData -Path $Path} | Should throw 'AST empty'
                Assert-MockCalled -Command GetASTFromFile -Scope It
            }

            It "Should NOT return anything if AST does not find any command elements" {
                Mock -CommandName GetASTFromFile -MockWith {
                    New-Module -AsCustomObject -ScriptBlock {
                        Function FindAll {
                            return $null
                        }
                    }
                } # end Mock

                Get-LocalizedHashData -Path $Path | Should BeNullOrEmpty
                Assert-MockCalled -Command GetASTFromFile -Scope It
            }
        }

        
        Context 'File as an input & tests for single quoted string is parsed' {
            Mock -CommandName GetASTFromFile -MockWith {
                New-Module -AsCustomObject -ScriptBlock {
                    Function FindAll {
                        $Global:FindAllCalled = $True
                        New-Module -AsCustomObject -ScriptBlock {
                            $CommandElements= @(
                                    [pscustomobject]@{
                                        StringConstantType = 'SingleQuoted'
                                        Value='This contains a Computername'
                                        Extent=@{
                                            StartLineNumber=3
                                        }
                                    }
                                );
                            Function GetCommandName {
                                'Write-Verbose'
                                $Global:GetCommandNameCalled= $True    
                            }
                            Export-ModuleMember -Variable * -Function *
                        }      
                    }
                                    
                }
            } # end Mock

            # Act
            $OutputHash = Get-LocalizedHashData -Path $Path

            # Assert
            It 'Should call the GetASTFromFile function to parse the file' {
                Assert-MockCalled -Command GetASTFromFile -Scope Context
            }

            It 'Should call the FindAll() method on the AST object' {
                $Global:FindAllCalled | Should be $True
            }

            It 'Should call the GetCommandName() method on the Command AST object' {
                $Global:GetCommandNameCalled | Should be $True
            }

            It 'Should return an ordered dictionary object' {
                $OutputHash.GetType().FullName | Should be 'System.Collections.Specialized.OrderedDictionary'
            }


            It 'Should return hash table with line no as key' {
                $OutputHash | Should Not BeNullOrEmpty
                $OutputHash.Keys | Should be 3
            }

            It 'Should return the single quoted string as it is' {
                $OutputHash.Values | Should be 'This contains a Computername'  
            }
        }


        Context 'File as an input & tests for double quoted string without any expression is parsed' {
            
            # Arrange
            Mock -CommandName GetASTFromFile -MockWith {
                New-Module -AsCustomObject -ScriptBlock {
                    Function FindAll {
                        $Global:FindAllCalled = $True
                        New-Module -AsCustomObject -ScriptBlock {
                            $CommandElements= @(
                                    [pscustomobject]@{
                                        StringConstantType = 'DoubleQuoted'
                                        Value="This contains a Computername"
                                        Extent=@{
                                            StartLineNumber=2
                                        }
                                    }
                                );
                            Function GetCommandName {
                                'Write-Verbose'
                                $Global:GetCommandNameCalled= $True    
                            }
                            Export-ModuleMember -Variable * -Function *
                        }      
                    }
                                    
                }
            } # end Mock
            
            # Act
            $outputHash = $OutputHash = Get-LocalizedHashData -Path $Path
            
            # Assert
            It 'Should call the GetASTFromFile function to parse the file' {
                Assert-MockCalled -Command GetASTFromFile -Scope Context
            }

            It 'Should return hash table with line no as key' {
                $OutputHash | Should Not BeNullOrEmpty
                $OutputHash.Keys | Should be 2
            }

            It 'Should return the double quoted string as it is' {
                $OutputHash.Values | Should be 'This contains a Computername'  
            }
        }

         
        Context 'File as an input & tests for double quoted string with variable is parsed' {
            # Arrange
            Mock -CommandName GetASTFromFile -MockWith {
                New-Module -AsCustomObject -ScriptBlock {
                    Function FindAll {
                        $Global:FindAllCalled = $True
                        New-Module -AsCustomObject -ScriptBlock {
                            $CommandElements= @(
                                    [pscustomobject]@{
                                        StringConstantType = 'DoubleQuoted'
                                        Value = 'This contains a $env:Computername' # a variable as a nested expression
                                        NestedExpressions = @(
                                            [pscustomobject]@{
                                                VariablePath = '$env:computerName'
                                            } 
                                        )
                                        Extent = @{
                                            StartLineNumber=2
                                        }
                                    }
                                );
                            Function GetCommandName {
                                'Write-Verbose'
                                $Global:GetCommandNameCalled= $True    
                            }
                            Export-ModuleMember -Variable * -Function *
                        }      
                    }
                                    
                }
            } # end Mock
            
            # Act
            $outputHash = $OutputHash = Get-LocalizedHashData -Path $Path
            
            # Assert
            It 'Should call the GetASTFromFile function to parse the file' {
                Assert-MockCalled -Command GetASTFromFile -Scope Context
            }

            It 'Should return hash table with line no as key' {
                $OutputHash | Should Not BeNullOrEmpty
                $OutputHash.Keys | Should be 2
            }

            It 'Should return the double quoted string as it is' {
                $OutputHash.Values | Should be 'This contains a Computername'  
            }
              

        }
        
        Context "File Content as an Input & tests for double quoted string with subexpression is parsed" {
            
            It 'Should try to parse the string input' {

            }

        }

        Context 'File as an Input and Prefix used' {
        
        }


    } # end Describe

} # end InModuleScope