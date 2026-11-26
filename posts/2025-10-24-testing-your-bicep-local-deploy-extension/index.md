---
title: "Testing your Bicep Local Deploy extension"
status: published
visibility: "members"
tags: ["Course", "Build custom Bicep extensions with Bicep Local Deploy"]
published_at: "2025-10-24T11:34:34.000Z"
custom_template: "custom-lesson"
---

<p>Testing builds reliable Bicep extensions that users trust in production environments. Unit and integration tests have their place. End-to-end testing validates the complete flow from a Bicep template to actual resource deployment. </p><p>This module teaches you to use Pester, PowerShell's testing framework, to write end-to-end tests that invoke Bicep Local Deploy and verify that your extension behaves as expected.</p><p>By the end of this module, you will have a test suite that validates your GoRest extension. You will understand how to structure tests, create reusable helpers, handle test data, and integrate testing into your development workflow.</p><p>In this module, you will:</p><ul><li>Understand different testing approaches for Bicep extensions.</li><li>Set up Pester for end-to-end testing.</li><li>Create reusable test helpers and utilities.</li><li>Write test cases for resource operations.</li><li>Handle test data and cleanup.</li><li>Run tests locally.</li></ul><h2 id="understanding-testing-strategies">Understanding testing strategies</h2><p>This section explores the testing strategies for Bicep extensions. You will understand why end-to-end testing is the focus.</p><h3 id="types-of-testing-available">Types of testing available</h3><p>Building .NET applications like Bicep extensions gives you several testing options, the same way as any .NET application:</p><p><strong>Unit testing</strong> tests individual components in isolation. It tests a single method or class. Popular .NET frameworks include:</p><ul><li><strong>xUnit</strong>: Modern, extensible testing framework with async support.</li><li><strong>NUnit</strong>: Rich framework with an extensive assertion library.</li><li><strong>MSTest</strong>: Microsoft's built-in testing framework, integrated with Visual Studio.</li></ul><p>Unit tests are fast and great for testing business logic, but they don't validate how your extension integrates with Bicep or real APIs.</p><p><strong>Integration testing</strong> tests how components work together. It can test your handler by simulating an API. These tests validate that your code correctly calls APIs and handles responses, but then again, they don't test your Bicep deployment flow.</p><p><strong>End-to-end testing</strong> (our focus) tests the entire system from start to finish. Write your Bicep templates, invoke <code>bicep local-deploy</code>, and verify if the actual resource is created. This approach catches issues that unit and integration tests miss, such as Bicep syntax errors, configuration issues, or API integration failures.</p><h3 id="why-focus-on-end-to-end-testing">Why focus on end-to-end testing?</h3><p>End-to-end testing provides unique value for Bicep extensions:</p><ol><li><strong>Validation</strong>: Tests exactly what users will do. Write Bicep, deploy, get resources.</li><li><strong>Catches integration issues</strong>: Validates that your extension works correctly with the Bicep CLI and runtime.</li><li><strong>Template validation</strong>: Ensures your Bicep examples work and produce expected outputs.</li><li><strong>API integration</strong>: Tests against real (or test) APIs, catching authentication, serialization, and protocol issues.</li><li><strong>Output verification</strong>: Confirms that outputs are correctly populated.</li></ol><p>Unit and integration tests have value for complex business logic. End-to-end tests give you the highest confidence that your extension works as intended. For this module, you'll be using Pester to write these end-to-end tests.</p><h2 id="setting-up-pester">Setting up Pester</h2><p>Pester is PowerShell's testing and mocking framework. Pester can be installed individually and is widely used for infrastructure testing. It provides a clean syntax for organizing tests, assertion capabilities, and easily integrates with CI/CD systems.</p><h3 id="prerequisites">Prerequisites</h3><p>Before setting up Pester, ensure you have:</p><ul><li><strong>PowerShell 7.4 or later: </strong>Check with <code>$PSVersionTable.PSVersion</code>.</li></ul><h3 id="installing-pester">Installing Pester</h3><p>To install Pester's latest version, you can run the following command:</p><pre><code class="language-powershell"># Install latest v5+ version
Install-PSResource -Name Pester -Version 5.7.1 -Repository PSGallery&#10;
# Verify version
Get-Module Pester -ListAvailable</code></pre><h3 id="project-structure-for-tests">Project structure for tests</h3><p>Organize your test files to keep them maintainable and easy to navigate. The recommended structure looks like this:</p><pre><code class="language-plaintext">GoRest/                          # Your extension project
  Models/
  Handlers/
  ...
