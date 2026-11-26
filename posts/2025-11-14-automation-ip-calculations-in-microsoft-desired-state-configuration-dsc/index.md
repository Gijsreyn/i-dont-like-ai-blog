---
title: "Automation IP calculations in Microsoft Desired State Configuration (DSC)"
status: published
tags: ["Microsoft Desired State Configuration v3"]
published_at: "2025-11-14T14:08:35.000Z"
custom_excerpt: "How to calculate IPs in Desired State Configuration using ARM functions"
feature_image: "images/2025-11-config-management.png"
---

<p>Network configurations have always been that exhausting task. One wrong digit means hours of debugging. You grab your spreadsheet again and start calculating the subnet masks. You double-check the CIDRS and hope you didn't accidentally overlap two network segments.</p><p>What if I told you there's a better way?</p><p>Not just better tooling, but a different approach that eliminates the spreadsheet entirely when you're working with network configurations and Desired State Configuration (DSC).</p><p>Here's how you can automate network configurations with PowerShell DSC and Microsoft DSC.</p><h2 id="the-problem-with-calculating">The problem with calculating</h2><p>When you're managing infrastructure, IP address allocation becomes that silent, productive killer. You need to:</p><ul><li>Divide a <code>/16</code> network into multiple <code>/24</code> subnets for different tiers.</li><li>Ensure nothing overlaps in the address spaces across regions.</li><li>Assign gateway addresses, DNS servers, and load balancers consistently.</li><li>Document everything</li></ul><p>And the tools? They're either complex (enterprise IPAM solutions) or too simple (good old Excel). There's no middle ground for teams that want automation without the overhead.</p><h2 id="enter-class-based-dsc-resources">Enter class-based DSC resources</h2><p>If you're coming from the PowerShell landscape, developing script-based DSC resources is old school. Class-based DSC resources are the latest pattern that supports additional features when using Microsoft DSC.</p><p>Let's look at a simple example of a DSC resource that manages IP access lists:</p><pre><code class="language-powershell">[DscResource()]
class IpAccessList
{
    [DscProperty(Key)]
    [System.String]
    $Name&#10;
    [DscProperty()]
    [System.String[]]
    $IpAddresses&#10;
    [IpAccessList] Get()
    {
        $currentState = [IpAccessList]::new()
        $currentState.Name = $this.Name
        $currentState.IpAddresses = $this.IpAddresses&#10;
        Write-Verbose "Get: Name=$($this.Name), IpAddresses=$($this.IpAddresses -join ', ')"&#10;
        return $currentState
    }&#10;
    [System.Boolean] Test()
    {
        Write-Verbose "Test: Checking IP addresses for '$($this.Name)'"&#10;
        if ($null -eq $this.IpAddresses -or $this.IpAddresses.Count -eq 0)
        {
            Write-Verbose "Test: No IP addresses defined"
            return $false
        }&#10;
        Write-Verbose "Test: Found $($this.IpAddresses.Count) IP address(es)"
        return $true
    }&#10;
    [void] Set()
    {
        Write-Verbose "Set: Configuring IP addresses for '$($this.Name)'"&#10;
        foreach ($ip in $this.IpAddresses)
        {
            Write-Verbose "Set: Processing IP address: $ip"
        }&#10;
        Write-Verbose "Set: Completed"
    }
}</code></pre><p>This class defines three methods:</p><ul><li><strong><code>Get()</code></strong> - Returns the current state.</li><li><strong><code>Test()</code> </strong>- Checks if configuration matches desired state.</li><li><strong><code>Set()</code></strong> - Enforces the desired state.</li></ul><p>The class itself has a <code>IpAddress</code> property to illustrate the example. An array of strings can be passed in. This means you can pass multiple IP addresses in CIDR notation:</p><pre><code class="language-powershell">Invoke-DscResource -Name IPAccessList -ModuleName MyModule -Method Set -Property @{
  Name = 'WebServers'
  IpAddresses = @('10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24')
}</code></pre><p>But here's where it gets interesting. How do you actually calculate those subnets <em>systematically</em>? How do you ensure nothing overlaps? How do you assign gateway addresses without manual calculation?</p><p>And then there's another problem: when you pass IP addresses as strings, you're responsible for validation. If you type in <code>10.0.1.0/33</code> or <code>10.0.1.256/24</code>, and the error happens later, you're scratching your head, thinking what's going on. The feedback loop is painful.</p><h2 id="enter-microsoft-dsc">Enter Microsoft DSC</h2><p>Microsoft DSC follows the Azure ARM functions implementation, allowing configuration functions that solve these problems.</p><p>Let's look at each function separately, starting of with <code>cidrSubnet()</code>. This function divides a large network block into smaller subnets automatically:</p><pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  baseNetwork:
    type: string
    defaultValue: 10.0.0.0/16
