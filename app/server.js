const express = require('express');
const { Pool } = require('pg');
const path = require('path');
const bcrypt = require('bcrypt');
const session = require('express-session');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'startuphub-secret-key-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false, // Set to true if using HTTPS
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Database connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: {
    rejectUnauthorized: false, // Required for RDS
  },
  connectionTimeoutMillis: 5000,
});

// Track database status
let dbConnected = false;

// Initialize database schema on startup
async function initializeDatabase() {
  try {
    const client = await pool.connect();
    try {
      // Create users table
      await client.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          username VARCHAR(50) UNIQUE NOT NULL,
          password_hash VARCHAR(255) NOT NULL,
          role VARCHAR(20) DEFAULT 'user',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Create tasks table with new fields
      await client.query(`
        CREATE TABLE IF NOT EXISTS tasks (
          id SERIAL PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          status VARCHAR(20) DEFAULT 'todo',
          priority VARCHAR(20) DEFAULT 'medium',
          category VARCHAR(50),
          due_date DATE,
          owner_id INTEGER REFERENCES users(id),
          created_by INTEGER REFERENCES users(id),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Add columns if they don't exist (migration for existing tables)
      await client.query(`
        DO $$
        BEGIN
          -- Add status column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='status') THEN
            ALTER TABLE tasks ADD COLUMN status VARCHAR(20) DEFAULT 'todo';
          END IF;

          -- Add priority column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='priority') THEN
            ALTER TABLE tasks ADD COLUMN priority VARCHAR(20) DEFAULT 'medium';
          END IF;

          -- Add category column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='category') THEN
            ALTER TABLE tasks ADD COLUMN category VARCHAR(50);
          END IF;

          -- Add due_date column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='due_date') THEN
            ALTER TABLE tasks ADD COLUMN due_date DATE;
          END IF;

          -- Add owner_id column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='owner_id') THEN
            ALTER TABLE tasks ADD COLUMN owner_id INTEGER REFERENCES users(id);
          END IF;

          -- Add created_by column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='created_by') THEN
            ALTER TABLE tasks ADD COLUMN created_by INTEGER REFERENCES users(id);
          END IF;

          -- Add updated_at column if not exists
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='updated_at') THEN
            ALTER TABLE tasks ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
          END IF;
        END $$;
      `);

      // Create default admin user if not exists
      const adminExists = await client.query(
        'SELECT id FROM users WHERE username = $1',
        ['admin']
      );

      if (adminExists.rows.length === 0) {
        const hashedPassword = await bcrypt.hash('admin123', 10);
        await client.query(
          'INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3)',
          ['admin', hashedPassword, 'admin']
        );
        console.log('✅ Default admin user created (username: admin, password: admin123)');
      }

      console.log('✅ Database tables initialized successfully');
      dbConnected = true;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('❌ Failed to initialize database:', err.message);
    console.error('App will continue but database operations may fail');
  }
}

// Authentication middleware
function requireAuth(req, res, next) {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

// Admin middleware
function requireAdmin(req, res, next) {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  if (req.session.userRole !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

// Login endpoint
app.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    const result = await pool.query(
      'SELECT id, username, password_hash, role FROM users WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);

    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Set session
    req.session.userId = user.id;
    req.session.username = user.username;
    req.session.userRole = user.role;

    res.json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Logout endpoint
app.post('/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' });
    }
    res.json({ success: true });
  });
});

// Check auth status
app.get('/auth/status', (req, res) => {
  if (req.session.userId) {
    res.json({
      authenticated: true,
      user: {
        id: req.session.userId,
        username: req.session.username,
        role: req.session.userRole
      }
    });
  } else {
    res.json({ authenticated: false });
  }
});

// Get all users (admin only)
app.get('/users', requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, role, created_at FROM users ORDER BY username'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching users:', err.message);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Create user (admin only)
app.post('/users', requireAdmin, async (req, res) => {
  try {
    const { username, password, role } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userRole = role || 'user';

    const result = await pool.query(
      'INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3) RETURNING id, username, role',
      [username, hashedPassword, userRole]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating user:', err.message);
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Username already exists' });
    }
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// Delete user (admin only)
app.delete('/users/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = parseInt(id);

    // Prevent deleting yourself
    if (userId === req.session.userId) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }

    // Check if user exists
    const userCheck = await pool.query(
      'SELECT id, username FROM users WHERE id = $1',
      [userId]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Delete user
    await pool.query('DELETE FROM users WHERE id = $1', [userId]);

    res.json({ success: true, message: 'User deleted successfully' });
  } catch (err) {
    console.error('Error deleting user:', err.message);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Get all tasks (filtered by user role)
app.get('/api/tasks', requireAuth, async (req, res) => {
  try {
    const isAdmin = req.session.userRole === 'admin';
    const userId = req.session.userId;

    let query = `
      SELECT t.*, u.username as owner_name, c.username as created_by_name
      FROM tasks t
      LEFT JOIN users u ON t.owner_id = u.id
      LEFT JOIN users c ON t.created_by = c.id
    `;
    
    let params = [];
    
    // Regular users can only see tasks assigned to them
    if (!isAdmin) {
      query += ' WHERE t.owner_id = $1';
      params.push(userId);
    }
    
    query += ' ORDER BY t.created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching tasks:', err.message);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Create task
app.post('/api/tasks', requireAuth, async (req, res) => {
  try {
    const { title, description, status, priority, category, due_date, owner_id } = req.body;
    
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }

    // Only admins can assign tasks to others
    const isAdmin = req.session.userRole === 'admin';
    const finalOwnerId = isAdmin ? owner_id : req.session.userId;

    const result = await pool.query(`
      INSERT INTO tasks (title, description, status, priority, category, due_date, owner_id, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [
      title,
      description || null,
      status || 'todo',
      priority || 'medium',
      category || null,
      due_date || null,
      finalOwnerId,
      req.session.userId
    ]);

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating task:', err.message);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Update task
app.put('/api/tasks/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, status, priority, category, due_date, owner_id } = req.body;

    // Check if user owns the task or is admin
    const taskCheck = await pool.query(
      'SELECT owner_id FROM tasks WHERE id = $1',
      [id]
    );

    if (taskCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = taskCheck.rows[0];
    const isAdmin = req.session.userRole === 'admin';
    const isOwner = task.owner_id === req.session.userId;

    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: 'Not authorized to edit this task' });
    }

    // Only admins can reassign tasks to others
    const finalOwnerId = isAdmin ? owner_id : task.owner_id;

    const result = await pool.query(`
      UPDATE tasks
      SET title = $1, description = $2, status = $3, priority = $4,
          category = $5, due_date = $6, owner_id = $7, updated_at = CURRENT_TIMESTAMP
      WHERE id = $8
      RETURNING *
    `, [title, description, status, priority, category, due_date, finalOwnerId, id]);

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating task:', err.message);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// Delete task
app.delete('/api/tasks/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if user owns the task or is admin
    const taskCheck = await pool.query(
      'SELECT owner_id FROM tasks WHERE id = $1',
      [id]
    );

    if (taskCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = taskCheck.rows[0];
    const isAdmin = req.session.userRole === 'admin';
    const isOwner = task.owner_id === req.session.userId;

    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: 'Not authorized to delete this task' });
    }

    await pool.query('DELETE FROM tasks WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting task:', err.message);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// Get task stats (overall and per-user)
