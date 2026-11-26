---
title: "Your first resource invocation"
status: published
tags: ["The fundamentals of Microsoft DSC"]
published_at: "2025-10-16T04:16:37.000Z"
custom_template: "custom-lesson"
---

<p>You have DSC installed and understand its purpose. Now it's time to put it to use.</p><p>This lesson teaches you to work with DSC resources. You'll explore the <code>Microsoft.Windows/Registry</code> resource. You'll discover its properties and understand the data types associated with them. Then, you'll invoke the resource directly from the command line.</p><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">The <code spellcheck="false" style="white-space: pre-wrap;">Microsoft.Windows/Registry</code> resource works only on Windows systems. If you're on Linux or macOS, don't skip this lesson. The concepts apply to all DSC resources. You can follow along and apply what you learn to resources available on your platform.</div></div><h2 id="exploring-resource-schema">Exploring resource schema</h2><p>You need to know what a resource can do. The schema tells you this. The schema describes the properties and shows the relevant data types. It marks the required properties and the optional ones. It explains what each property does.</p><p>To examine the <code>Microsoft.Windows/Registry</code> schema, run the following command:</p><pre><code class="language-bash">dsc resource schema --resource Microsoft.Windows/Registry</code></pre><p>The command returns a YAML schema document. Here's a truncated version of the key properties:</p><pre><code class="language-yaml">$schema: https://json-schema.org/draft/2020-12/schema
title: Registry
type: object
properties:
  keyPath:
    description: The path to the registry key.
    type: string
  _metadata:
    description: The information from a config set --what-if operation.
    anyOf:
    - $ref: '#/$defs/Metadata'
    - type: 'null'
  valueName:
    description: The name of the registry value.
    type:
    - string
    - 'null'
  valueData:
    description: The data of the registry value.
    anyOf:
    - $ref: '#/$defs/RegistryValueData'
    - type: 'null'
  _exist:
    type:
    - boolean
    - 'null'
additionalProperties: false
required:
- keyPath</code></pre><p>The schema shows you four things:</p><ul><li><code>keyPath</code> is required. It must be a string. This is the registry path.</li><li><code>valueName</code> is optional. It can be a string or null. This is the value name within the key.</li><li><code>valueData</code> holds the actual data you want to set. It references the <code>RegistryValueData</code> definition.</li><li><code>_exist</code> determines if the key exists. It returns a boolean or null value.</li></ul><p>Don't worry if the full schema seems overwhelming at first. The complete schema includes many technical details about type definitions and validation rules. You don't need to understand every line at this moment. The key is knowing which properties you can use and what they do. As you work with the resource, the schema will make more sense.</p><p>The best way to learn is through hands-on experience. Let's start using the resource.</p><h2 id="working-with-the-dsc-resource-command">Working with the <code>dsc resource</code> command</h2><p>The <code>dsc resource</code> command works with individual resources. You don't need a full configuration document at this point. Running the <code>dsc resource &lt;operation&gt;</code> command is perfect for learning and testing.</p><p>The command supports several operations:</p><ul><li><strong>list</strong> – List or find resources available on your system.</li><li><strong>get</strong> – Invoke the get operation to retrieve the current state.</li><li><strong>test</strong> – Invoke the test operation to check if state matches desired state.</li><li><strong>set</strong> – Invoke the set operation to apply the desired state.</li><li><strong>delete</strong> – Invoke the delete operation to remove a resource instance.</li><li><strong>export</strong> – Retrieves all resource instances from your system.</li></ul><p>Each operation serves a purpose. This lesson will focus on the three most common operations, as well as a new one (<code>delete</code>). These form the core workflow for managing resources.</p><h3 id="get-the-current-state">Get the current state</h3><p>To check if a registry key exists and retrieve its current values, use the <code>get</code> operation. You provide the resource properties as JSON input.</p><p>Here's how to check the current state of a registry key:</p><pre><code class="language-powershell"># Build JSON from hashtable
$in = @{
    keyPath = 'HKLM\Software\Microsoft\Windows\CurrentVersion'
    valueName = 'ProgramFilesDir'
} | ConvertTo-Json -Compress
dsc resource get -r Microsoft.Windows/Registry -i $in
</code></pre><p>This command:</p><ol><li>Creates a compressed JSON string with the registry path and value name.</li><li>Specifies the short alias resource type <code>-r</code>.</li><li>Adds the input content to the short alias <code>-i</code>.</li></ol><p>The output shows the current state:</p><pre><code class="language-yaml">actualState:
  keyPath: HKLM\Software\Microsoft\Windows\CurrentVersion
  valueName: ProgramFilesDir
  valueData:
    String: C:\Program Files</code></pre><p>Notice the <code>valueData</code> field. It includes the data type and the actual value.</p><h3 id="testing-the-desired-state">Testing the desired state</h3><p>Before making changes, you may want to check if the system is already in the desired state. Does a registry value already match what you want?</p><p>The <code>test</code> operation answers this question. To test if a custom registry value already exists, run the following:</p><pre><code class="language-powershell">$in = @{
    keyPath = 'HKCU\Software\MyApplication'
    valueName = 'ConfigPath'
    valueData = @{
        String = 'C:\MyApp\config.json'
    }
} | ConvertTo-Json -Depth 3 -Compress
dsc resource test -r Microsoft.Windows/Registry -i $in
</code></pre><p>The output tells you whether the current state matches the desired state:</p><pre><code class="language-yaml">desiredState:
  keyPath: HKCU\Software\MyApplication
  valueData:
    String: C:\MyApp\config.json
  valueName: ConfigPath