resources:
  - name: Network segmentation
    type: Microsoft.DSC.Debug/Echo
    properties:
      output:
        webTier: "[cidrSubnet(parameters('baseNetwork'), 24, 0)]"
        appTier: "[cidrSubnet(parameters('baseNetwork'), 24, 1)]"
        dataTier: "[cidrSubnet(parameters('baseNetwork'), 24, 2)]"</code></pre><p>This produces:</p><pre><code class="language-yaml">output:
  webTier: 10.0.0.0/24
  appTier: 10.0.1.0/24
  dataTier: 10.0.2.0/24</code></pre><p>There you have it already. No spreadsheet, no calculator, no mistakes.</p><p>The <code>cidrSubnet()</code> function takes three parameters:</p><ol><li>Base CIDR block</li><li>New prefix length</li><li>Subnet index</li></ol><p>Now, imagine you want to calculate specific host IP addresses within a subnet. Grab the <code>cidrHost()</code> function:</p><pre><code class="language-yaml">resources:
  - name: Infrastructure IPs
    type: Microsoft.DSC.Debug/Echo
    properties:
      output:
        gateway: "[cidrHost('192.168.100.0/24', 1)]"
        primaryDNS: "[cidrHost('192.168.100.0/24', 2)]"
        secondaryDNS: "[cidrHost('192.168.100.0/24', 3)]"
        loadBalancer: "[cidrHost('192.168.100.0/24', 10)]"</code></pre><p>The result:</p><pre><code class="language-yaml">output:
  gateway: 192.168.100.1
  primaryDNS: 192.168.100.2
  secondaryDNS: 192.168.100.3
  loadBalancer: 192.168.100.10</code></pre><p>The pattern here is consistency. Always use <code>.1</code> for gateways, <code>.2</code> and <code>.3</code> for DNS, and <code>.10</code> for load balancers. Your team starts learning the conventions once and applies them everywhere.</p><p>Lastly, there's one more function you can use to extract detailed network information from CIDR notation. This is the <code>parseCidr()</code> function:</p><pre><code class="language-yaml">resources:
  - name: Network details
    type: Microsoft.DSC.Debug/Echo
    properties:
      output: "[parseCidr('192.168.1.0/24')]"</code></pre><p>Returns:</p><pre><code>output:
  network: 192.168.1.0
  netmask: 255.255.255.0
  broadcast: 192.168.1.255
  firstUsable: 192.168.1.1
  lastUsable: 192.168.1.254
  cidr: 24</code></pre><p>This is perfect for documentation, validation, or configuring systems that require subnet masks rather than CIDR notation.</p><h2 id="bringing-it-together">Bringing it together</h2><p>Here's where the power starts by combining in. You can combine PSDSC class-based resources with CIDR functions to automate entire network configurations:</p><pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  vnetCidr:
    type: string
    defaultValue: 172.16.0.0/12&#10;  