tests/                           # Test directory (separate from extension)
  GoRest.Tests.ps1               # Main test file for GoRest extension
  scripts/                       # Shared test utilities
    Test-Bicep.ps1               # Checks Bicep CLI availability
    Initialize-TestCase.ps1      # Sets up test cases with dynamic values
  examples/                      # Test Bicep templates
    user/
      create-user.bicep          # Template for creating single user
      create-user.bicepparam     # Parameters for single user
      multiple-users.bicep       # Template for multiple users
      multiple-users.bicepparam  # Parameters for multiple users</code></pre><p>To create the directory structure, run the following commands from your project root:</p><pre><code class="language-powershell"># From your project root
mkdir tests
mkdir tests/scripts
mkdir tests/examples
mkdir tests/examples/user</code></pre><p>This structure separates tests from your extension code. You can run tests without interfering with the build output. The <code>scripts</code> directory contains reusable helpers. The <code>examples</code> directory holds the Bicep templates used in tests.</p><h2 id="creating-test-helpers">Creating test helpers</h2><p>Reusable test helpers eliminate duplication. They make your tests cleaner and more maintainable. It also allows you to dynamically build your test examples.</p><h3 id="verify-bicep-availability">Verify Bicep availability</h3><p>This helper checks if the Bicep CLI is installed. When Bicep is not available, tests skip automatically rather than failing with confusing errors.</p><p>Create the following file <code>Test-Bicep.ps1</code> in the <code>tests/scripts</code> directory:</p><pre><code class="language-powershell">&lt;#
.SYNOPSIS
    Checks if Bicep CLI is available and meets minimum version requirements.&#10;
.DESCRIPTION
    This function verifies that the Bicep CLI is installed and accessible in the PATH.
    It's used in BeforeDiscovery to conditionally skip tests if Bicep is not available.
#&gt;
function Test-Bicep {
    [CmdletBinding()]
    [OutputType([bool])]
    param()&#10;
    try {
        $bicepVersion = &amp; bicep --version&#10;        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Bicep CLI returned error. Exit code: $LASTEXITCODE"
            return $false
        }&#10;
        if ($bicepVersion -match 'Bicep CLI version ([\d.]+)') {
            $version = [version]$matches[1]
            $minVersion = [version]'0.38.63'  # Minimum version with local-deploy support and --format&#10;
            if ($version -lt $minVersion) {
                Write-Warning "Bicep version $version is below minimum required version $minVersion"
                return $false
            }&#10;
            Write-Verbose "Bicep CLI version $version detected"
            return $true
        }
        else {
            Write-Warning "Could not parse Bicep version from output: $bicepVersion"
            return $false
        }
    }
    catch {
        Write-Warning "Bicep CLI not found or not accessible: $_"
        return $false
    }
}</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">Bicep version 0.38.63 is a nightly build version and adds the <code spellcheck="false" style="white-space: pre-wrap;">--format</code> support.</div></div><p></p><p>The key features of this helper are:</p><ul><li>Ensures Bicep supports the updated <code>--format</code> switch.</li><li>Handles errors gracefully.</li><li>Adds verbose output to debug installation.</li><li>Returns an easy <code>Boolean</code> value to validate in Pester.</li></ul><h3 id="set-up-test-scenarios">Set up test scenarios</h3><p>This helper copies test files to Pester's <code>TestDrive</code> (a temporary directory cleaned after tests) and dynamically replaces parameter values. You can use the same templates across different test environments without hardcoding values. It also makes sure that the <code>bicepconfig.json</code> and extensions are copied over to the <code>TestDrive</code>.</p><p>Create the following file <code>Initialize-TestCase.ps1</code> in the <code>tests/scripts</code> directory:</p><pre><code class="language-powershell">&lt;#
.SYNOPSIS
    Copies the extension and creates bicepconfig.json for testing.&#10;
.DESCRIPTION
    Copies the my-extension folder from output directory to the test location
    and creates a bicepconfig.json file configured for local deployment.&#10;
.PARAMETER OutputPath
    Destination path where extension and config should be copied&#10;
.EXAMPLE
    Initialize-ExtensionForTest -OutputPath $TestDrive
