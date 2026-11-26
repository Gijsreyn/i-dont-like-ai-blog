---
title: "Deploying Bicep from Azure DevOps with the new BicepDeploy@0 task"
status: published
tags: ["Bicep", "Azure DevOps"]
published_at: "2026-06-18T05:34:36.000Z"
custom_excerpt: "No more Azure CLI, Azure PowerShell, or ARM task"
feature_image: "images/2026-06-kRTsElPhHJ93rU9T.png"
---

<p>For a long time, deploying Bicep through Azure DevOps wasn't a clear choice. You could use the <a href="https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/azure-resource-group-deployment-v2?view=azure-pipelines">Azure resource group deployment task</a>. You could have created something custom with the Azure CLI. Or you used a combination with the Azure PowerShell task and used the available PowerShell commands.</p><p>All of those solutions work. But they don't quite feel like a <em>native </em>Bicep experience. That finally changed.</p><p>A few months ago, the Bicep team already introduced a GitHub Actions experience for Bicep deployment. After that was released, you saw it already coming that another request for Azure DevOps landed.</p><p>Now, if you looked at the recent <a href="https://youtu.be/0tyg60UD0o0?si=F3JfsfV77fi7aXKj&amp;t=1033">Bicep community call</a>, I was happy to see Sneha Bandla present the new native task <code>BicepDeploy@0</code>. The task can work directly with <code>.bicep</code> or <code>.bicepparam</code> files, install and cache the Bicep CLI version, and run validation operations (including <code>what-if</code>). </p><p>In this post, you will see where <code>BicepDeploy@0</code> fits, what problem it solves, and how to start using it in an Azure DevOps pipeline.</p><h2 id="a-quick-look-at-bicep-deploy">A quick look at Bicep Deploy</h2><p>Before looking at the new task, it's good to look back a bit. The Bicep CLI has always been laid-back when it comes to deployment automation. Yes, the language is a first-class citizen to ARM, but the deployment command came from somewhere else. As mentioned in the introduction, you used the Azure CLI with commands such as <code>az deployment group create</code> or <code>az deployment sub create</code>. The same would be applicable for Azure PowerShell (<code>New-AzResourceGroupDeployment</code> or <code>New-AzSubscriptionDeployment</code>.</p><p>Those commands deploy Bicep just fine, but the pipeline still requires some customization inside scripts. Think about which scope your Bicep file requires to land, how parameters are passed in, or how you invoke what-if if you needed it.</p><p>Then, the groundwork formed. In <a href="https://github.com/Azure/bicep/releases/tag/v0.38.3">v0.38.3</a>, the <code>bicep deploy</code> command was introduced. And that work led to a better deploy experience natively from the CLI itself. Instead of compiling <code>.bicep</code> files to ARM, the pipeline can describe a Bicep deployment directly. That would mean:</p><ul><li>Here you have the template</li><li>These are the parameters</li><li>This is the scope</li><li>And this is the Bicep version I want</li></ul><p>For DevOps pipelines, this matters a lot because local commands are usually easy to implement and fix.</p><h2 id="why-use-bicepdeploy0">Why use BicepDeploy@0?</h2><p>You can already guess why you should use <code>BicepDeploy@0</code>: it just removes the glue code you've been (probably) doing for years.</p><p>Take, for example, a typical Azure DevOps pipeline where you use the Azure CLI task:</p><pre><code class="language-yaml">- task: AzureCLI@2
  displayName: Deploy Bicep template
  inputs:
    azureSubscription: &lt;azureSubscription&gt;
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      az deployment group create \
        --resource-group my-resource-group \
        --template-file infra/main.bicep \
        --parameters infra/main.bicepparam</code></pre><p>Or for Azure PowerShell:</p><pre><code class="language-yaml">- task: AzurePowerShell@5
  displayName: Deploy Bicep template
  inputs:
    azureSubscription: &lt;azureSubscription&gt;
    ScriptType: InlineScript
    Inline: |
      New-AzResourceGroupDeployment `
        -ResourceGroupName 'my-resource-group' `
        -TemplateFile 'infra/main.bicep' `
        -TemplateParameterFile 'infra/main.bicepparam'
    azurePowerShellVersion: LatestVersion</code></pre><p>Everyone deploying Bicep files should be familiar with the above examples. But they push deployment behavior into scripts. Now, the scope above is for a resource group. The pipeline author has to know the <em>right </em>command for every scope. And that should further translate into pipeline inputs.</p><p>With the new <code>BicepDeploy@0</code> task, the same deployment becomes a task configuration:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  displayName: Deploy Bicep template
  inputs:
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: my-resource-group
    templateFile: infra/main.bicep
    parametersFile: infra/main.bicepparam</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">By default, the <code spellcheck="false" style="white-space: pre-wrap;">scope</code> is <code spellcheck="false" style="white-space: pre-wrap;">resourceGroup</code>, thus omitted from the above code snippet. Other scopes, such as subscriptions, tenants, or management groups, are also supported.</div></div><p></p><p>With the task defined, it isn't hidden in a shell script. It just says what it is going to do through Bicep-specific task inputs.</p><h2 id="pin-the-bicep-version">Pin the Bicep version</h2><p>I hadn't even shown the Bicep version in the previous section, but that was explicitly left out because that's something you've to do as well. And many folks complained about it.</p><p>The Bicep CLI isn't installed on all runners, let alone when you host your own. Most of the time, you would just install the <em>latest </em>Bicep CLI version on your agent, and sometimes, this would break.</p><p>One of the more practical inputs to solve it easily now is to specify the <code>bicepVersion</code> in the <code>BicepDeploy@0</code> task:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  displayName: Deploy with pinned Bicep version
  inputs:
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: my-resource-group
    templateFile: infra/main.bicep
    parametersFile: infra/main.bicepparam
    bicepVersion: 0.38.5</code></pre><p>This automatically solves the installation step. I also prefer to pin versions deliberately, especially in important pipelines I'm running. </p><h2 id="validate-and-preview-before-you-deploy">Validate and preview before you deploy</h2><p>The other benefit of using this task is the fact that you can run two different operations to validate and preview by using <code>validate</code> or <code>whatIf</code>.</p><p>To insert a validation step early in the pipeline, you could use something like this:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  displayName: Validate Bicep template
  inputs:
    operation: validate
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: my-resource-group
    templateFile: infra/main.bicep
    parametersFile: infra/main.bicepparam
    validationLevel: providerNoRbac</code></pre><p>If the template is correct, you can do a what-if step afterward before actually applying the infrastructure:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  displayName: Preview Bicep changes
  inputs:
    operation: whatIf
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: my-resource-group
    templateFile: infra/main.bicep
    parametersFile: infra/main.bicepparam
    whatIfExcludeChangeTypes: noChange</code></pre><p>You can choose the validation level for deployment validate and what-if operations. The task supports <code>provider</code>, <code>template</code>, and <code>providerNoRbac</code>, which gives you a way to tune how deep validation should go for the environment and permissions available to that pipeline.</p><h2 id="using-deployment-stacks">Using deployment stacks</h2><p>The other big reason to pay attention to this task is the support for deployment stacks.</p><p>In short, deployment stacks let Azure track the resources managed by a deployment and define what should happen when resources are no longer present in the template. </p><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">For more information on deployment stacks, check out the <a href="https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell">article on Microsoft Learn</a>.</div></div><p></p><p>With <code>BicepDeploy@0</code>, you can set <code>type</code> to <code>deploymentStack</code> and configure those options:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  displayName: Deploy production stack
  inputs:
    type: deploymentStack
    operation: create
    name: production-stack
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: production-rg
    templateFile: infra/main.bicep
    parametersFile: infra/production.bicepparam
    actionOnUnmanageResources: delete
    denySettingsMode: denyWriteAndDelete</code></pre><p>If you want to go for a safer option first, start with <code>actionOnUnmanageResource: detach</code>. This just keeps the resources alive in Azure, but it isn't managed by the stack anymore.</p><p>There are additional stack-specific inputs. However, these are perfectly described in the article on Microsoft Learn. The important point is that those are task inputs now, rather than creating something custom (again).</p><h2 id="capture-outputs-for-later-steps">Capture outputs for later steps</h2><p>Capturing outputs is another place where <code>BicepDeploy@0</code> shines compared to the older script-based approach. Take Azure PowerShell. Typically, you caputre the deployment result and walk through the <code>Outputs</code> object yourself:</p><pre><code class="language-yaml">- task: AzurePowerShell@5
  name: deploy
  displayName: Deploy infrastructure
  inputs:
    azureSubscription: &lt;azureSubscription&gt;
    ScriptType: InlineScript
    Inline: |
      $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName 'my-resource-group' `
        -TemplateFile 'infra/main.bicep'&#10;
      foreach ($output in $deployment.Outputs.GetEnumerator()) {
        Write-Host "##vso[task.setvariable variable=$($output.Key);isOutput=true]$($output.Value.Value)"
      }
    azurePowerShellVersion: LatestVersion</code></pre><p>With the <code>BicepDeploy@0</code>, Bicep's output just becomes part of the pipeline variables for later usage. You just have to give the step a <code>name</code> and you can reference it later:</p><pre><code class="language-yaml">- task: BicepDeploy@0
  name: deploy
  displayName: Deploy infrastructure
  inputs:
    azureResourceManagerConnection: &lt;azureSubscription&gt;
    subscriptionId: $(subscriptionId)
    resourceGroupName: my-resource-group
    templateFile: infra/main.bicep&#10;
