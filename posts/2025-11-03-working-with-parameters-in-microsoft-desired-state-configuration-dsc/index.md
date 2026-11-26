---
title: "Working with parameters in Microsoft Desired State Configuration (DSC)"
status: published
tags: ["Microsoft Desired State Configuration v3"]
published_at: "2025-11-03T04:57:24.000Z"
custom_excerpt: "Learn how to leverage parameters in Microsoft DSC configuration documents"
feature_image: "images/2025-11-featureimage.png"
---

<p>If you worked with PowerShell Desired State Configuration (PSDSC), <em>you know the pain</em>.</p><p>Managing parameters was a nightmare. You wrote a configuration. You compiled it into an MOF file. You deployed that MOF. Then you needed different parameters for staging. So you compiled again. Then production needed different values. You compiled a third time.</p><p>Every parameter change meant recompiling. Every environment needed its own MOF file. Every deployment required managing and distributing these files across your infrastructure.</p><p>It was <em>exhausting</em>.</p><p>Microsoft Desired State Configuration (DSC) changes everything.</p><p>Parameters are processed at runtime. One configuration file. Multiple environments. No compilation. No MOF files. No distribution headache.</p><p>You define your configuration once. You run it with different parameters. That's it.</p><p>This article shows you how, starting with a comparison of PSDSC versus Microsoft DSC.</p><h2 id="comparing-parameters">Comparing parameters</h2><p>Before you look at how you can work with parameters in Microsoft DSC, let's see both scenarios in both systems using a real-world example: deploying a web server configuration to production with environment-specific parameters.</p><p>In a compilation workflow using PSDSC, the following configuration document illustrates what happens:</p><pre><code class="language-powershell"># Step 1: Define the configuration script
Configuration WebServerConfig {
    param(
        [string]$Environment = 'Development',
        [int]$Port = 8080
    )&#10;
    Import-DscResource -ModuleName PSDesiredStateConfiguration&#10;    
    Node $ServerName {
        WindowsFeature IIS {
            Name = 'Web-Server'
            Ensure = 'Present'
        }&#10;        
        File ConfigFile {
            DestinationPath = "C:\Config\app.config"
            Contents = "Environment: $Environment`nPort: $Port"
        }
    }
}&#10;
# Step 2: COMPILE to MOF file (parameters become hardcoded)
WebServerConfig -Environment 'Production' -Port 443 -ServerName 'WebServer01' -OutputPath 'C:\MOFs'
# Creates: C:\MOFs\WebServer01.mof with hardcoded values&#10;
# Step 3: APPLY the MOF file (separate operation)
Start-DscConfiguration -Path 'C:\MOFs' -Wait&#10;
# Problem: To use different parameters, you must:
# 1. Recompile the configuration script
# 2. Generate a new MOF file
# 3. Distribute the new MOF to target systems</code></pre><p>As you can see, the challenge is clear: parameters are "baked into" the MOF file at compile time. Each environment needs its own MOF file. Changing values requires recompiling and redistributing.</p><p>Now let's look at how Microsoft DSC does it:</p><pre><code class="language-yaml"># webserver-config.dsc.yaml - One configuration for all environments
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  environment:
    type: string
  port:
    type: int
  configPath:
    type: string
resources:
  - name: IIS Web Server
    type: Microsoft.Windows/WindowsPowerShell
    properties:
      resources:
        - name: Web-Server Feature
          type: PsDesiredStateConfiguration/WindowsFeature
          properties:
            Name: Web-Server
            Ensure: Present
        - name: Application Config File
          type: PsDesiredStateConfiguration/File
          properties:
            DestinationPath: "[parameters('configPath')]"
            Contents: "[concat('Environment: ', parameters('environment'), '\nPort: ', string(parameters('port')))]"
            Ensure: Present</code></pre><p>To run it for different environments, you can simply add the <code>--parameters</code> option when calling <code>dsc</code> at runtime:</p><pre><code class="language-powershell"># Development