#&gt;
function Initialize-ExtensionForTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )&#10;
    $sourceExtensionPath = Join-Path $PSScriptRoot "..\..\output\my-extension"
    $targetExtensionPath = Join-Path $OutputPath "my-extension"&#10;    
    if (Test-Path $sourceExtensionPath) {
        Copy-Item -Path $sourceExtensionPath -Destination $targetExtensionPath -Recurse -Force
        Write-Verbose "Copied extension from $sourceExtensionPath to $targetExtensionPath"
    } else {
        throw "Extension not found at $sourceExtensionPath. Please build the extension first."
    }&#10;    
    $bicepConfig = @{
        experimentalFeaturesEnabled = @{
            localDeploy = $true
        }
        extensions = @{
            GoRestExtension = "my-extension"
        }
        implicitExtensions = @()
    }&#10;    
    $bicepConfigPath = Join-Path $OutputPath "bicepconfig.json"
    $bicepConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $bicepConfigPath -Encoding UTF8
    Write-Verbose "Created bicepconfig.json at $bicepConfigPath"&#10;
    return [PSCustomObject]@{
        BicepConfigFile = $bicepConfigPath
        ExtensionPath   = $targetExtensionPath
    }
}&#10;
&lt;#
.SYNOPSIS
    Initializes a test case by copying files and replacing parameter values.&#10;
.DESCRIPTION
    Copies Bicep template and parameter files to TestDrive and replaces placeholder
    values with actual test values. This allows tests to use dynamic values like
    API endpoints, tokens, and unique identifiers without modifying source files.&#10;
.PARAMETER Path
    Path to the directory containing the Bicep template files&#10;
.PARAMETER OutputPath
    Destination path (typically $TestDrive in Pester tests)&#10;
.PARAMETER ExampleName
    Name of the example/test case (used for file naming)&#10;
.PARAMETER ValuesToReplace
    Hashtable of placeholder values to replace in the copied files
    Key: placeholder name, Value: replacement value&#10;
