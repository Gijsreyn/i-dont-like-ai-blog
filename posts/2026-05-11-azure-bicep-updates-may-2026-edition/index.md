---
title: "Azure Bicep Updates — May 2026 Edition"
status: published
tags: ["Bicep", "Azure"]
published_at: "2026-05-11T06:02:42.000Z"
feature_image: "images/cover.jpg"
---

<p>The months are passing by this year, and we're already in May 2026. If you expected one release to land, you might be disappointed. Because actually, it was two!</p><p>The last release (v0.43.8) reverted one of the GA functionality <code>retryOn</code> because the backend changes against ARM weren't ready yet. Regardless, the team was able to push in two changes during this release, which will be covered later.</p><p>Besides the new <code>retryOn</code> decorator, this release was also packed with other features:</p><ul><li>Two new functions you can use on resources.</li><li>Two new linter rules added.</li><li>One breaking change for Azure Container Registries (ACRs).</li><li>Richer output on <code>snapshot</code> command and another parameter added.</li></ul><p>Let's get into it.</p><h2 id="another-operation-is-in-progress">Another operation is "in progress"</h2><p>In 2020, a user named rshariy created the <a href="https://github.com/Azure/bicep/issues/1013">Add "wait" and "retry" deployment options</a> issue on GitHub. A clear description was given, and a ton of responses came along.</p><p>Now, the team has finally released something for it: the <code>retryOn</code> decorator. This decorator is quite simple and accepts one required parameter and one optional parameter. The first argument is the specific <em>error code</em> you want to retry on, and the second one will be how many times:</p><pre><code class="language-bicep">@retryOn(['&lt;errorCode&gt;'], &lt;retryTimes&gt;)</code></pre><p>There are probably multiple ways to get the specific error code, but the two most useful are the already <a href="https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/common-deployment-errors">available list</a> or using the method described <a href="https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/find-error-code?tabs=azure-portal">here</a>.</p><p>I could have posted a rough example of how you could use it on several resources, but if you go to the link above on the GitHub issue, you'll find plenty of them (or you encountered one already yourself).</p><h2 id="easier-array-and-string-expressions">Easier array and string expressions</h2><p>The next addition in line are not the kind of features that make you rewrite an entire template. Instead, they're the kind of functions you start using once you know they exist. Bicep v0.43.1 added <code>like()</code> and <code>distinct()</code>.</p><p>The <code>like()</code> function is used for pattern matching on strings, and yes, it does support the <code>*</code> wildcard. This is useful when you have established a naming convention, for example, in Azure. If all your production workloads start with <code>prod-</code>, you can use that directly in your template instead of passing another boolean parameter. More on that later.</p><p>Then the <code>distinct()</code> function does what the name already says: it returns a new array with duplicate values removed. The nice part about the function is the fact that it keeps the first occurrence order. You can use this function to generate resource child objects from arrays. Take IP rules, alert receivers, tags, or role assignments as an example for this. </p><p>To put it more in perspective, let's take a real-world example. Imagine you deploy storage accounts from a shared module. You know that storage accounts in production should get zone-redundant storage, while non-production storage accounts should stay locally redundant. You also want to remove duplicates from an allowed IP list, as these might come from different teams:</p><pre><code class="language-bicep">param location string = resourceGroup().location
param workloadName string&#10;
param allowedIpAddresses array = [
	'203.0.113.10'
	'198.51.100.25'
	'203.0.113.10'
]&#10;
var isProduction = like(workloadName, 'prod-*')
var uniqueAllowedIpAddresses = distinct(allowedIpAddresses)&#10;
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
	name: '${replace(workloadName, '-', '')}st001'
	location: location
	sku: {
		name: isProduction ? 'Standard_ZRS' : 'Standard_LRS'
	}
	kind: 'StorageV2'
	properties: {
		minimumTlsVersion: 'TLS1_2'
		allowBlobPublicAccess: false
		publicNetworkAccess: 'Enabled'
		networkAcls: {
			defaultAction: 'Deny'
			bypass: 'AzureServices'
			ipRules: [for ipAddress in uniqueAllowedIpAddresses: {
				action: 'Allow'
				value: ipAddress
			}]
		}
	}
}&#10;
output productionWorkload bool = isProduction
output configuredIpRules array = uniqueAllowedIpAddresses</code></pre><p>If you established that Azure naming convention, you notice when <code>workloadName</code> containing <code>prod-</code>, will get the <code>Standard_ZRS</code> SKU. <code>Standard_LRS</code> is set when <code>dev-</code> is found. And even though you added <code>203.0.113.10</code> twice, the generated storage account only received it once in the <code>ipRules</code> collection.</p><p>Small functions, but practical in nature.</p><h2 id="better-guardrails-before-you-hit-deploy">Better guardrails before you hit deploy</h2><p>One thing I liked in this release is that it added not only new syntax. It added a couple of new guardrails around the authoring experience. Two new rules were introduced.</p><p>The first new rule is <code>use-recognized-resource-type</code>. It might not be an obvious one, but it focuses on the underlying <code>reference()</code> ARM function. With this rule, Bicep validates the resource type string you pass in against its built-in Azure type registry. If it's not found, the rule is fired upon.</p><p>An obvious example is a typo. Take the following example:</p><pre><code class="language-bicep">param storageAccountName string&#10;
output keys object = listKeys(resourceId('Microsoft.Storage/storageAcounts', storageAccountName), '2025-08-01')</code></pre><p>For the sharp eyes amongst us, the <code>storageAcounts</code> is spelled wrong. The rule catches this early. But there's also a less obvious situation. That situation will be custom or private resource types.</p><p>Organizations can register extension resources or use types that are not part of the standard Azure resource provider set. Bicep will not know about them. The rule will warn on those as well, even though the usage is correct. Keep this in mind when you configure this rule.</p><p>The second rule is <code>no-module-name</code> and if you've followed the Bicep releases lately, you going to love this new linting rule. See, explicit module names aren't needed anymore, but many often still copy-paste them. For example, this pattern that might be copied can now be flagged by this rule:</p><pre><code class="language-bicep">module networking './modules/networking.bicep' = {
	name: 'networking'
	params: {
		location: resourceGroup().location
	}
}</code></pre><p>The new preferred version is a little simpler:</p><pre><code class="language-bicep">module networking './modules/networking.bicep' = {
	params: {
		location: resourceGroup().location
	}
}</code></pre><p>Now, before moving on to the next section, I have already covered the new command in the previous edition (<code>snapshot</code>). In this release, the command became richer.</p><p>First, as already mentioned in the introduction, the output from the snapshot becomes more predictable. Having a predictable output can help you not only in reviewing, but also in the values in later stages if you deploy through a DevOps pipeline.</p><p>What happens now is that Bicep resolves whatever it can at compile time and keeps the rest as ARM expressions. This template with four outputs will resolve:</p><pre><code class="language-bicep">output storageAccountType string = storageAccountType
output blobUri string = sa.properties.primaryEndpoints.blob
output objectWithExpressions object = {
  foo: 'bar'
  baz: 123
  qux: sa.properties.primaryEndpoints.blob
}
output objectLiteral object = {
  storageAccountType: storageAccountType
  baz: 123
}</code></pre><p>Produces this snapshot as JSON:</p><pre><code class="language-json">"outputs": {
  "storageAccountType": "Standard_LRS",
  "blobUri": "[reference('...storageAccounts/storejs26ofeqkqeve', '2022-09-01').primaryEndpoints.blob]",
  "objectWithExpressions": "[createObject('foo', 'bar', 'baz', 123, 'qux', reference(...).primaryEndpoints.blob)]",
  "objectLiteral": {
    "storageAccountType": "Standard_LRS",
    "baz": 123
  }
}</code></pre><p>This is, of course, what Bicep can predict. </p><p>Better yet, the second thing the snapshot command gets is a management group ID parameter. That's helpful for platform engineering teams managing management groups to subscription level. Take an example when assigning a policy:</p><pre><code class="language-bicep">targetScope = 'managementGroup'&#10;
param policyAssignmentName string
param policyDefinitionId string&#10;
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
	name: policyAssignmentName
	properties: {
		policyDefinitionId: policyDefinitionId
	}
}&#10;
output policyAssignmentId string = policyAssignment.id</code></pre><p>Then you can generate a snapshot with:</p><pre><code class="language-bicep">bicep snapshot main.bicepparam --mode overwrite --management-group-id platform --location westeurope</code></pre><p>That will give you a much better reviewable artifact. Combining that with the predicted output gives you output values that can be handed off later.</p><h2 id="only-know-registries-please">Only know registries, please</h2><p>This release also includes a breaking change. That breaking change is related to where Bicep modules can be restored from. Bicep now enforces a <em>trusted registry list</em> when restoring OCI modules. If it's not on that list, the restore is <strong>blocked, </strong>and you get a <strong>BCP446 </strong>error.</p><p>What are the trusted registries? Currently, these are the built-in ones:</p><ul><li><code>*.azurecr.io</code></li><li><code>*.azurecr.cn</code> and <code>*.azurecr.us</code></li><li><code>mcr.microsoft.com</code> and <code>mcr.azure.cn</code></li><li><code>ghcr.io</code></li></ul><p>Personally, I don't think many people are affected by this change. Only when you use a custom domain for Azure Container Registry endpoints, because those support mapping to your own domain name. So, imagine you have a module reference like <code>br:moduleStore.myCompany.com/networking/hub:1.0.0</code>, you're going to be impacted by the change. You've got to change up the part <code>myCompany.com</code> to <code>.azurecr.io</code>.</p><p>If you're not sure what the login server is for a registry, you can use Azure PowerShell for it:</p><pre><code class="language-powershell"># Requires Az.ContainerRegistry
$registry = Get-AzContainerRegistry -ResourceGroupName &lt;resourceGroupName&gt; -Name &lt;registryName&gt;&#10;
$registry.LoginServer</code></pre><h2 id="conclusion">Conclusion</h2><p>It's good to see that there are always steps taken to improve the security posture, even though it's a breaking change. Also, having those new guardrails in place and a better experience on the snapshot command makes the overall product just a little gentler to use.</p><p>To see the full release notice, I would recommend taking a look at the <a href="https://github.com/Azure/bicep/releases/tag/v0.43.1">v0.43.1 </a>release, which contains most of the new functionality, bug fixes, and improvements. </p>
