/**
 * Todo API - A working app connected to Azure resources
 * 
 * This app demonstrates a functional application where:
 * - The app works perfectly fine
 * - But the infrastructure has security issues (expiring secrets, open NSG rules, missing DNS link)
 * 
 * Architecture:
 * - App Service with VNet integration (traffic goes through subnet with insecure NSG)
 * - Key Vault secrets (which are expiring soon!)
 * - Azure Storage for todo attachments
 */

const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const { BlobServiceClient } = require('@azure/storage-blob');

const app = express();
app.use(express.json());

// In-memory todo storage (simple for demo purposes)
let todos = [];
let nextId = 1;

// Azure clients (initialized on startup)
let secretClient = null;
let blobContainerClient = null;
let configuredSecrets = {};

// ============================================================================
// STARTUP: Initialize Azure connections
// ============================================================================
async function initializeAzureClients() {
  const credential = new DefaultAzureCredential();

  // Initialize Key Vault client
  const keyVaultName = process.env.KEY_VAULT_NAME;
  if (keyVaultName) {
    const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
    secretClient = new SecretClient(keyVaultUrl, credential);
    console.log(`✅ Connected to Key Vault: ${keyVaultName}`);

    // Read secrets (these are expiring soon - SRE Agent should detect!)
    try {
      const sqlSecret = await secretClient.getSecret('sql-connection-string');
      configuredSecrets['sql-connection-string'] = '***configured***';
      console.log(`   📋 Loaded secret: sql-connection-string (expires: ${sqlSecret.properties.expiresOn})`);

      const apiKeySecret = await secretClient.getSecret('api-key-external');
      configuredSecrets['api-key-external'] = '***configured***';
      console.log(`   📋 Loaded secret: api-key-external (expires: ${apiKeySecret.properties.expiresOn})`);
    } catch (err) {
      console.warn(`   ⚠️ Could not load secrets: ${err.message}`);
    }
  }

  // Initialize Storage client
  const storageAccountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;
  const containerName = process.env.AZURE_STORAGE_CONTAINER_NAME || 'data';
  if (storageAccountName) {
    const blobServiceClient = new BlobServiceClient(
      `https://${storageAccountName}.blob.core.windows.net`,
      credential
    );
    blobContainerClient = blobServiceClient.getContainerClient(containerName);
    console.log(`✅ Connected to Storage: ${storageAccountName}/${containerName}`);
  }

  console.log('\n🚀 Azure integrations initialized');
}

// ============================================================================
// HEALTH CHECK: Shows infrastructure status
// ============================================================================
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    app: 'Todo API',
    version: '1.0.0',
    connections: {
      keyVault: secretClient !== null,
      storage: blobContainerClient !== null
    }
  };
  res.json(health);
});

// ============================================================================
// TODO CRUD OPERATIONS
// ============================================================================

// GET /todos - List all todos
app.get('/todos', (req, res) => {
  res.json({
    count: todos.length,
    items: todos
  });
});

// GET /todos/:id - Get a specific todo
app.get('/todos/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const todo = todos.find(t => t.id === id);
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  res.json(todo);
});

// POST /todos - Create a new todo
app.post('/todos', async (req, res) => {
  const { title, description } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const todo = {
    id: nextId++,
    title,
    description: description || '',
    completed: false,
    createdAt: new Date().toISOString()
  };

  todos.push(todo);

  // Store in blob storage for persistence (if available)
  if (blobContainerClient) {
    try {
      const blobClient = blobContainerClient.getBlockBlobClient(`todos/${todo.id}.json`);
      await blobClient.upload(JSON.stringify(todo), JSON.stringify(todo).length, {
        blobHTTPHeaders: { blobContentType: 'application/json' }
      });
      todo.storedInBlob = true;
    } catch (err) {
      console.warn(`Could not store todo in blob: ${err.message}`);
      todo.storedInBlob = false;
    }
  }

  res.status(201).json(todo);
});

// PUT /todos/:id - Update a todo
app.put('/todos/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  const todoIndex = todos.findIndex(t => t.id === id);
  if (todoIndex === -1) {
    return res.status(404).json({ error: 'Todo not found' });
  }

  const { title, description, completed } = req.body;
  const todo = todos[todoIndex];
  
  if (title !== undefined) todo.title = title;
  if (description !== undefined) todo.description = description;
  if (completed !== undefined) todo.completed = completed;
  todo.updatedAt = new Date().toISOString();

  // Update in blob storage
  if (blobContainerClient) {
    try {
      const blobClient = blobContainerClient.getBlockBlobClient(`todos/${todo.id}.json`);
      await blobClient.upload(JSON.stringify(todo), JSON.stringify(todo).length, {
        blobHTTPHeaders: { blobContentType: 'application/json' },
        overwrite: true
      });
    } catch (err) {
      console.warn(`Could not update todo in blob: ${err.message}`);
    }
  }

  res.json(todo);
});

// DELETE /todos/:id - Delete a todo
app.delete('/todos/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  const todoIndex = todos.findIndex(t => t.id === id);
  if (todoIndex === -1) {
    return res.status(404).json({ error: 'Todo not found' });
  }

  const [deleted] = todos.splice(todoIndex, 1);

  // Delete from blob storage
  if (blobContainerClient) {
    try {
      const blobClient = blobContainerClient.getBlockBlobClient(`todos/${id}.json`);
      await blobClient.deleteIfExists();
    } catch (err) {
      console.warn(`Could not delete todo from blob: ${err.message}`);
    }
  }

  res.json({ message: 'Todo deleted', todo: deleted });
});

// ============================================================================
// ROOT: Simple landing page
// ============================================================================
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Todo API</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #0078d4; }
        .card { background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
        code { background: #e1e1e1; padding: 2px 6px; border-radius: 4px; }
        a { color: #0078d4; }
      </style>
    </head>
    <body>
      <h1>✅ Todo API</h1>
      <p>A simple Todo application running on Azure App Service.</p>

      <div class="card">
        <h3>API Endpoints</h3>
        <ul>
          <li><code>GET</code> <a href="/health">/health</a> - Health check</li>
          <li><code>GET</code> <a href="/todos">/todos</a> - List all todos</li>
          <li><code>POST</code> /todos - Create a todo</li>
          <li><code>PUT</code> /todos/:id - Update a todo</li>
          <li><code>DELETE</code> /todos/:id - Delete a todo</li>
        </ul>
      </div>

      <div class="card">
        <h3>Try it out</h3>
        <p>Create a todo:</p>
        <code>curl -X POST -H "Content-Type: application/json" -d '{"title":"My first todo"}' ${req.protocol}://${req.get('host')}/todos</code>
      </div>
    </body>
    </html>
  `);
});

// ============================================================================
// START SERVER
// ============================================================================
const PORT = process.env.PORT || 3000;

initializeAzureClients()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`\n🎯 Todo API listening on port ${PORT}`);
      console.log(`   Health: http://localhost:${PORT}/health`);
      console.log(`   Todos:  http://localhost:${PORT}/todos`);
    });
  })
  .catch(err => {
    console.error('Failed to initialize Azure clients:', err);
    // Start anyway - app can still work with in-memory storage
    app.listen(PORT, () => {
      console.log(`\n🎯 Todo API listening on port ${PORT} (without Azure integrations)`);
    });
  });