.EXAMPLE
    $testCase = Initialize-TestCase -Path './examples/user' -OutputPath $TestDrive `
        -ExampleName 'create-user' -ValuesToReplace @{
            workspaceUrl = 'https://gorest.co.in'
            token = $env:GOREST_TOKEN
        }
#&gt;
function Initialize-TestCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,&#10;
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,&#10;
        [Parameter(Mandatory = $true)]
        [string]$ExampleName,&#10;
        [Parameter(Mandatory = $false)]
        [hashtable]$ValuesToReplace = @{}
    )&#10;
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }&#10;
    $extensionSetup = Initialize-ExtensionForTest -OutputPath $OutputPath&#10;
    $bicepFile = Get-ChildItem -Path $Path -Filter "$ExampleName.bicep" -File
    $bicepParamFile = Get-ChildItem -Path $Path -Filter "$ExampleName.bicepparam" -File&#10;
    if (-not $bicepFile) {
        throw "Bicep file not found: $Path/$ExampleName.bicep"
    }&#10;
    $destBicepPath = Join-Path $OutputPath "$ExampleName.bicep"
    $bicepContent = Get-Content $bicepFile.FullName -Raw&#10;
    foreach ($key in $ValuesToReplace.Keys) {
        $placeholder = "{{$key}}"
        $bicepContent = $bicepContent -replace [regex]::Escape($placeholder), $ValuesToReplace[$key]
    }&#10;
    Set-Content -Path $destBicepPath -Value $bicepContent -Encoding UTF8&#10;
    $filesCopied = @($destBicepPath)&#10;
    $destParamPath = $null
    if ($bicepParamFile) {
        $destParamPath = Join-Path $OutputPath "$ExampleName.bicepparam"
        $paramContent = Get-Content $bicepParamFile.FullName -Raw&#10;
        foreach ($key in $ValuesToReplace.Keys) {
            $placeholder = "{{$key}}"
            $paramContent = $paramContent -replace [regex]::Escape($placeholder), $ValuesToReplace[$key]
        }&#10;
        Set-Content -Path $destParamPath -Value $paramContent -Encoding UTF8
        $filesCopied += $destParamPath
    }&#10;
    return [PSCustomObject]@{
        Name              = $ExampleName
        BicepFile         = $destBicepPath
        ParamFile         = $destParamPath
        BicepConfigFile   = $extensionSetup.BicepConfigFile
        ExtensionPath     = $extensionSetup.ExtensionPath
        FilesCopied       = $filesCopied
        OutputPath        = $OutputPath
        ValuesReplaced    = $ValuesToReplace
    }
}</code></pre><p>This helper function helps to integrate the known <code>TestDrive</code> variable that Pester populates on each run. It copies files to this temporary file. When tests are finished, this directory is cleaned up. </p><p>The helper function allows for dynamic replacement of placeholder values. It returns the required paths for tests to run successfully. These two helpers lay the groundwork for different scenarios. Now it's time to create the actual test file.</p><h2 id="writing-end-to-end-tests">Writing end-to-end tests</h2><p>With the helpers ready, you can now write tests for the GoRest <code>User</code> resource. Start with the test file structure, then add specific test cases.</p><h3 id="creating-the-main-test-file">Creating the main test file</h3><p>Start by creating the following <code>GoRest.tests.ps1</code> main test file in the <code>tests</code> directory:</p><pre><code class="language-powershell">[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = 'https://gorest.co.in',&#10;
    [Parameter(Mandatory = $false)]
    [string]$Token = $env:GOREST_TOKEN,&#10;
    [Parameter(Mandatory = $false)]
    [string]$ExtensionName = 'my-extension'
)&#10;
# Script-level variables
$script:rootPath = Split-Path -Path $PSScriptRoot -Parent
$script:extensionPath = Join-Path $script:rootPath 'output'&#10;
# BeforeDiscovery runs before any tests, used to determine if tests should be skipped
BeforeDiscovery {
    # Load test helpers
    . (Join-Path $PSScriptRoot 'scripts' 'Test-Bicep.ps1')&#10;    
    # Check if Bicep is available
    $script:bicepAvailable = Test-Bicep&#10;    
    if (-not $script:bicepAvailable) {
        Write-Warning "Bicep CLI not available or version too old. Tests will be skipped."
    }&#10;
    # Check if extension is built
    $script:extensionBuilt = Test-Path (Join-Path $script:extensionPath $ExtensionName)&#10;    
    if (-not $script:extensionBuilt) {
        Write-Warning "GoRest extension not built. Run build.ps1 first. Tests will be skipped."
    }&#10;
    # Check if token is available
    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Warning "GOREST_TOKEN not set. Some tests may fail. Get a token from https://gorest.co.in"
    }&#10;
    # Overall skip condition
    $script:skip = -not ($script:bicepAvailable -and $script:extensionBuilt)
}&#10;
# BeforeAll runs once before all tests in this file
BeforeAll {
    # Load test helpers
    . (Join-Path $PSScriptRoot 'scripts' 'Initialize-TestCase.ps1')&#10;    
    # Set environment variable for authentication
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $env:API_KEY = $Token
    }
}&#10;
Describe 'GoRest User resource functionality' -Skip:$skip {&#10;    
    Context 'Creating users' {&#10;        
        It 'Should create a single user successfully' {
            $uniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)
            $testEmail = "test.user.$uniqueId@example.com"&#10;            
            $testCase = Initialize-TestCase `
                -Path (Join-Path $PSScriptRoot 'examples' 'user') `
                -OutputPath $TestDrive `
                -ExampleName 'create-user' `
                -ValuesToReplace @{
                    baseUrl = $BaseUrl
                    token   = $Token
                    email   = $testEmail
                }&#10;
            $result = &amp; bicep local-deploy $testCase.ParamFile --format json&#10;
            $LASTEXITCODE | Should -Be 0 -Because "deployment should succeed"
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Not -Contain 'Error'
            $result | Should -Not -Contain 'Failed'&#10;
            $resultConverted = $result | ConvertFrom-Json&#10;
            # Verify outputs
            $resultConverted.outputs | Should -Not -BeNullOrEmpty -Because "outputs should be present"
            $resultConverted.outputs.userId | Should -Not -BeNullOrEmpty -Because "userId should be present"
            $resultConverted.outputs.userEmail | Should -Be $testEmail -Because "userEmail should match input"
            $resultConverted.outputs.userName | Should -Be 'Test User' -Because "userName should match input"
        }&#10;
        It 'Should create multiple users successfully' {
            $uniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)
            $adminEmail = "admin.$uniqueId@example.com"
            $devEmail = "developer.$uniqueId@example.com"&#10;            
            $testCase = Initialize-TestCase `
                -Path (Join-Path $PSScriptRoot 'examples' 'user') `
                -OutputPath $TestDrive `
                -ExampleName 'multiple-users' `
                -ValuesToReplace @{
                    baseUrl    = $BaseUrl
                    token      = $Token
                    adminEmail = $adminEmail
                    devEmail   = $devEmail
                }&#10;
            $result = &amp; bicep local-deploy $testCase.ParamFile --format json&#10;
            $LASTEXITCODE | Should -Be 0 -Because "deployment should succeed"
            $result | Should -Not -BeNullOrEmpty&#10;
            $result | Should -Not -Contain 'Error'
            $result | Should -Not -Contain 'Failed'&#10;
            $resultConverted = $result | ConvertFrom-Json&#10;            
            # Verify outputs
            $resultConverted.outputs | Should -Not -BeNullOrEmpty -Because "outputs should be present"
            $resultConverted.outputs.adminUserId | Should -Not -BeNullOrEmpty -Because "adminUserId should be present"
            $resultConverted.outputs.adminUserEmail | Should -Be $adminEmail -Because "adminUserEmail should match input"
            $resultConverted.outputs.devUserId | Should -Not -BeNullOrEmpty -Because "devUserId should be present"
            $resultConverted.outputs.devUserEmail | Should -Be $devEmail -Because "devUserEmail should match input"
        }
    }&#10;
    Context 'Updating users' {&#10;        
        It 'Should be idempotent - redeploying same user should succeed' {
            $uniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)
            $testEmail = "idempotent.$uniqueId@example.com"&#10;            
            $testCase = Initialize-TestCase `
                -Path (Join-Path $PSScriptRoot 'examples' 'user') `
                -OutputPath $TestDrive `
                -ExampleName 'create-user' `
                -ValuesToReplace @{
                    baseUrl = $BaseUrl
                    token   = $Token
                    email   = $testEmail
                }&#10;
            $result1 = &amp; bicep local-deploy $testCase.ParamFile --format json
            $LASTEXITCODE | Should -Be 0 -Because "first deployment should succeed"&#10;
            $result2 = &amp; bicep local-deploy $testCase.ParamFile --format json&#10;
            $LASTEXITCODE | Should -Be 0 -Because "second deployment should also succeed"
            $result2 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -Contain 'Error'
            $result2 | Should -Not -Contain 'Failed'&#10;
            $resultConverted = $result2 | ConvertFrom-Json&#10;
            # Verify outputs
            $resultConverted.outputs | Should -Not -BeNullOrEmpty -Because "outputs should be present"
            $resultConverted.outputs.userId | Should -Not -BeNullOrEmpty -Because "userId should be present"
            $resultConverted.outputs.userEmail | Should -Be $testEmail -Because "userEmail should match input"
            $resultConverted.outputs.userName | Should -Be 'Test User' -Because "userName should match input"
        }
    }
}</code></pre><p>Now, before running the tests, you need the two example Bicep files that the test references.</p><h3 id="creating-test-bicep-templates">Creating test Bicep templates</h3><p>In the <code>examples</code> directory, create the following <code>create-user.bicep</code> file:</p><pre><code class="language-bicep">targetScope = 'local'&#10;
param baseUrl string
@secure()
param token string
param email string&#10;
extension GoRestExtension with {
  baseUrl: baseUrl
  token: token
}&#10;
resource user 'User' = {
  name: 'Test User'
  email: email
  gender: 'Male'
  status: 'Active'
}&#10;
output userId int = user.id
output userEmail string = user.email
output userName string = user.name
</code></pre><p>Create the <code>create-user.bicepparam</code> in the same directory:</p><pre><code class="language-bicep">using 'create-user.bicep'&#10;
param baseUrl = '{{baseUrl}}'
param token = '{{token}}'
param email = '{{email}}'</code></pre><p>To test multiple users, you can create <code>multiple-users.bicep</code>:</p><pre><code class="language-bicep">targetScope = 'local'&#10;
param baseUrl string
@secure()
param token string
param adminEmail string
param devEmail string&#10;
extension GoRestExtension with {
  baseUrl: baseUrl
  token: token
}&#10;
resource adminUser 'User' = {
  name: 'Admin User'
  email: adminEmail
  gender: 'Female'
  status: 'Active'
}&#10;
resource devUser 'User' = {
  name: 'Developer User'
  email: devEmail
  gender: 'Male'
  status: 'Active'
}&#10;
output adminUserId int = adminUser.id
output adminUserEmail string = adminUser.email
output devUserId int = devUser.id
output devUserEmail string = devUser.email
</code></pre><p>Do the same with the single user by creating the <code>multiple-user.bicepparam</code> file:</p><pre><code class="language-bicep">using 'multiple-users.bicep'&#10;
param baseUrl = '{{baseUrl}}'
param token = '{{token}}'
param adminEmail = '{{adminEmail}}'
param devEmail = '{{devEmail}}'</code></pre><p>The templates use <code>{{placeholder}}</code> syntax for values that will be replaced by <code>Initialize-TestCase</code>. Tests can inject unique emails, different base URLs, or test-specific tokens.</p><h2 id="running-your-tests">Running your tests</h2><p>Before integration tests in a CI/CD pipeline or the automation scripts, you can explore how tests run locally. </p><h3 id="running-all-tests">Running all tests</h3><p>From your project root, run all tests:</p><pre><code class="language-powershell"># Basic run
Invoke-Pester -Path ./tests/GoRest.Tests.ps1&#10;
# Detailed output
Invoke-Pester -Path ./tests/GoRest.Tests.ps1 -Output Detailed&#10;
# Pass parameters
$pesterContainer = New-PesterContainer -Path "tests/GoRest.Tests.ps1" -Data @{ Token = "&lt;yourToken&gt;";}
Invoke-Pester -Container $pesterContainer</code></pre><p>When the test runs successfully, you should see:</p><pre><code class="language-plaintext">Starting discovery in 1 files.
Discovery found 3 tests in 366ms.
Running tests.&#10;
Running tests from 'C:\source\GoRest\tests\GoRest.tests.ps1'
Describing GoRest User resource functionality
 Context Creating users
   [+] Should create a single user successfully 4.26s (4.26s|2ms)                                                       
   [+] Should create multiple users successfully 4.53s (4.53s|1ms)                                                      
 Context Updating users
   [+] Should be idempotent - redeploying same user should succeed 8.2s (8.2s|2ms)
Tests completed in 17.44s
Tests Passed: 3, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0</code></pre><h2 id="advanced-testing-patterns">Advanced testing patterns</h2><p>Now that you've followed the "happy path", these advanced patterns include parameterized tests, two follow the "unhappy path", and consider rate limits.</p><h3 id="parameterized-tests">Parameterized tests</h3><p>Parameterized tests eliminate code duplication when testing the same logic with multiple input values. Instead of writing separate test cases for each scenario, you can define the test logic once and provide different data sets. Pester's <code>ForEach</code> parameter makes this easy. You pass in an array of <code>hashtables</code>, and Pester runs the test once for each table present. </p><p>To test the same logic with different inputs, add the following testcase to your testsuite:</p><pre><code class="language-powershell">Context 'Creating users with different genders' {
        BeforeDiscovery {
            $script:genderTestCases = @(
                @{ Gender = 'Male'; Name = 'John Doe' }
                @{ Gender = 'Female'; Name = 'Jane Doe' }
            )
        }&#10;
        It 'Should create user with gender: &lt;Gender&gt;' -ForEach $genderTestCases {
            param($Gender, $Name)&#10;        
            $uniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)
            $testEmail = "test.$uniqueId@example.com"
            $testName = "gender-$Gender-$uniqueId"&#10;            
            $testPath = Join-Path $TestDrive $testName
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null&#10;            
            . (Join-Path $PSScriptRoot 'scripts' 'Initialize-TestCase.ps1')
            $extensionSetup = Initialize-ExtensionForTest -OutputPath $testPath&#10;        
            $bicepContent = @"
targetScope = 'local'&#10;
@secure()
param token string&#10;
extension GoRestExtension with {
  baseUrl: '$BaseUrl'
  token: token
}&#10;
resource user 'User' = {
  name: '$Name'
  email: '$testEmail'
  gender: '$Gender'
  status: 'Active'
}&#10;
output userId int = user.id
output userEmail string = user.email
output userName string = user.name
"@&#10;        
            $bicepPath = Join-Path $testPath "$testName.bicep"
            Set-Content -Path $bicepPath -Value $bicepContent -Encoding UTF8&#10;            
            $paramContent = @"
using '$testName.bicep'&#10;
param token = '$Token'
"@&#10;            
            $paramPath = Join-Path $testPath "$testName.bicepparam"
            Set-Content -Path $paramPath -Value $paramContent -Encoding UTF8&#10;        
            $result = &amp; bicep local-deploy $paramPath --format json&#10;        
            $LASTEXITCODE | Should -Be 0 -Because "deployment should succeed for gender: $Gender"
            $result | Should -Not -BeNullOrEmpty&#10;            
            $resultConverted = $result | ConvertFrom-Json
            $resultConverted.outputs.userId | Should -Not -BeNullOrEmpty
            $resultConverted.outputs.userEmail | Should -Be $testEmail
            $resultConverted.outputs.userName | Should -Be $Name
        }
    }</code></pre><h3 id="rate-limiting-considerations">Rate limiting considerations</h3><p>Most public APIs enforce rate limits to prevent abuse. When testing against real APIs like GoRest, these limits can cause test failures unrelated to your code.</p><p>Rate limits are confusing during testing runs. They waste time and make results unreliable. The solution is to throttle by adding delays between tests. Pester's <code>BeforeEach</code> block provides a perfect place to implement this. Before each <code>It</code> block, you can add the following code block:</p><pre><code class="language-powershell">BeforeEach {
    # Add delay between tests to avoid rate limiting
    if ($script:lastTestTime) {
        $elapsed = (Get-Date) - $script:lastTestTime
        $minimumDelay = [TimeSpan]::FromSeconds(2)&#10;        
        if ($elapsed -lt $minimumDelay) {
            $waitTime = $minimumDelay - $elapsed
            Start-Sleep -Seconds $waitTime.TotalSeconds
        }
    }
    $script:lastTestTime = Get-Date
}</code></pre><h3 id="the-unhappy-path">The "unhappy path"</h3><p>You've tested the happy path (or flow), giving you the confidence that your extension works. But what about unhappy paths? Testing failures are commonly known in the software development landscape. Gracefully testing scenarios that will fail builds your confidence even more. </p><p>The "unhappy path" covers ways that things can go wrong: invalid input, missing authentication, malformed data, and API errors. These tests verify that your extension provides clear error messages. </p><p>To test the unhappy paths, add the two following tests:</p><pre><code class="language-powershell">Context 'Error handling' {&#10;        
        It 'Should fail with invalid email format' {
            $testCase = Initialize-TestCase `
                -Path (Join-Path $PSScriptRoot 'examples' 'user') `
                -OutputPath $TestDrive `
                -ExampleName 'create-user' `
                -ValuesToReplace @{
                baseUrl = $BaseUrl
                token   = $Token
                email   = 'not-an-email'  # Invalid email
            }&#10;
            $result = &amp; bicep local-deploy $testCase.ParamFile --format json 2&gt;&amp;1&#10;
            $LASTEXITCODE | Should -Not -Be 0 -Because "invalid email should cause failure"
            $result.outputs | Should -BeNullOrEmpty -Because "no outputs should be present on failure"
        }&#10;
        It 'Should fail with missing authentication' {
            $originalToken = $env:API_KEY
            $env:API_KEY = $null&#10;            
            try
            {
                $uniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)
                $testCase = Initialize-TestCase `
                    -Path (Join-Path $PSScriptRoot 'examples' 'user') `
                    -OutputPath $TestDrive `
                    -ExampleName 'create-user' `
                    -ValuesToReplace @{
                    baseUrl = $BaseUrl
                    token   = ''  # Empty token
                    email   = "noauth.$uniqueId@example.com"
                }&#10;
                $result = &amp; bicep local-deploy $testCase.ParamFile --format json&#10;
                $LASTEXITCODE | Should -Not -Be 0
                $result.outputs | Should -BeNullOrEmpty -Because "no outputs should be present on auth failure"
            }
            finally
            {
                $env:API_KEY = $originalToken
            }
        }
    }</code></pre><p>Perfect, you've set up advanced patterns. Try rerunning the tests to see if all of them pass. A successful run should return:</p><pre><code class="language-plaintext">Starting discovery in 1 files.
Discovery found 7 tests in 363ms.
Running tests.&#10;
Running tests from 'C:\source\GoRest\tests\GoRest.tests.ps1'
Describing GoRest User resource functionality
 Context Creating users
   [+] Should create a single user successfully 4.3s (4.29s|7ms)
   [+] Should create multiple users successfully 4.22s (4.22s|0ms)
 Context Updating users
   [+] Should be idempotent - redeploying same user should succeed 8.36s (8.36s|2ms)
 Context Error handling
   [+] Should fail with invalid email format 4.16s (4.16s|2ms)
PS C:\source\GoRest&gt; 
   [+] Should fail with missing authentication 17.31s (17.3s|7ms)
 Context Creating users with different genders
   [+] Should create user with gender: Male 4.13s (4.13s|2ms)
   [+] Should create user with gender: Female 4.17s (4.17s|1ms)
Tests completed in 47.2s
Tests Passed: 7, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0</code></pre><h2 id="automating-tests-in-build-script">Automating tests in build script</h2><p>You've run tests manually now by executing <code>Invoke-Pester</code>. But automation ensures tests run consistently every time you make a change to your extension and publish it locally. Your build script should support running tests during this process.</p><p>Adding a <code>-Test</code> switch that triggers test execution after a successful publish instantly gives you the feedback you need.</p><h3 id="adding-test-switch-to-automation-script">Adding test switch to automation script</h3><p>The test switch runs Pester tests after your extension is built and published. This gives you a single command to build and validate your extension.</p><p>To add this switch, update the <code>build.ps1</code> script with a test parameter and logic after the extension is published:</p><pre><code class="language-powershell"># Top section parameters
#Requires -Version 7.0
[CmdletBinding()]
param (
    [ValidateSet("Release", "Debug")]
    [string]
    $Configuration = "Release",&#10;
    [switch]
    $Clean,&#10;
    [switch]
    $Test
)</code></pre><p>After the compilation, add the following:</p><pre><code class="language-powershell">if ($bicepExe)
    {
        Write-Verbose -Message "Bicep CLI found at $bicepExe" -Verbose
        Write-Verbose -Message "Compiling Bicep files for extension '$targetName'." -Verbose
        Write-Verbose -Message ($extensionParams | ConvertTo-Json | Out-String) -Verbose
        &amp; $bicepExe @extensionParams&#10;
        if ($Test.IsPresent)
        {
            Write-Verbose "Running tests..." -Verbose&#10;    
            $testPath = Join-Path $PSScriptRoot 'tests'
            if (Test-Path $testPath)
            {
                $pesterConfig = New-PesterConfiguration
                $pesterConfig.Run.Path = $testPath
                $pesterConfig.Run.Exit = $true
                $pesterConfig.Output.Verbosity = 'Detailed'&#10;        
                Invoke-Pester -Configuration $pesterConfig
            }
            else
            {
                Write-Warning "Test directory not found at '$testPath'. Skipping tests."
            }
        }
    }
    else
    {
        Write-Warning "Bicep CLI is not installed. Skipping Bicep compilation."
        return
    }</code></pre><p>You can now run <code>./build.ps1 -Test</code> script, which triggers the Pester tests. This pattern integrates testing directly into your development workflow. If a test fails, the exit code prevents failed tests from blocking your release.</p><h2 id="summary">Summary</h2><p>You learned these topics in this module:</p><ul><li>Different testing approaches and why end-to-end testing was the focus in this module.</li><li>Setting up Pester for PowerShell-based testing.</li><li>Created reusable test helpers.</li><li>Written test cases that cover:<ul><li>Resource creation.</li><li>Idempotency and updates.</li><li>Error handling.</li><li>Output validation.</li></ul></li><li>Running test locally.</li><li>Implemented advanced testing patterns.</li><li>Integrated into the build automation script.</li></ul><p>You now have a complete test suite that validates your GoRest extension works correctly. These tests give you confidence to make more changes and provide users with a reliable extension.</p><h2 id="next-steps">Next steps</h2><p>With a consistent build script in place, you are ready to look at documentation and publish your extension. The next module covers:</p><ul><li>Generate documentation from your code attributes.</li><li>Validate documentation completeness.</li><li>Publish to Azure Container Registry.</li><li>Reference your extension from Bicep templates.</li></ul><h2 id="knowledge-check">Knowledge check</h2><ol><li><strong>Why is end-to-end testing particularly valuable for Bicep extensions?</strong></li></ol><p>Answer: End-to-end testing validates the complete flow from Bicep template to actual resource deployment. It catches integration issues, template errors, and API problems that unit tests miss. It tests exactly what users will do in production.</p><ol start="2"><li><strong>What is the purpose of the TestDrive in Pester?</strong></li></ol><p>Answer: TestDrive is a temporary directory that Pester creates for each test file and cleans up automatically afterward. It provides an isolated location for test files without polluting the actual file system.</p><ol start="3"><li><strong>Why use unique identifiers (like GUIDs) in test data?</strong></li></ol><p>Answer: Unique identifiers prevent conflicts when tests run in parallel or when multiple test runs occur without cleanup.</p>