actualState:
  keyPath: HKCU\Software\MyApplication
  _exist: false
inDesiredState: false
differingProperties:
- valueData
- valueName
- _exist</code></pre><p>The output shows you three important things:</p><ul><li><code>inDesiredState: false</code> tells you the truth. The registry value doesn't match your desired configuration</li><li><code>differingProperties</code> list exactly which properties don't match. In this case, <code>valueData</code>, <code>valueName</code>, and <code>_exist</code> all differ. This helps you understand what needs to change.</li></ul><p>The key doesn't exist yet. That's why <code>_exist</code> is false, and the other properties are missing from the actual state.</p><h3 id="setting-the-desired-state">Setting the desired state</h3><p>You've tested the configuration. You know it doesn't match, so you want to fix that. The <code>set</code> operation applies your desired state. It <em>makes</em> the changes happen.</p><p>To <code>set</code> the previous example, change the <code>test</code> operation to <code>set</code>:</p><pre><code class="language-powershell">$in = @{
    keyPath = 'HKCU\Software\MyApplication'
    valueName = 'ConfigPath'
    valueData = @{
        String = 'C:\MyApp\config.json'
    }
} | ConvertTo-Json -Depth 3 -Compress
dsc resource set -r Microsoft.Windows/Registry -i $in</code></pre><p>The command will create the registry key if needed. It sets the value. The output shows two states. Before and after:</p><pre><code class="language-yaml">beforeState:
  keyPath: HKCU\Software\MyApplication
  _exist: false
afterState:
  keyPath: HKCU\Software\MyApplication
  valueName: ConfigPath
  valueData:
    String: C:\MyApp\config.json