resources:
  - name: Web tier network
    type: MyModule/IpAccessList
    properties:
      Name: WebTier
      IpAddresses:
        - "[cidrSubnet(parameters('vnetCidr'), 24, 0)]"
        - "[cidrSubnet(parameters('vnetCidr'), 24, 1)]"
        - "[cidrSubnet(parameters('vnetCidr'), 24, 2)]"&#10;  
  - name: App tier network
    type: DatabricksDsc/IpAccessList
    properties:
      Name: AppTier
      IpAddresses:
        - "[cidrSubnet(parameters('vnetCidr'), 24, 10)]"
        - "[cidrSubnet(parameters('vnetCidr'), 24, 11)]"&#10;  
  - name: Infrastructure details
    type: Microsoft.DSC.Debug/Echo
    properties:
      output:
        webTierSubnet: "[cidrSubnet(parameters('vnetCidr'), 24, 0)]"
        webTierGateway: "[cidrHost(cidrSubnet(parameters('vnetCidr'), 24, 0), 1)]"
        webServer1: "[cidrHost(cidrSubnet(parameters('vnetCidr'), 24, 0), 10)]"
        webServer2: "[cidrHost(cidrSubnet(parameters('vnetCidr'), 24, 0), 11)]"
        loadBalancer: "[cidrHost(cidrSubnet(parameters('vnetCidr'), 24, 0), 20)]"</code></pre><p>Run this configuration:</p><pre><code class="language-bash">dsc config get --file network-config.dsc.config.yaml</code></pre><p>The output:</p><pre><code class="language-yaml">results:
- metadata:
    Microsoft.DSC:
      duration: PT2.9537957S
  name: Web tier network
  type: MyModule/IpAccessList
  result:
    actualState:
      Name: WebTier
      IpAddresses:
      - 172.16.0.0/24
      - 172.16.1.0/24
      - 172.16.2.0/24
- metadata:
    Microsoft.DSC:
      duration: PT2.5088117S
  name: App tier network
  type: MyModule/IpAccessList
  result:
    actualState:
      IpAddresses:
      - 172.16.10.0/24
      - 172.16.11.0/24
      Name: AppTier
- metadata:
    Microsoft.DSC:
      duration: PT0.3531996S
  name: Infrastructure details
  type: Microsoft.DSC.Debug/Echo
  result:
    actualState:
      output:
        webTierSubnet: 172.16.0.0/24
        webTierGateway: 172.16.0.2
        webServer1: 172.16.0.11
        webServer2: 172.16.0.12
        loadBalancer: 172.16.0.21
messages: []
hadErrors: false</code></pre><h2 id="what-problem-does-this-actually-solve">What problem does this actually solve</h2><p>Let's be honest about what this eliminates. First, the spreadsheet problem. No more Excel files needed to calculate subnets. No more "check the documentation" when someone asks what IP range web servers use, as it's all declared in documents.</p><p>Then you have the consistency. Every environment eventually follows the same pattern. Western Europe uses the subnet index <code>0-9</code>, whereas the north uses <code>10-19</code>.</p><p>Lastly, the overlapping problem. You can't accidentally overlap subnets when the function calculates them sequentially. Math doesn't make mistakes; humans do.</p><h2 id="when-you-should-use-this">When you should use this</h2><p>This approach shines when you're managing your network using DSC and when:</p><ul><li>You're managing multiple environments.</li><li>You need consistent IP allocation across regions.</li><li>You're systematically dividing large address spaces.</li><li>You want Infrastructure-as-Code (IaC) for networking.</li></ul><p>It's not necessary if:</p><ul><li>You have three servers to maintain (even though you still can).</li><li>Your network topology changes yearly.</li><li>You prefer GUI-based network tools</li></ul><h2 id="getting-started">Getting started</h2><p>If the above examples inspired you to get started, there are two things you need:</p><ul><li>PowerShell 7+</li><li>Microsoft DSC for CIDR configuration functions.</li></ul><p>That's it. Just PowerShell and YAML together. </p><h2 id="where-this-goes-next">Where this goes next</h2><p>The future here is reusability. Imagine the following:</p><ul><li>A DSC resource that configures Databricks IP access lists using these functions.</li><li>A resource that configures firewall rules based on CIDR calculations.</li><li>A resource that generates network diagrams from your DSC config.</li></ul><p>The building blocks already exist. The CIDR functions handle the math. Class-based DSC resources handle the state management. </p><p>What you need is a problem worth solving.</p><p>For me, that's always been network automation. Because it helps me explore the systematic deployment of infrastructure, it helps me ensure production environments are consistent. It helps me document complex networks in code, even though that's my Achilles heel.</p><p>That's the fastest way to build reliable systems.</p>