dsc config get --file webserver-config.dsc.yaml --parameters '{"parameters":{"environment":"development","port":8080,"configPath":"C:\\Config\\dev-app.config"}}'&#10;
# Production
dsc config get --file webserver-config.dsc.yaml --parameters '{"parameters":{"environment":"production","port":443,"configPath":"C:\\Config\\prod-app.config"}}'&#10;
# Change values instantly - just provide different parameters
dsc config get --file webserver-config.dsc.yaml --parameters '{"parameters":{"environment":"staging","port":9000,"configPath":"C:\\Config\\staging-app.config"}}'</code></pre><p>The improvement is clear. Parameters are evaluated at runtime. One configuration file works everywhere, and the values can change instantly without any recompilation.</p><p>Here's a quick table of the <strong>key differences</strong> between PSDSC and Microsoft DSC:</p><table>
<thead>
<tr>
<th>Aspect</th>
<th>PowerShell DSC</th>
<th>Microsoft DSC</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Parameter processing</strong></td>
<td>Compile-time (static)</td>
<td>Runtime (dynamic)</td>
</tr>
<tr>
<td><strong>Workflow</strong></td>
<td>Write script → Compile to MOF → Apply MOF</td>
<td>Write config → Execute with parameters</td>
</tr>
<tr>
<td><strong>Intermediate files</strong></td>
<td>MOF files required</td>
<td>No MOF files</td>
</tr>
<tr>
<td><strong>Change parameters</strong></td>
<td>Recompile + redistribute</td>
<td>Provide different values</td>
</tr>
<tr>
<td><strong>Multi-environment</strong></td>
<td>One MOF per environment</td>
<td>One config + parameter files</td>
</tr>
<tr>
<td><strong>Parameter format</strong></td>
<td>PowerShell function parameters</td>
<td>JSON/YAML files or inline</td>
</tr>
</tbody>
</table>
<h2 id="understanding-parameter-definitions"><strong>Understanding parameter definitions</strong></h2><p>Now that you see how Microsoft DSC differs from PSDSC, let’s look at the ways to pass parameters to your configurations, beginning with parameter definitions.</p><p>As you've seen in the above code snippet, parameters are defined with the <code>parameters</code> keyword. Take a look at the following configuration document:</p><pre><code class="language-yaml"># example-config.dsc.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  environment:
    type: string
    defaultValue: development
    allowedValues:
      - development
      - staging
      - production
  port:
    type: int
    defaultValue: 8080
    minValue: 1
    maxValue: 65535
  serverName:
    type: string
    defaultValue: myserver
    minLength: 3
    maxLength: 15
  enableSSL:
    type: bool
    defaultValue: false
  tags:
    type: array
    defaultValue:
      - web
      - production
    minLength: 1
    maxLength: 5
resources:
  - name: Echo Configuration
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[concat('Env: ', parameters('environment'), ', Server: ', parameters('serverName'), ', Port: ', string(parameters('port')), ', SSL: ', string(parameters('enableSSL')))]"</code></pre><p>Each parameter can have two properties:</p><ul><li><strong>type</strong>: The data type (string, int, bool, array, object, secureString, secureObject).</li><li><strong>defaultValue</strong>: Used if no value is provided.</li></ul><p>It's also possible to add optional constraints:</p><ul><li>For <strong>string </strong>types: <code>minLength</code>, <code>maxLength</code>, <code>allowedValues</code>.</li><li>For <strong>int </strong>types: <code>minValue</code>, <code>maxValue</code>, <code>allowedValues</code>.</li><li>For <strong>array </strong>types: <code>minLength</code>, <code>maxLength</code>, <code>allowedValues</code>.</li><li>For <strong>all</strong> types: <code>allowedValues</code> (array of permitted values).</li></ul><p>Now that you know about the parameter definitions, let's look at how you can provide parameters to the engine.</p><h2 id="method-1-using-parameter-files">Method 1: Using parameter files</h2><p>Parameter files provide a structured way to define parameter values separately from your configuration. This is the most common and recommended approach for managing parameters.</p><p>For illustration purposes, you can create it in multiple ways. Choose the one that appeals to you.</p><h3 id="use-json-parameter-file"><strong>Use JSON parameter file</strong></h3><p>Create the following JSON file containing your parameters:</p><pre><code class="language-json">// parameters.json
{
  "parameters": {
    "environment": "production",
    "port": 443,
    "serverName": "web-prod-01"
  }
}</code></pre><p>To use the parameter file, use it with your configuration:</p><pre><code class="language-bash">dsc config --parameters-file parameters.json get --file example-config.dsc.yaml</code></pre><h3 id="use-powershell-to-create-a-parameters-file"><strong>Use PowerShell to create a parameters file</strong></h3><p>You can create the parameters file using PowerShell and save it as JSON:</p><pre><code class="language-powershell"># Create parameters as a hashtable and convert to JSON
$params = @{
    parameters = @{
        environment = 'production'
        port = 443
        serverName = 'web-prod-01'
    }
} | ConvertTo-Json&#10;
# Save to file
$params | Set-Content -Path 'parameters.json'&#10;
# Use with DSC
dsc config --parameters-file parameters.json get --file example-config.dsc.yaml</code></pre><h3 id="use-yaml-parameter-file"><strong>Use YAML parameter file</strong></h3><p>DSC also supports YAML parameter files, which can be more readable for complex structures:</p><pre><code class="language-yaml"># parameters.yaml
parameters:
  environment: production
  port: 443
  serverName: web-prod-01
  tags:
    - web
    - critical
  metadata:
    owner: platform-team
    costCenter: engineering</code></pre><p>Then, to apply the parameter file, you'll run:</p><pre><code class="language-bash">dsc config --parameters-file parameters.yaml get --file example-config.dsc.yaml</code></pre><h3 id="bonus-using-yayaml-in-powershell"><strong>Bonus: Using YaYaml in PowerShell</strong></h3><p>If you prefer to stick with PowerShell and convert parameter files from a hashtable, use the <a href="https://www.powershellgallery.com/packages/Yayaml/0.7.0">YaYaml</a> PowerShell module:<br></p><pre><code class="language-powershell"># Install YaYaml module if not already installed
