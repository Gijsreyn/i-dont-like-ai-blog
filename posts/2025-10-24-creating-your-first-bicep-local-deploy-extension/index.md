---
title: "Creating your first Bicep Local Deploy extension"
status: published
tags: ["Course", "Build custom Bicep extensions with Bicep Local Deploy"]
published_at: "2025-10-24T11:34:01.000Z"
custom_template: "custom-lesson"
---

<p>With your environment set up, it's time to develop your first Bicep Local Deploy extension. In this module, you'll:</p><ul><li>Scaffold a new extension project using the template.</li><li>Understand the project structure and the created files.</li><li>Define a custom resource module with documentation attributes.</li><li>Implement a basic resource handler.</li><li>Build your extension locally.</li><li>Write your first Bicep file using your custom resource.</li></ul><p>Let's dive into it.</p><h2 id="scaffold-your-extension-project">Scaffold your extension project</h2><p>The fastest way to start building an extension is by using the unofficial project template. The template provides a project structure similar to other open-source projects, with all the components needed to get started right out of the bat. This eliminates minutes, let alone hours, of setup work from the start.</p><p>In the first lesson, you already created a simple demo extension project to verify your installation. Now, let's create a practical extension that leverages a real service with authentication and responds with actual data.</p><p>This free service, <a href="https://gorest.co.in/">GoRest</a>, allows you to authenticate using a token. Token-based authentication is one of the most common patterns in REST API services, making this an ideal exercise. To use GoRest, you'll need either a GitHub account, a Microsoft account, or a Google account to create an authentication token. If you already have one of these accounts, you're ready to start.</p><h3 id="create-the-project">Create the project</h3><p>The <code>dotnet new</code> command with the <code>bicep-ld-tpl</code> template creates a complete ready-to-use extension project. </p><p>To create a new extension project using this template, you can run:</p><pre><code class="language-bash"># Create new extension project
dotnet new bicep-ld-tpl -n GoRest&#10;
# Navigate to the project
cd GoRest</code></pre><h3 id="explore-the-project-structure">Explore the project structure</h3><p>Understanding the project structure helps you navigate and extend your codebase. The template organizes files by responsibility: <strong>models </strong>define resource schemas, <strong>handlers </strong>implement the logic, and the <strong>build script </strong>automates compilation and publishing the extension.</p><p>This separation of concerns makes it easy to find what you need and maintains clear boundaries between different aspects of your extension. The template creates a complete project structure:</p><pre><code class="language-plaintext">GoRest/
 build.ps1                    # Build and publish script
 global.json                  # .NET SDK version configuration
 GlobalUsings.cs              # Global using directives
 Program.cs                   # Application entry point
 GoRest.csproj                # Project file
 Models/
    Configuration.cs          # Extension configuration
    SampleResource/
      SampleResource.cs       # Sample resource model (we'll replace this)
 Handlers/
    ResourceHandlerBase.cs    # Base handler with REST API helpers
    SampleHandler/
      SampleResourceHandler.cs # Sample resource handler (we'll replace this)</code></pre><h3 id="key-files-explained">Key files explained</h3><p>Let's examine the most important files in your extension project. Understanding what each file does and how they work together allows you to customize the template to your needs. These files form the foundation of every Bicep extension, and you'll interact with them frequently as you develop your extension.</p><h4 id="programcs">Program.cs</h4><p>The entry point that configures:</p><ul><li>Dependency injection</li><li>Register extension</li><li>Map resource handlers</li></ul><p>This file is where your extension comes to life. It tells Bicep what your extension is called, which resource types it provides, and how to handle requests for those resources.</p><p>The entry point that registers your extension handlers:</p><pre><code class="language-csharp">using Bicep.Local.Extension.Host.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using GoRest.Handlers.SampleHandler;
using GoRest.Models;&#10;
var builder = WebApplication.CreateBuilder();&#10;
builder.AddBicepExtensionHost(args);
builder
    .Services.AddBicepExtension(
        name: "GoRest",
        version: "0.0.1",
        isSingleton: true,
        typeAssembly: typeof(Program).Assembly,
        configurationType: typeof(Configuration)
    )
    .WithResourceHandler&lt;SampleResourceHandler&gt;();&#10;
