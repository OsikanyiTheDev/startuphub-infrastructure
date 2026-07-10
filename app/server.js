const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Database connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: false,
  connectionTimeoutMillis: 5000,
});

// Track database status
let dbConnected = false;

// Initialize database schema on startup
async function initializeDatabase() {
  try {
    const client = await pool.connect();
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS tasks (
          id SERIAL PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          status VARCHAR(50) DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Database table initialized successfully');
      dbConnected = true;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('Failed to initialize database:', err.message);
    console.error('App will continue but database operations may fail');
  }
}

// Health check endpoint (used by ALB)
app.get('/', async (req, res) => {
  const html = `
<!DOCTYPE html>
<html>
<head>
  <title>StartupHub - Task Manager</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; }
    h1 { color: #2c3e50; margin-bottom: 10px; }
    .subtitle { color: #7f8c8d; margin-bottom: 30px; }
    .status { padding: 10px 15px; border-radius: 5px; margin-bottom: 20px; }
    .status.ok { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
    .status.error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
    .card { background: white; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .task-form { display: flex; gap: 10px; flex-wrap: wrap; }
    .task-form input, .task-form button { padding: 10px 15px; border-radius: 5px; font-size: 14px; }
    .task-form input { flex: 1; border: 1px solid #ddd; min-width: 200px; }
    .task-form button { background: #3498db; color: white; border: none; cursor: pointer; }
    .task-form button:hover { background: #2980b9; }
    .task-list { list-style: none; }
    .task-item { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid #eee; }
    .task-item:last-child { border-bottom: none; }
    .task-title { font-weight: 500; }
    .task-meta { font-size: 12px; color: #95a5a6; }
    .task-delete { background: #e74c3c; color: white; border: none; padding: 5px 12px; border-radius: 4px; cursor: pointer; font-size: 12px; }
    .task-delete:hover { background: #c0392b; }
    .empty { text-align: center; padding: 40px; color: #95a5a6; }
    .instance-info { font-size: 12px; color: #95a5a6; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 StartupHub Task Manager</h1>
    <p class="subtitle">Powered by Node.js, Express & PostgreSQL on AWS</p>

    <div class="status ${dbConnected ? 'ok' : 'error'}">
      ${dbConnected ? '✅ Database Connected' : '❌ Database Disconnected'}
    </div>

    <div class="card">
      <h2 style="margin-bottom: 15px;">Add New Task</h2>
      <form class="task-form" onsubmit="addTask(event)">
        <input type="text" id="taskTitle" placeholder="What needs to be done?" required>
        <button type="submit">Add Task</button>
      </form>
    </div>

    <div class="card">
      <h2 style="margin-bottom: 15px;">Tasks</h2>
      <ul class="task-list" id="taskList">
        <li class="empty">Loading tasks...</li>
      </ul>
    </div>

    <p class="instance-info">Instance: ${process.env.HOSTNAME || 'unknown'} | Time: ${new Date().toISOString()}</p>
  </div>

  <script>
    async function loadTasks() {
      try {
        const res = await fetch('/api/tasks');
        const tasks = await res.json();
        const list = document.getElementById('taskList');
        if (tasks.length === 0) {
          list.innerHTML = '<li class="empty">No tasks yet. Add one above!</li>';
          return;
        }
        list.innerHTML = tasks.map(t => \`
          <li class="task-item">
            <div>
              <div class="task-title">\${t.title}</div>
              <div class="task-meta">\${t.status} • \${new Date(t.created_at).toLocaleString()}</div>
            </div>
            <button class="task-delete" onclick="deleteTask(\${t.id})">Delete</button>
          </li>
        \`).join('');
      } catch (err) {
        document.getElementById('taskList').innerHTML = '<li class="empty">Failed to load tasks</li>';
      }
    }

    async function addTask(event) {
      event.preventDefault();
      const title = document.getElementById('taskTitle').value;
      await fetch('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title })
      });
      document.getElementById('taskTitle').value = '';
      loadTasks();
    }

    async function deleteTask(id) {
      await fetch('/api/tasks/' + id, { method: 'DELETE' });
      loadTasks();
    }

    loadTasks();
    setInterval(loadTasks, 10000);
  </script>
</body>
</html>`;

  res.status(200).send(html);
});

// API: Get all tasks
app.get('/api/tasks', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, title, description, status, created_at FROM tasks ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching tasks:', err.message);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// API: Create a task
app.post('/api/tasks', async (req, res) => {
  try {
    const { title, description } = req.body;
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    const result = await pool.query(
      'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING id, title, description, status, created_at',
      [title, description || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating task:', err.message);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// API: Delete a task
app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM tasks WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting task:', err.message);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// API: Health check (for ALB)
app.get('/health', async (req, res) => {
  try {
    const client = await pool.connect();
    try {
      await client.query('SELECT 1');
      res.status(200).json({ status: 'healthy', database: 'connected' });
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

// Start server
initializeDatabase().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`StartupHub app listening on port ${PORT}`);
    console.log(`Database host: ${process.env.DB_HOST || 'not set'}`);
    console.log(`Database name: ${process.env.DB_NAME || 'not set'}`);
  });
});