app.get('/api/stats', requireAuth, async (req, res) => {
  try {
    const isAdmin = req.session.userRole === 'admin';
    const userId = req.session.userId;

    // Overall stats
    let overallQuery = `
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'todo') as todo,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress,
        COUNT(*) FILTER (WHERE status = 'done') as done,
        COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status != 'done') as overdue
      FROM tasks
    `;
    
    let overallParams = [];
    
    // Regular users only see their own stats
    if (!isAdmin) {
      overallQuery += ' WHERE owner_id = $1';
      overallParams.push(userId);
    }

    const overallResult = await pool.query(overallQuery, overallParams);

    // Per-user stats (admin only)
    let userStats = [];
    if (isAdmin) {
      const userStatsResult = await pool.query(`
        SELECT 
          u.id,
          u.username,
          COUNT(t.id) as total_tasks,
          COUNT(t.id) FILTER (WHERE t.status = 'done') as completed_tasks,
          CASE 
            WHEN COUNT(t.id) = 0 THEN 0
            ELSE ROUND((COUNT(t.id) FILTER (WHERE t.status = 'done')::numeric / COUNT(t.id)::numeric) * 100, 1)
          END as completion_percentage
        FROM users u
        LEFT JOIN tasks t ON u.id = t.owner_id
        GROUP BY u.id, u.username
        ORDER BY u.username
      `);
      userStats = userStatsResult.rows;
    }

    res.json({
      ...overallResult.rows[0],
      userStats: userStats
    });
  } catch (err) {
    console.error('Error fetching stats:', err.message);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Health check endpoint (for ALB)
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
    console.log(`🚀 StartupHub Task Manager running on port ${PORT}`);
    console.log(`📊 Database host: ${process.env.DB_HOST || 'not set'}`);
    console.log(`🗄️  Database name: ${process.env.DB_NAME || 'not set'}`);
    console.log(`👤 Default admin: username: admin, password: admin123`);
  });
});