changedProperties:
- valueName
- valueData
- _exist</code></pre><p>The output confirms the change. The <code>beforeState</code> shows the key didn't exist. The <code>afterState</code> shows it now exists with the correct values. The <code>changedProperties</code> array lists exactly what changed. You have now successfully created a registry key.</p><p>Before closing the lesson, let's review the registry value types and examine one more practical example.</p><h2 id="understanding-registry-value-types">Understanding registry value types</h2><p>When you've worked with the registry before, you know it supports multiple value types. When you work with the <code>valueData</code> property, you need to specify the correct type. This type matters; otherwise, the underlying DSC Resource fails. </p><p>Here's a table representing each value type:</p><table>
<thead>
<tr>
<th>Type</th>
<th>JSON Property</th>
<th>Example</th>
<th>Use Case</th>
</tr>
</thead>
<tbody>
<tr>
<td>String</td>
<td><code>String</code></td>
<td><code>"C:\Path"</code></td>
<td>Text values, paths</td>
</tr>
<tr>
<td>DWord</td>
<td><code>DWord</code></td>
<td><code>1</code></td>
<td>32-bit numbers, flags</td>
</tr>
<tr>
<td>QWord</td>
<td><code>QWord</code></td>
<td><code>12345678</code></td>
<td>64-bit numbers</td>
</tr>
<tr>
<td>Binary</td>
<td><code>Binary</code></td>
<td><code>[0, 255, 128]</code></td>
<td>Binary data as byte array</td>
</tr>
<tr>
<td>MultiString</td>
<td><code>MultiString</code></td>
<td><code>["value1", "value2"]</code></td>
<td>Lists of strings</td>
</tr>
<tr>
<td>ExpandString</td>
<td><code>ExpandString</code></td>
<td><code>"%SystemRoot%\System32"</code></td>
<td>Strings with environment variables</td>
</tr>
</tbody>
</table>
<p>So, let's say you want to use a <code>DWord</code> value. Here is an example using a <code>DWord</code> value type:</p><pre><code class="language-powershell">$in = @{
    keyPath = 'HKCU\Software\MyApplication'
    valueName = 'MaxConnections'
    valueData = @{
        DWord = 100
    }
} | ConvertTo-Json -Depth 3
dsc resource set -r Microsoft.Windows/Registry -i $in</code></pre><h2 id="practical-example-application-configuration">Practical example: Application configuration</h2><p>Imagine the following. You deploy an application. It stores configuration data in the registry. You need three things:</p><ol><li>Check if the configuration already exists.</li><li>Create it if it doesn't.</li><li>Verify if it was created correctly.</li></ol><p>Let's go through the steps once again.</p><h3 id="step-1-%E2%80%93-check-the-current-state">Step 1 – Check the current state</h3><p>First, you'll fetch the current state to <em>check if the configuration already exists</em>:</p><pre><code class="language-powershell">$check = @{
    keyPath = 'HKCU\Software\MyApp\Settings'
    valueName = 'DatabasePath'
} | ConvertTo-Json -Compress
dsc resource get -r Microsoft.Windows/Registry -i $check</code></pre><p>If <code>_exist</code> equals <code>false</code>, the <code>valueName</code> does not exist. </p><h3 id="step-2-%E2%80%93-set-the-configuration">Step 2 – Set the configuration</h3><p>When you verified that the current state does not exist, you can set the configuration:</p><pre><code>$config = @{
    keyPath = 'HKCU\Software\MyApp\Settings'
    valueName = 'DatabasePath'
    valueData = @{
        String = 'C:\ProgramData\MyApp\database.db'
    }
} | ConvertTo-Json -Depth 3 -Compress
dsc resource set -r Microsoft.Windows/Registry -i $config</code></pre><p>This will create the registry key <code>DatabasePath</code> with the value data provided to the registry.</p><h3 id="step-3-%E2%80%93-verify-the-configuration">Step 3 – Verify the configuration</h3><p>Now that the configuration is set, you can verify it by running <code>dsc resource test</code>:</p><pre><code class="language-powershell">$verify = @{
    keyPath = 'HKCU\Software\MyApp\Settings'
    valueName = 'DatabasePath'
    valueData = @{
        String = 'C:\ProgramData\MyApp\database.db'
    }
} | ConvertTo-Json -Depth 3 -Compress&#10;
$result = dsc resource test -r Microsoft.Windows/Registry -i $verify
$result | ConvertFrom-Json | Select-Object -ExpandProperty inDesiredState</code></pre><p>In the above snippet, we transform the result into rich PowerShell objects, allowing us to search through the properties. We know that the <code>inDesiredState</code> tells us if the system is in its desired state. Because you've run the set, this result should be <code>True</code>.</p><h2 id="key-takeaways">Key takeaways</h2><p>Before you proceed further in the course, remember the following concepts:</p><ul><li>Use <code>dsc resource list</code> to discover resources on your system.</li><li>Use <code>dsc resource schema</code> to understand resource properties.</li><li>Use <code>dsc resource get</code> to check the current state without making changes.</li><li>Use <code>dsc resource test</code> to verify if the current state matches the desired state.</li><li>Use <code>dsc resource set</code> to apply the desired state.</li></ul><p><strong>Always<em> </em></strong>pay attention to what data types are expected for the properties.</p><h2 id="wrap-up">Wrap up</h2><p>You now understand how to work with individual resources. The skills you've learned here matter. Discovering schemas. Understanding properties. Using the <code>dsc resource</code> command. These form the foundation. Everything you do with <code>dsc</code> builds on this.</p><p>Before you finish up this module, it's time to practice and explore in the next lesson.</p><p></p>