- task: PowerShell@2
  displayName: Use deployment outputs
  inputs:
    targetType: inline
    script: |
      Write-Host "Storage Account Name: $(deploy.storageAccountName)"
      Write-Host "Web App URL: $(deploy.webAppUrl)"</code></pre><p>If your template emits sensitive values, use <code>maskedOutputs</code> to list outputs that should be masked in logs.</p><h2 id="when-to-replace-existing-tasks">When to replace existing tasks</h2><p>Don't worry. You don't need to rewrite every pipeline immediately. If a pipeline has a lot of custom logic around deployment, you're going to need to translate that context. </p><p>But for straightforward Bicep deployments you've seen in this article, <code>BicepDeploy@0</code> is a better default than a generic ARM deployment task (or <code>az</code> and <code>New-Az</code> command).</p><p>I would start with new pipelines first. Use the native task, templatize it so you can have different inputs for different use cases, and choose deployment stacks when you're ready for it.</p><p>Then look at existing pipelines that mostly wrap <code>az deployment</code> or <code>New-*AzDeployment</code> code. Those are going to be good candidates for migration.</p><h2 id="conclusion">Conclusion</h2><p>This new <code>BicepDeploy@0</code> task for Azure DevOps helps you to define a more direct way to describe Bicep deployment, just as it did for GitHub Actions. </p><p>You can point it at <code>.bicep</code> and <code>.bicepparam</code> files, pick your operation with scope, and don't forget to pin the Bicep CLI version. That's what I like about this new task. Fewer parts to move in every pipeline, including clearer intent in YAML. And finally, Bicep became a first-class citizen for deployments.</p><p>For the full documentation on the task, head to this <a href="https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/bicep-deploy-v0?view=azure-pipelines">link</a>.</p>
