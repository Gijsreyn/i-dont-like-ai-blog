---
title: "Own the enforcement schedule"
status: published
visibility: "members"
tags: ["Course", "Migrating from PowerShell DSC"]
published_at: "2026-09-20T10:12:13.000Z"
custom_template: "custom-lesson"
---

<p>The LCM checked your configuration every 15 minutes, whether you thought about it or not. Microsoft DSC doesn't do that. <strong>If nothing runs the <code>dsc</code> command, nothing happens.</strong></p>
<p>This is the biggest day-to-day difference in the whole migration. It's also the one teams most often find out about the hard way. A few weeks after the switch, someone asks why a setting that drifted never got fixed, and the answer is that nothing was running.</p>
<h2 id="pick-the-command-that-matches-the-old-mode">Pick the command that matches the old mode</h2>
<p>The LCM's <code>ConfigurationMode</code> setting decided what it did on each check. You now pick a <code>dsc</code> command that does the same job:</p>
<table>
<thead>
<tr>
<th>Old <code>ConfigurationMode</code></th>
<th>New scheduled command</th>
<th>What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>ApplyOnly</code></td>
<td>Nothing on a schedule. Run <code>dsc config set</code> once from a pipeline or by hand</td>
<td>Applies the configuration once and never checks it again</td>
</tr>
<tr>
<td><code>ApplyAndMonitor</code></td>
<td><code>dsc config test</code>, and alert when it reports <code>inDesiredState: false</code></td>
<td>Finds drift but doesn't fix it</td>
</tr>
<tr>
<td><code>ApplyAndAutoCorrect</code></td>
<td><code>dsc config set</code></td>
<td>Fixes drift on every run</td>
</tr>
</tbody>
</table>
<p>Picking the command is the easy part, because each mode maps to exactly one command. Picking how <em>often</em> it runs is up to you. In the LCM, that was <code>ConfigurationModeFrequencyMins</code>, a number hidden in a meta-configuration. Now it's a schedule you write yourself, keep in source control, and review like any other change.</p>
<blockquote>
<p>[!TIP]<br>
Start with the same interval the LCM used, and change it later. If you keep the old timing, any difference you notice after the switch comes from the migration and not from a new schedule. That makes problems much easier to track down while you're still building trust in the new setup.</p>
</blockquote>
<h2 id="windows-a-scheduled-task">Windows: a scheduled task</h2>
<p>On Windows, the closest match to the LCM is a scheduled task that runs <code>dsc config set</code>:</p>
<pre><code class="language-powershell">$action = New-ScheduledTaskAction `
    -Execute 'dsc.exe' `
    -Argument 'config set --file C:\BinderyOps\webserver-adapted.dsc.config.yaml'&#10;
$trigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15)&#10;
Register-ScheduledTask `
    -TaskName 'BinderyDscEnforcement' `
    -TaskPath '\DSC\' `
    -Action $action `
    -Trigger $trigger `
    -User 'SYSTEM' `
    -RunLevel Highest
</code></pre>
<p>This task runs every 15 minutes as <code>SYSTEM</code> with the highest privileges, which is how the LCM ran too. The difference is that you can now see it in Task Scheduler. An operator can open it, turn it off, and check how the last run went.</p>
<h3 id="manage-the-schedule-with-dsc-itself">Manage the schedule with DSC itself</h3>
<p>A scheduled task is just another setting on the machine, so a DSC resource can manage it. That means DSC can look after the very task that runs DSC.</p>
<p>The example below uses <code>DSC.Tutorial/ScheduledTask</code>, the resource you build in chapter 8 of <em>The Microsoft DSC Handbook</em>:</p>
<pre><code class="language-yaml">$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: Enforcement schedule
    type: DSC.Tutorial/ScheduledTask
    properties:
      taskName: BinderyDscEnforcement
      taskPath: \DSC\
      execute: dsc.exe
      argument: "config set --file C:\\BinderyOps\\webserver-adapted.dsc.config.yaml"
      triggerTime: "02:00AM"
      description: "Enforces the Bindery web server configuration"
      _exist: true
</code></pre>
<blockquote>
<p>[!NOTE]<br>
The tutorial resource only supports a daily trigger, so this document creates a task that runs once a day at 02:00. That's enough to show the idea. For a 15-minute interval like the LCM's, extend the resource with a repeat interval, or use a scheduled task resource that supports one.</p>
</blockquote>
<p>You now have two documents. The <em>schedule document</em> above describes the task. The <em>web server document</em> describes the server. The task runs <code>dsc config set</code> against the web server document on every interval.</p>
<p>You can go one step further and let each scheduled run apply the schedule document as well. Then, if someone edits or disables the task, the next run puts it back the way the document describes. The schedule keeps the configuration correct, and the configuration keeps the schedule correct.</p>
<p><img src="https://storage.ghost.io/c/dd/64/dd64ba9d-7bdd-441e-bb5f-13f8be709814/content/images/2026/10/scheduled-enforcement-loop.png" alt="Figure 1: The schedule enforces the configuration, and a configuration enforces the schedule." loading="lazy"></p>
<blockquote>
<p>[!NOTE]<br>
Something still has to apply the schedule document the very first time. That can be a build pipeline, a machine image, or a script that runs once during setup. You can't avoid this step, and the LCM had the same problem: something had to push its meta-configuration too. The same goes for a task that someone deletes. A deleted task can't run, so nothing puts it back until the bootstrap step runs again.</p>
</blockquote>
<h2 id="linux-cron-or-a-systemd-timer">Linux: cron or a systemd timer</h2>
<p>On Linux, cron can do the same job:</p>
<pre><code class="language-bash">*/15 * * * * root /usr/bin/dsc config set --file /etc/bindery/webserver.dsc.config.yaml &gt;&gt; /var/log/dsc-enforcement.log 2&gt;&amp;1
</code></pre>
<p>A systemd timer is the better choice. It sends output to the system journal, can wait a few minutes after boot before the first run, and keeps a failed state that an operator can look up:</p>
<pre><code class="language-ini"># /etc/systemd/system/dsc-enforce.service
[Unit]
Description=Enforce Bindery desired state&#10;
[Service]
Type=oneshot
ExecStart=/usr/bin/dsc config set --file /etc/bindery/webserver.dsc.config.yaml
</code></pre>
<pre><code class="language-ini"># /etc/systemd/system/dsc-enforce.timer
[Unit]
Description=Run DSC enforcement every 15 minutes&#10;
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min&#10;
[Install]
WantedBy=timers.target
</code></pre>
<pre><code class="language-bash">systemctl enable --now dsc-enforce.timer
systemctl list-timers dsc-enforce.timer
</code></pre>
<h2 id="save-the-results-or-you-only-replaced-half-the-lcm">Save the results, or you only replaced half the LCM</h2>
<p>The LCM kept a record of each run that you could read with <code>Get-DscConfigurationStatus</code>. A scheduled task that throws away its output keeps nothing.</p>
<p><code>dsc</code> returns its results as JSON, so save them:</p>
<pre><code class="language-powershell">$result = dsc config set --file C:\BinderyOps\webserver-adapted.dsc.config.yaml --output-format json |
    ConvertFrom-Json&#10;
$stamp = Get-Date -Format 'yyyy-MM-ddTHH-mm-ss'
$result | ConvertTo-Json -Depth 20 |
    Out-File "C:\BinderyOps\logs\run-$stamp.json"&#10;
if ($result.hadErrors) {
    Write-EventLog -LogName Application -Source 'BinderyDsc' `
        -EntryType Error -EventId 4001 `
        -Message "DSC enforcement reported errors. See run-$stamp.json"
}
</code></pre>
<p>This gives you more than the LCM did. You get one JSON file per run, with the state of every resource before and after the run. You can send those files to any log platform as they are, with no special parsing.</p>
<blockquote>
<p>[!TIP]<br>
If your machines ran in <code>ApplyAndMonitor</code> mode, schedule <code>dsc config test</code> instead and alert on <code>inDesiredState: false</code>. Both commands return results in the same shape, so the same logging setup works for both. Moving a machine from "report drift" to "fix drift" then only means changing <code>test</code> to <code>set</code> in the scheduled command.</p>
</blockquote>
<h2 id="switch-over-in-the-right-order">Switch over in the right order</h2>
<p>The most common migration problem is two tools managing the same settings at once. You won't notice while they agree. The trouble starts the day their desired values differ, which usually happens during a change, when you least want surprises.</p>
<p>Follow these steps on each machine:</p>
<ol>
<li>
<p><strong>Check.</strong> Run <code>dsc config test</code> on a machine the LCM manages. Every resource in the migrated document should report <code>inDesiredState: true</code>.</p>
</li>
<li>
<p><strong>Stop the LCM from making changes.</strong> Set its meta-configuration to <code>ApplyOnly</code>, or remove its configuration completely:</p>
<pre><code class="language-powershell">Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force
</code></pre>
</li>
<li>
<p><strong>Make sure the LCM has stopped.</strong> <code>Get-DscConfigurationStatus</code> should show no new runs.</p>
</li>
<li>
<p><strong>Turn on the new schedule.</strong> Register the scheduled task or enable the timer.</p>
</li>
<li>
<p><strong>Wait for one full interval.</strong> Read the saved result of the first scheduled run before you move on.</p>
</li>
</ol>
<blockquote>
<p>[!WARNING]<br>
Never turn on the new schedule while the LCM is still in <code>ApplyAndAutoCorrect</code> mode for the same settings. Each tool keeps changing the machine back to its own version of the settings. This back and forth is hard to spot, because both tools report that their run succeeded.</p>
</blockquote>