var app = builder.Build();
app.MapBicepExtension();
await app.RunAsync();
</code></pre><h4 id="configurationcs">Configuration.cs</h4><p>The <code>Configuration</code> class defines default parameters that users specify when declaring your extension in Bicep. These parameters are always mandatory and are used widely amongst all resource types. Configuration properties can include base URLs, authentication tokens, and other default values.</p><p>Users set these once in the <code>extension</code> declaration, and the framework makes them available to all your resource handlers. When you scaffolded the project, the default configuration parameters are:</p><pre><code class="language-csharp">using Azure.Bicep.Types.Concrete;
using Bicep.Local.Extension.Types.Attributes;&#10;
namespace GoRest.Models;&#10;
public class Configuration
{
    [TypeProperty("The base URL for the API endpoint.", ObjectTypePropertyFlags.Required)]
    public required string BaseUrl { get; set; }
}
</code></pre><p>The REST API you'll be using requires an authentication token. That's why you can add an additional property <code>Token</code>:</p><pre><code class="language-csharp">[TypeProperty("The authentication token for GoRest API.", ObjectTypePropertyFlags.Required)]
public required string Token { get; set; }</code></pre><h4 id="resourcehandlerbasecs">ResourceHandlerBase.cs</h4><p>A base class that is not mandatory, but highly likely to be used. It can encapsulate common HTTP client functionality, making it easier to call REST APIs from your handlers. This class provides helper methods for making HTTP requests, handling responses, deserializing JSON, and potentially handling errors. </p><p>By inheriting from this base class, your resource handlers can focus on simple logic rather than boilerplate each HTTP request and response.</p><p>The other key files will be explained in more detail in the following sections.</p><h2 id="define-your-resource-model">Define your resource model</h2><p>Resource models are the heart of your extension. They define the properties of your resources (required or optional) and the outputs they produce. The model acts as a contract between Bicep and your extension. This is where you get IntelliSense, validation, and type safety in your VS Code editor.</p><p>Designing your models with clear property names and documentation attributes makes your extension easier to use. In the following subsection, you'll create a <code>User</code> resource that represents a user in the GoRest API system. This is a practical demonstration of how you can leverage Bicep's ecosystem of extensions and how they work with external REST APIs. The model will include properties like:</p><ul><li>Name</li><li>Email</li><li>Gender</li><li>Status</li></ul><p>Those are the properties that users can define and return in the <code>output</code> properties that are returned after deployment.</p><h3 id="create-the-model-folder">Create the model folder</h3><p>Organizing your models in dedicated folders keeps your codebase clean. This structure becomes valuable as your extension grows and you add more resource types. Each resource type gets its own folder, depending on how the REST API organizes it.</p><p>To create the <code>User</code> folder, run the following command:</p><pre><code class="language-bash">mkdir src/Models/User</code></pre><h3 id="define-the-model-class">Define the model class</h3><p>Now you'll create the complete <code>User</code> model that defines the structure of your resource. This model includes two enums (<code>UserGender</code> and <code>UserStatus</code>) that constrains valid values. Because Bicep's Local Deploy doesn't support custom enum types in its type system, you'll see an attribute (<code>[JsonConverter(typeof(JsonStringEnumConverter))]</code>) added, allowing you to bridge the gap by converting your .NET enum values to and from strings during serialization.</p><p>Pay close attention to how the <code>User</code> class inherits from <code>UserIdentifiers</code>. This pattern separates identifying properties from the rest of the model, which the framework uses to track resource instances.</p><p>Follow the steps below to define the model class:</p><ol><li>Create a new file <code>User.cs</code> in the <code>User</code> directory.</li><li>Add the following code snippet:</li></ol><pre><code class="language-csharp">using Bicep.Local.Extension.Types.Attributes;
using System.Text.Json.Serialization;&#10;
namespace GoRest.Models.User;&#10;
public enum UserGender
{
    Male,
    Female
}&#10;
public enum UserStatus
{
    Active,
    Inactive
}&#10;
[BicepFrontMatter("category", "User Management")]
[BicepDocHeading("User", "Manages users in the GoRest API.")]
[BicepDocExample(
    "Creating a basic user",
    "This example creates a simple active user with required fields.",
    @"resource adminUser 'User' = {
  name: 'John Doe'
  email: 'john.doe@example.com'
  gender: 'Male'
  status: 'Active'
}")]
[BicepDocExample(
    "Creating multiple users",
    "This example creates multiple users with different settings.",
    @"resource adminUser 'User' = {
  name: 'Jane Admin'
  email: 'jane.admin@company.com'
  gender: 'Female'
  status: 'Active'
}&#10;
resource devUser 'User' = {
  name: 'Bob Developer'
  email: 'bob.dev@company.com'
  gender: 'Male'
  status: 'Active'
}")]
[BicepDocCustom(
    "User email requirements",
    @"User emails must be unique in the GoRest system. Key considerations:&#10;
- Email addresses must be valid and unique
- Use organization domain emails for better tracking
- Inactive users can be reactivated by updating their status
- Gender field accepts 'Male' or 'Female' values
- Status field accepts 'Active' or 'Inactive' values")]
[ResourceType("User")]
public class User : UserIdentifiers
{
    [TypeProperty("The full name of the user.", ObjectTypePropertyFlags.Required)]
    public required string Name { get; set; }&#10;
    [TypeProperty("The gender of the user.", ObjectTypePropertyFlags.Required)]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public required UserGender? Gender { get; set; }&#10;
    [TypeProperty("The status of the user account.", ObjectTypePropertyFlags.Required)]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public required UserStatus? Status { get; set; }&#10;
    [TypeProperty("The unique user ID assigned by GoRest.", ObjectTypePropertyFlags.ReadOnly)]
    public int Id { get; set; }
}&#10;
public class UserIdentifiers
{
    [TypeProperty("The unique email address of the user.", ObjectTypePropertyFlags.Required | ObjectTypePropertyFlags.Identifier)]
    public required string Email { get; set; }
}</code></pre><h3 id="understanding-property-flags">Understanding property flags</h3><p>The property flags you see are the mechanism for controlling how Bicep treats your resource properties. They determine whether a property is required, whether it can be set by users, or whether it is only returned as output. It also serves as a unique identifier (<code>UserIdentifiers</code>) for the resource.</p><p>Understanding these flags helps you design your resource models that behave correctly in Bicep files</p><p>The <code>ObjectTypePropertyFlags</code> enum controls property behavior:</p><ul><li><strong>Required:</strong> Property must be specified in Bicep.</li><li><strong>Identifier:</strong> Used to uniquely identify the resource.</li><li><strong>ReadOnly: </strong>Output property, cannot be set by users.</li><li><strong>None:</strong> Optional input property.</li></ul><h2 id="implement-the-resource-handler">Implement the resource handler</h2><p>Resource handlers are the hardworking components of your extension. While your model defines <em>what</em> your resource looks like, handlers define <em>how</em> it behaves. Handlers translate Bicep's declarative resource requests into imperative API calls. It creates, updates, or deletes resources. Well-written handlers make your resources feel more predictable to Bicep users.</p><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">Imperative translates declarative Bicep into step-by-step instructions.</div></div><p></p><p>Every handler implements at least three key methods: Preview (checks the current state before deployment), CreateOrUpdate (provisions or modifies the resource), and GetIdentifiers (extracts unique identifiers). These methods form the resource lifecycle, allowing Bicep to manage your custom resources with the same declarative approach it uses for Azure resources.</p><h3 id="create-the-handler-folder">Create the handler folder</h3><p>Just as models benefit from being organized, handlers do too. This keeps handler code, helper classes, and any handler-specific types together. </p><p>To create the folder, run the following command:</p><pre><code class="language-bash">mkdir src/Handlers/UserHandler</code></pre><h3 id="create-userhandlercs">Create UserHandler.cs</h3><p>The following handler implementation demonstrates the resource lifecycle for user management in the GoRest API. It shows how to check whether a user exists by email, create a new user, update existing users, and populate output properties (such as the generated user ID).</p><p>The handler uses the base class's HTTP client helper to make REST API calls and logs operations for debugging. Follow the steps below to create the <code>UserHandler.cs</code>:</p><ol><li>Create a new file named <code>UserHandler.cs</code> in the <code>UserHandler</code> directory.</li><li>Add the following code snippet:</li></ol><pre><code class="language-csharp">using Microsoft.Extensions.Logging;
using GoRest.Models;
using GoRest.Models.User;&#10;
namespace GoRest.Handlers.UserHandler;&#10;
public class UserHandler : ResourceHandlerBase&lt;User, UserIdentifiers&gt;
{
    private const string UsersApiEndpoint = "/public/v2/users";&#10;
    public UserHandler(ILogger&lt;UserHandler&gt; logger)
        : base(logger) { }&#10;
    protected override async Task&lt;ResourceResponse&gt; Preview(
        ResourceRequest request,
        CancellationToken cancellationToken
    )
    {
        var props = request.Properties;&#10;        
        _logger.LogInformation("Previewing user: {Email}, Name: {Name}", props.Email, props.Name);&#10;
        var existing = await GetUserByEmailAndNameAsync(
            request.Config,
            props.Email,
            props.Name,
            cancellationToken
        );&#10;
        if (existing != null)
        {
            _logger.LogInformation("User exists with ID: {Id}, populating outputs", existing.Id);&#10;            
            // Populate output properties from existing resource
            props.Id = existing.Id;
            props.Name = existing.Name;
            props.Gender = existing.Gender;
            props.Status = existing.Status;
        }
        else
        {
            _logger.LogInformation("User does not exist, will be created");
        }&#10;
        return GetResponse(request);
    }&#10;
    protected override async Task&lt;ResourceResponse&gt; CreateOrUpdate(
        ResourceRequest request,
        CancellationToken cancellationToken
    )
    {
        var props = request.Properties;&#10;
        _logger.LogInformation("Ensuring user: {Email}, Name: {Name}", props.Email, props.Name);&#10;
        var existing = await GetUserByEmailAndNameAsync(request.Config, props.Email, props.Name, cancellationToken);&#10;
        if (existing == null)
        {
            _logger.LogInformation("Creating new user: {Email}", props.Email);
            var created = await CreateUserAsync(request.Config, props, cancellationToken);&#10;            
            // Populate output properties from the created user
            props.Id = created.Id;
            props.Name = created.Name;
            props.Gender = created.Gender;
            props.Status = created.Status;
        }
        else
        {
            _logger.LogInformation("Updating existing user with ID: {Id}", existing.Id);&#10;            
            try
            {
                await UpdateUserAsync(request.Config, existing.Id, props, cancellationToken);
                props.Id = existing.Id;
            }
            catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.UnprocessableEntity)
            {
                // This can happen if we're trying to update with the same email that already exists
                _logger.LogWarning("Update returned 422 (Unprocessable Entity), treating as successful: {Message}", ex.Message);
                props.Id = existing.Id;
            }
        }&#10;
        return GetResponse(request);
    }&#10;
    protected override UserIdentifiers GetIdentifiers(User properties) =&gt;
        new() { Email = properties.Email };&#10;
    private async Task&lt;User?&gt; GetUserByEmailAndNameAsync(
        Configuration configuration,
        string email,
        string name,
        CancellationToken ct
    )
    {
        try
        {
            // GoRest API doesn't support filtering by email/name in query params
            // Fetch all users and search by email OR name
            _logger.LogInformation("Fetching all users to search for email: {Email} OR name: {Name}", email, name);&#10;            
            var response = await CallApiForResponse&lt;List&lt;User&gt;&gt;(
                configuration,
                HttpMethod.Get,
                UsersApiEndpoint,
                ct
            );&#10;
            if (response != null)
            {
                _logger.LogInformation("API returned {Count} users", response.Count);
            }
            else
            {
                _logger.LogWarning("API returned null response");
                return null;
            }&#10;
            // Search for user by email OR name (case-insensitive)
            var match = response.FirstOrDefault(u =&gt; 
                string.Equals(u.Email, email, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(u.Name, name, StringComparison.OrdinalIgnoreCase));&#10;
            if (match != null)
            {
                _logger.LogInformation("Found matching user: ID={Id}, Email={Email}, Name={Name}", 
                    match.Id, match.Email, match.Name);
            }
            else
            {
                _logger.LogInformation("No matching user found for email={Email} OR name={Name}", email, name);
            }&#10;
            return match;
        }
        catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get user by email and name: {Email}, {Name}", email, name);
            return null;
        }
    }&#10;
    private async Task&lt;User&gt; CreateUserAsync(
        Configuration configuration,
        User user,
        CancellationToken ct
    )
    {
        var createPayload = new
        {
            name = user.Name,
            email = user.Email,
            gender = user.Gender?.ToString().ToLowerInvariant(),
            status = user.Status?.ToString().ToLowerInvariant()
        };&#10;
        var response = await CallApiForResponse&lt;User&gt;(
            configuration,
            HttpMethod.Post,
            UsersApiEndpoint,
            ct,
            createPayload
        );&#10;
        return response ?? throw new InvalidOperationException("Failed to create user");
    }&#10;
    private async Task UpdateUserAsync(
        Configuration configuration,
        int userId,
        User user,
        CancellationToken ct
    )
    {
        var updatePayload = new
        {
            name = user.Name,
            email = user.Email,
            gender = user.Gender?.ToString().ToLowerInvariant(),
            status = user.Status?.ToString().ToLowerInvariant()
        };&#10;
        await CallApiForResponse&lt;User&gt;(
            configuration,
            HttpMethod.Put,
            $"{UsersApiEndpoint}/{userId}",
            ct,
            updatePayload
        );
    }
}</code></pre><h3 id="understanding-handler-methods">Understanding handler methods</h3><p>Each handler method serves a specific purpose. Understanding when each method is called and what it should do helps you build reliable extensions. These methods work together to provide Bicep with the information it needs to manage resources declaratively. </p><h4 id="preview">Preview</h4><p>Preview is called before any changes are made. This gives Bicep a chance to show users what will happen during deployment. This is your opportunity to check if a resource already exists and retrieve its current properties. Preview should <strong>never</strong> make changes.</p><p>Use this to:</p><ul><li>Retrieve current resource properties.</li><li>Populate output properties.</li><li>Validate resource state.</li></ul><h4 id="createorupdate">CreateOrUpdate</h4><p><code>CreateOrUpdate</code> is where the actual resource provisioning happens. This method is called during deployment to apply the desired state specified in Bicep. It should check if the resource exists, create it if it doesn't, or update it if it does. This method must be idempotent, meaning every time you call the resource, the same result should be returned. </p><p>This method should:</p><ul><li>Check if the resource exists.</li><li>Create a new resource or update an existing one.</li><li>Return the final resource state with outputs.</li></ul><h4 id="getidentifiers">GetIdentifiers</h4><p>The <code>GetIdentifiers</code> method is the important method that extracts the unique identifiers from a resource. The framework uses these identifiers to track resource instances, manage resource dependencies, and maintain state across deployments. Identifiers must be stable and unique</p><p>The framework uses it to:</p><ul><li>Track resource instances.</li><li>Handle resource dependencies.</li><li>Manage resource state.</li></ul><h2 id="register-your-handler">Register your handler</h2><p>With your model and handler complete, you need to tell your extension about them. Registration is the step that connects your handler to the Bicep framework. When this happens, the resource type is available for use in Bicep files. The <code>WithResourceHandler</code> method wires up dependency injection, maps the HTTP requests, and enables the framework to discover your resource type.</p><p>Update <code>Program.cs</code> to use your new handler:</p><pre><code class="language-csharp">using Bicep.Local.Extension.Host.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using GoRest.Handlers.SampleHandler;
using GoRest.Models;
using GoRest.Handlers.UserHandler;&#10;
var builder = WebApplication.CreateBuilder();&#10;
builder.AddBicepExtensionHost(args);
builder
    .Services.AddBicepExtension(
        name: "GoRest",
        version: "0.0.1",
        isSingleton: true,
        typeAssembly: typeof(Program).Assembly,
        configurationType: typeof(Configuration)
    )
    .WithResourceHandler&lt;UserHandler&gt;();&#10;
var app = builder.Build();
app.MapBicepExtension();
await app.RunAsync();
</code></pre><h2 id="authenticating-against-rest-api">Authenticating against REST API</h2><p>Before building your extension, there's one more thing to do. You need to understand how authentication works with the GoRest API. The base class (<code>ResourceHandlerBase.cs</code>) class includes built-in authentication support using an environment variable. </p><p>Because you've added the <code>Token</code> property in the model, you provide two capabilities for supplying credentials. The original base class code's authentication flow is:</p><pre><code class="language-csharp">// Try API_KEY environment variable for authentication
var apiKey = Environment.GetEnvironmentVariable("API_KEY");
if (!string.IsNullOrWhiteSpace(apiKey))
{
    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
        "Bearer",
        apiKey
    );
}&#10;
return client;</code></pre><p>However, you can't expect all users to set this environment variable up front. That's where you can change the above code to:</p><pre><code class="language-csharp">// Try API_KEY environment variable for authentication, otherwise use configuration token
var apiKey = Environment.GetEnvironmentVariable("API_KEY");
var token = apiKey ?? configuration.Token;&#10;
if (!string.IsNullOrWhiteSpace(token))
{
    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
        "Bearer",
        token
    );
}&#10;
return client;</code></pre><p>This approach gives you the best of both worlds to supply your authentication token:</p><ol><li><strong>Environment variable(API_KEY):</strong> Takes precedence if set. It's useful for local development or DevOps pipelines.</li><li><strong>Configuration parameter (<code>Token</code>): </strong>Specified in your Bicep parameters.</li></ol><h3 id="getting-your-gorest-token"><strong>Getting your GoRest token</strong></h3><p>To use the GoRest API, you can already retrieve an authentication token. Here's how to obtain one:</p><ol><li>Visit the <a href="https://gorest.co.in/">GoRest</a> site.</li><li>Click the <strong>Sign in</strong> button in the top navigation.</li><li>Choose one of the authentication providers:<ol><li> <strong>GitHub:</strong> Sign in with your GitHub account.</li><li><strong>Microsoft: </strong>Sign in with your Microsoft account.</li><li><strong>Google:</strong> Sign in with your Google account.</li></ol></li><li>After authentication, you'll be redirected back to GoRest.</li><li>Click on your profile icon in the top-right corner.</li><li>Your <strong>access token </strong>will be displayed here.</li></ol><p>Store this value for later.</p><h2 id="building-your-extension">Building your extension</h2><p>Building your extension compiles your .NET code and packages it with its dependencies. In the end, a deployment-ready extension is produced in the <code>output</code> directory. The build automation script you've played with can be reused to automate this entire process. A successful build means your extension is ready to be referenced from Bicep files.</p><p>To build and publish (locally) the extension, run the following in a PowerShell terminal session:</p><pre><code class="language-powershell">.\build.ps1</code></pre><h2 id="test-your-extension-with-bicep">Test your extension with Bicep</h2><p>The moment of truth. Now that the extension is published, you can test it with an actual Bicep file. You'll write your Bicep code as you usually would for Azure resources. When you edit your Bicep file in the VS Code editor, you notice the IntelliSense kicks in. Now let's use your extension in a Bicep file.</p><h3 id="create-mainbicep">Create main.bicep</h3><p>This Bicpe file demonstrates the full capabilities of your <code>User</code> resource. Notice how it declares the extension with configuration parameters (<code>baseUrl</code> and <code>token</code>), defines a resource with all required properties, and outputs values from read-only properties, such as the generated user ID.</p><pre><code class="language-bicep">targetScope = 'local'&#10;
param baseUrl string
@secure()
param token string&#10;
extension gorest with {
  baseUrl: baseUrl
  token: token
}&#10;
resource adminUser 'User' = {
  name: 'John Doe'
  email: 'john.doe@example.com'
  gender: 'Male'
  status: 'Active'
}&#10;
output adminUserId int = adminUser.id
output adminUserEmail string = adminUser.email</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">ℹ️</div><div class="kg-callout-text">Don't worry about the inline errors you'll see.</div></div><p></p><h3 id="create-mainbicepparam">Create main.bicepparam</h3><p>Bicep Local Deploy doesn't support direct deployments. Instead, it relies on <code>.bicepparam</code> files to be used for deployment. Here's where the earlier fetched token comes in:</p><pre><code class="language-bicep">using 'main.bicep'&#10;
param baseUrl = 'https://gorest.co.in'
param token = 'YOUR_GOREST_TOKEN_HERE'  // Replace with your actual token</code></pre><h3 id="create-bicepconfigjson-optional">Create bicepconfig.json (optional)</h3><p>Remember the squiggly errors in your <code>main.bicep</code> file. This is because Bicep Local Deploy is an experimental feature. When Bicep Local Deploy is in GA (General Availability), this step is no longer mandatory. Once you configure the following, Bicep can discover your local extension, load its type definitions, and provide IntelliSense for your custom resource types:</p><pre><code class="language-json">{
  "experimentalFeaturesEnabled": {
    "localDeploy": true
  },
  "extensions": {
    "GoRestExtension": "output/my-extension"
  },
  "implicitExtensions": []
}</code></pre><div class="kg-card kg-callout-card kg-callout-card-blue"><div class="kg-callout-emoji">💡</div><div class="kg-callout-text">If you want to change the name (<code spellcheck="false" style="white-space: pre-wrap;">my-extension</code>), you can change the <code spellcheck="false" style="white-space: pre-wrap;">&lt;AssemblyName&gt;</code> in the <code spellcheck="false" style="white-space: pre-wrap;">.csproj</code> file.</div></div><p></p><p>Now that everything is in place, run the following command:</p><pre><code class="language-bash">bicep local-deploy main.bicepparam</code></pre><p>When the deployment is successful, you'll see a user ID returned:</p><pre><code class="language-plaintext">╭───────────┬──────────┬───────────╮
│ Resource  │ Duration │ Status    │
├───────────┼──────────┼───────────┤
│ adminUser │ 0.9s     │ Succeeded │
╰───────────┴──────────┴───────────╯
╭─────────────┬─────────╮
│ Output      │ Value   │
├─────────────┼─────────┤
│ adminUserId │ 8204520 │
╰─────────────┴─────────╯</code></pre><h2 id="troubleshooting">Troubleshooting</h2><p>Even whilst writing these lessons, issues were encountered. To debug extensions, it's pretty straightforward by adding an environment variable in your existing session:</p><pre><code class="language-powershell">$env:BICEP_TRACING_ENABLED = $true</code></pre><p>When this environment variable is set, additional logging is shown, including the <code>_logger</code> messages.</p><h2 id="summary">Summary</h2><p>In this module, you:</p><ul><li>Scaffolded an extension project from .NET template.</li><li>Created a custom resource model with documentation attributes.</li><li>Implemented a resource handler with <code>Preview</code> and <code>CreateOrUpdate</code> logic.</li><li>Registered your handler in the extension.</li></ul><h2 id="next-steps">Next steps</h2><p>Your extension is functional, but there's more to learn. In the following lessons, you'll:</p><ul><li>Add testing in your project structure.</li><li>Create your documentation.</li><li>Publish the actual extension to a container registry.</li></ul><h2 id="knowledge-check">Knowledge check</h2><ol><li><strong>What is the purpose of the Preview method in a resource handler?</strong></li></ol><p>Answer: Preview checks if a resource exists and populates output properties before deployment, allowing Bicep to show what will be created or updated.</p><ol start="2"><li><strong>Which property flag makes a property required in Bicep?</strong></li></ol><p>Answer: <code>ObjectTypePropertyFlags.Required</code> makes a property required in Bicep deployments.</p><ol start="3"><li><strong>Why do we use separate Identifiers classes?</strong></li></ol><p>Answer: Identifiers classes contain only the properties needed to uniquely identify a resource, which the framework uses to track and manage resource instances.</p><ol start="4"><li><strong>How does the GoRest extension authenticate with the API?</strong></li></ol><p>Answer: The extension uses a token-based authentication scheme where the token is provided in the Configuration class and passed with each API request in the Authorization header.</p>
