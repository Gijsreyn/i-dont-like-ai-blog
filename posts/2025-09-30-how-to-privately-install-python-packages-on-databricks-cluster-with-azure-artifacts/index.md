---
title: "How to privately install Python packages on Databricks cluster with Azure Artifacts"
status: published
tags: ["Azure DevOps", "Databricks"]
published_at: "2025-09-30T05:23:54.000Z"
custom_excerpt: "Learn how you can privately install Python packages on your Databricks clusters"
feature_image: "images/2025-09-install-databricks-private-package.png"
feature_image_alt: "Privately install Python packages on Databricks"
---

<p>Are your Python dependencies secure? Do your compliance requirements prevent you from using public repositories for installing dependencies?</p><p>While NPM is a different ecosystem, <a href="https://securelist.com/shai-hulud-worm-infects-500-npm-packages-in-a-supply-chain-attack/117547/">recent events</a> highlighted once again the importance of carefully downloading and installing packages you rely on. One wrong package can compromise your enterprise.</p><p>As workspace admins, you want to ensure that users using your Databricks instance default to installing privately. If they want to install from PyPI.org explicitly, they should still be allowed to do so (there are other methods to close this off).</p><p>In this tutorial, you will learn how to connect to Azure Artifacts to install Python packages privately. </p><h2 id="prerequisites">Prerequisites</h2><p>Assuming you want to follow along, you're going to need:</p><ul><li>An Azure DevOps Services account.</li><li>A running Databricks instance.</li><li>The Databricks CLI v0.264.0 or above.</li></ul><h2 id="step-1set-up-azure-artifacts">Step 1 - Set up Azure Artifacts</h2><p>To be able to download and install Python packages from Azure Artifacts, you first need one. </p><ol>
<li>
<p>Go to <a href="https://dev.azure.com/">https://dev.azure.com/</a><organizationname>.</organizationname></p>
</li>
<li>
<p>Select the project you want to work in.</p>
</li>
<li>
<p>In the left navigation, select <strong>Artifacts</strong>.</p>
<p><img src="images/2025-09-select-artifact.png" alt="select-artifact.png" loading="lazy"></p>
</li>
<li>
<p>If this is your first feed, select <strong>Create Feed</strong>. Otherwise, select + New Feed.</p>
<p><img src="images/2025-09-create-artifact.png" alt="create-artifact.png" loading="lazy"></p>
</li>
<li>
<p>Enter a <strong>Name</strong> for the feed (for example, PrivatePython).</p>
</li>
<li>
<p>(Optional) Provide a Description to help other users understand the purpose of this feed.</p>
</li>
<li>
<p>Under <strong>Visibility</strong>, choose one of the following:</p>
<ul>
<li>Organization – allow all members of the organization to use the feed.</li>
<li>Project – restrict access to the current project.</li>
<li>Specific people or groups – grant access only to selected users.</li>
</ul>
</li>
<li>
<p>Leave the <strong>Upstream sources</strong> to allow packages to flow from external registries (in this case, PyPI.org).</p>
</li>
<li>
<p>Select <strong>Create</strong>.</p>
</li>
</ol>
<p>You have now successfully created an Azure Artifacts feed. We purposely left the "Upstream sources" enabled, even though it still goes to an open-source repository. This is for demo purposes to illustrate it downloads packages <em>through</em> Azure Artifacts.</p><h2 id="step-2upserting-the-credential-scope-and-secret">Step 2 - Upserting the credential scope and secret</h2><p>By default, users who want Python packages installed should always go to the private repository, unless they explicitly don't specify the <code>--index-url</code>. You, as workspace admin, can therefore set two important values in the instance:</p><ul><li>A Databricks secret scope named <code>databricks-package-management</code>.</li><li>A secret key linked to the scope with the name: <code>pip-index-url</code>.</li></ul><p>When both values are set, each cluster that is spawned will use the configured settings.</p><ol>
<li>
<p><strong>Create a Personal Access Token (PAT)</strong> in Azure DevOps:</p>
<ol>
<li>Go to <code>https://dev.azure.com/&lt;organizationName&gt;</code>.</li>
<li>In the upper-right corner, select your profile picture and then select <strong>Security</strong>.</li>
<li>Under <strong>Personal Access Tokens</strong>, select <strong>+ New Token</strong>.</li>
<li>Enter a <strong>Name</strong> (for example, <code>artifacts-python</code>).</li>
<li>Set the <strong>Organization</strong> to your Azure DevOps organization.</li>
<li>Set the <strong>Expiration</strong> to a suitable period (for example, 30 or 90 days, depending on your compliance policy).</li>
<li>Under <strong>Scopes</strong>, select <strong>Packaging (Read)</strong>.</li>
<li>Select <strong>Create</strong> and copy the PAT value. You will use this in later steps.</li>
</ol>
</li>
<li>
<p><strong>Authenticate with Databricks CLI</strong> (if not already logged in):</p>
<pre><code class="language-bash">databricks auth login
</code></pre>
</li>
<li>
<p>Create <strong>a secret scope</strong> in Databricks for package management:</p>
<pre><code class="language-bash">databricks secrets create-scope databricks-package-management
</code></pre>
</li>
<li>
<p><strong>Configure access control lists (ACLs)</strong> for the scope:</p>
<pre><code class="language-bash">databricks secrets put-acl databricks-package-management admins MANAGE
databricks secrets put-acl databricks-package-management users READ
</code></pre>
</li>
<li>
<p>Store the <strong>private index URL</strong> as a secret. Replace <index-url-value> with the full <strong>Azure Artifacts Python feed URL</strong>, including your PAT token.</index-url-value></p>
<pre><code class="language-bash">databricks secrets put-secret --json '{"scope": "databricks-package-management", "key": "pip-index-url", "string_value":"&lt;index-url-value&gt;"}'
</code></pre>
<p>Example format for the value:</p>
<pre><code class="language-bash">https://&lt;username&gt;:&lt;pat-token&gt;@pkgs.dev.azure.com/&lt;organizationName&gt;/&lt;projectName&gt;/_packaging/&lt;feedName&gt;/pypi/simple/
</code></pre>
</li>
</ol>
<p>At this point, you have securely stored the package index URL and credentials in Databricks. Your users won’t need to specify manually <code>--index-url</code> or <code>--extra-index-url</code> when installing packages.</p><figure class="kg-card kg-image-card"><img src="images/2025-09-image-5.png" class="kg-image" alt="" loading="lazy" width="1233" height="179"></figure><h2 id="step-3test-out-library-installation">Step 3 - Test out library installation</h2><p>To verify that the default index URL is correctly being used from the secret scope and secret you created earlier, you need a cluster to test with. By installing a standard package such as <code>pandas</code>, you can confirm that the package is resolved through your private Azure Artifacts feed instead of PyPI.org.</p><ol>
<li>
<p><strong>Create a demo cluster</strong> in Databricks:</p>
<ol>
<li>In the Databricks workspace, go to <strong>Compute</strong>.</li>
<li>Select <strong>+ Create Cluster</strong>.</li>
<li>Enter a <strong>Cluster Name</strong> (for example, <code>demo-cluster</code>).</li>
<li>Choose a small cluster configuration (for example, <code>Standard_DS3_v2</code>) suitable for testing.</li>
<li>Select <strong>Create Cluster</strong>.</li>
</ol>
</li>
<li>
<p><strong>Start the cluster</strong> if it does not start automatically.</p>
</li>
<li>
<p><strong>Install a Python library</strong> from the private feed:</p>
<ol>
<li>
<p>In the cluster details page, select the <strong>Libraries</strong> tab.</p>
</li>
<li>
<p>Select <strong>Install New</strong>.</p>
</li>
<li>
<p>Choose <strong>PyPI</strong> as the library source.</p>
</li>
<li>
<p>In the <strong>Package</strong> field, enter:</p>
<pre><code class="language-plaintext">pandas==2.3.2
</code></pre>
</li>
<li>
<p>Select <strong>Install</strong>.</p>
</li>
</ol>
<p><img src="images/2025-09-install-pandas.png" alt="install-pandas.png" loading="lazy"></p>
<p>This test confirms that users no longer need to specify <code>--index-url</code> or <code>--extra-index-url</code>. Instead, the cluster uses the default value stored in the Databricks secret scope.</p>
</li>
<li>
<p><strong>Verify the installation succeeds</strong>. The <code>pandas</code> package should install successfully without additional configuration.</p>
</li>
<li>
<p><strong>Check Azure Artifacts</strong>:</p>
<ol>
<li>Go back to your Azure DevOps portal at <code>https://dev.azure.com/&lt;organizationName&gt;</code>.</li>
<li>Navigate to the project and select <strong>Artifacts</strong>.</li>
<li>Open your feed (for example, <code>PrivatePython</code>).</li>
<li>Under <strong>Packages</strong>, confirm that <code>pandas</code> now appears as a cached package in your feed.</li>
</ol>
</li>
</ol>
<figure class="kg-card kg-image-card"><img src="images/2025-09-image-6.png" class="kg-image" alt="" loading="lazy" width="1140" height="438"></figure><p>You have now validated that Databricks can resolve and install Python packages directly from your Azure Artifacts feed, ensuring secure and private access across your workspace.</p><h2 id="summary">Summary</h2><p>You have successfully installed a Python package through the Azure Artifacts. Users who want to install Python packages through notebooks, Databricks Asset Bundles (DABs), or any other mechanism will consistently be enforced by the secret scope. Please note that when they explicitly define the <code>--index-url</code>, it will take precedence over the default.</p><p>Even though you have used the "Upstream sources" to fetch packages from PyPI.org, it illustrates that if you push the packages yourself to the Azure Artifact feed, you can install them from here. </p>