Install-PSResource -Name YaYaml -Scope CurrentUser&#10;
# Create parameters as a hashtable
$params = @{
    parameters = @{
        environment = 'production'
        port = 443
        serverName = 'web-prod-01'
        tags = @('web', 'critical')
        metadata = @{
            owner = 'platform-team'
            costCenter = 'engineering'
        }
    }
}&#10;
# Convert to YAML and save
$params | ConvertTo-Yaml -Depth 10 | Set-Content -Path 'parameters.yaml'&#10;
# Use with DSC
dsc config --parameters-file parameters.yaml get --file example-config.dsc.yaml</code></pre><h2 id="method-2-using-inline-parameters">Method 2: Using inline parameters</h2><p>This example was showcased in the introduction. Inline parameters allow you to pass parameters directly on the command line without creating a separate file. This is useful for quick testing.</p><p>To pass parameters as a JSON string, you can use the <code>--parameters</code> or <code>-p</code> flag:</p><pre><code class="language-bash">dsc config --parameters '{"parameters":{"environment":"staging"}}' get --file example-config.dsc.yaml</code></pre><p>If you want to fallback on PowerShell to construct the proper JSON, use:</p><pre><code class="language-powershell"># Create parameters as hashtable and convert to JSON
$inlineParams = @{
    parameters = @{
        environment = 'staging'
        port = 9000
    }
} | ConvertTo-Json -Compress&#10;
# Pass to DSC
dsc config --parameters $inlineParams get --file example-config.dsc.yaml</code></pre><p>As a bonus, you can also pass in YAML with the YaYaml PowerShell module:</p><pre><code class="language-powershell"># Convert parameters to YAML and pass inline
$inlineParams = @{
    parameters = @{
        environment = 'staging'
        port = 9000
        tags = @('web', 'staging')
    }
} | ConvertTo-Yaml&#10;
# Pass YAML string to DSC
dsc config --parameters $inlineParams get --file example-config.dsc.yaml</code></pre><h2 id="method-3-using-stdin-with-pipeline">Method 3: Using STDIN with pipeline</h2><p>DSC allows you to read parameter files from standard input (STDIN). This provides for pipeline scenarios and integration with other tools.</p><p>To read from STDIN, you can use the <code>-</code> as the parameter file path:</p><pre><code class="language-bash">cat parameters.json | dsc config --parameters-file - get --file example-config.dsc.yaml</code></pre><p>If you want to construct it using <strong>PowerShell</strong>, use:</p><pre><code class="language-powershell">$params = @{
    parameters = @{
        environment = 'production'
        port = 443
    }
} | ConvertTo-Json&#10;
$params | Set-Content -Path parameters.json&#10;
Get-Content 'parameters.json' | dsc config --parameters-file - get --file example-config.dsc.yaml</code></pre><p>The same would imply for YAML:</p><pre><code class="language-powershell"># Convert parameters to YAML and pipe to DSC
$params = @{
    parameters = @{
        environment = 'production'
        port = 443
        tags = @('web', 'production')
    }
} | ConvertTo-Yaml&#10;
$params | Set-Content -Path 'parameters.yaml'&#10;
# Pipe YAML file to DSC
Get-Content 'parameters.yaml' | dsc config --parameters-file - get --file example-config.dsc.yaml</code></pre><h2 id="method-4-merging-multiple-parameter-sources">Method 4: Merging multiple parameter sources</h2><p>DSC allows you to merge parameters from multiple sources, with inline parameters taking precedence over parameter files. This enables you to dynamically pass in parameters for complex deployments.</p><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">This feature is currently available as an unofficial release and may change before official release.</div></div><p>To combine a parameter file with inline overrides, use PowerShell:</p><pre><code class="language-powershell"># Base parameters in file
$baseParams = @{
    parameters = @{
        environment = 'production'
        port = 443
        enableSSL = $true
        logLevel = 'info'
    }
} | ConvertTo-Json&#10;
$baseParams | Set-Content -Path 'base-parameters.json'&#10;
# Override specific parameters inline
$overrideParams = @{
    parameters = @{
        port = 8443
        logLevel = 'debug'
    }
} | ConvertTo-Json -Compress&#10;
# Merged result: environment=production, port=8443, enableSSL=true, logLevel=debug
dsc config --parameters-file base-parameters.json --parameters $overrideParams get --file example-config.dsc.yaml</code></pre><p>When merging parameters from multiple sources, DSC will apply the following precedence:</p><ol><li>Inline parameters</li><li>Parameter file</li><li>Default values</li></ol><h2 id="best-practices">Best practices</h2><p>You've learned the mechanics of passing parameters to DSC configurations. Now let's talk about doing it right.</p><p>These aren't theoretical guidelines. They're lessons learned from the field and real deployments. Follow them, and you'll avoid the common pitfalls that make parameter management painful.</p><h3 id="use-parameter-files-for-environment-configuration">Use parameter files for environment configuration</h3><p>Store environment-specific configurations in a separate folder in version control:</p><pre><code class="language-plaintext">parameters/
├── development.json
├── staging.json
└── production.json&#10;
Or:
parameters/
├── development.yaml
├── staging.yaml
└── production.yaml</code></pre><h3 id="leverage-default-values">Leverage default values</h3><p>Provide sensible defaults for parameters that rarely change:</p><pre><code class="language-yaml">parameters:
  logLevel:
    type: string
    defaultValue: info  # Reasonable default
  port:
    type: int
    defaultValue: 8080  # Common default
  environment:
    type: string
    # No default - must be explicitly provided</code></pre><h3 id="validate-with-constraints">Validate with constraints</h3><p>Use constraints to prevent invalid configurations:</p><pre><code class="language-yaml">parameters:
  environment:
    type: string
    allowedValues:
      - development
      - staging
      - production&#10;  
  port:
    type: int
    minValue: 1
    maxValue: 65535&#10;  
  serverName:
    type: string
    minLength: 3
    maxLength: 15</code></pre><h3 id="document-your-parameters">Document your parameters</h3><p>Each parameter declared in your configuration document can be documented using the <code>metadata</code> keyword:</p><pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  environment:
    type: string
    defaultValue: development
    allowedValues:
      - development
      - staging
      - production
    metadata: 
      description: Deployment environment
  port:
    type: int
    defaultValue: 8080
    minValue: 1
    maxValue: 65535
    metadata:
      description: TCP port number for the application
  serverName:
    type: string
    defaultValue: myserver
    minLength: 3
    maxLength: 15
    metadata:
      description: Server hostname or identifier
  enableSSL:
    type: bool
    defaultValue: false
    metadata:
      description: Enable SSL/TLS encryption
  tags:
    type: array
    defaultValue:
      - web
      - production
    minLength: 1
    maxLength: 5
    metadata:
      description: Resource tags for categorization
# truncated</code></pre><h2 id="summary">Summary</h2><p>Microsoft DSC provides flexible methods for passing parameters to configurations. You've learned four methods:</p><ol><li><strong>Parameter files</strong>: Best for environment configurations.</li><li><strong>Inline parameters</strong>:<strong> </strong>Ideal for quick tests.</li><li><strong>STDIN</strong>: Enables pipeline input and integration scenarios.</li><li><strong>Parameter merging</strong>: Combines multiple sources with clear precedence (unofficial).</li></ol><p>Choose the method that best fits your use case, or combine methods for flexibility. The declarative nature of Microsoft DSC configurations, combined with its parameter system, enables reusable configuration management across multiple platforms.</p>
