-- Add missing columns for brute force protection
USE twita_db;

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS failed_attempts INT DEFAULT 0 AFTER role,
ADD COLUMN IF NOT EXISTS last_attempt DATETIME DEFAULT NULL AFTER failed_attempts,
ADD COLUMN IF NOT EXISTS locked_until DATETIME DEFAULT NULL AFTER last_attempt;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_locked_until ON users(locked_until);
CREATE INDEX IF NOT EXISTS idx_user_tweets ON tweets(user_id);
CREATE INDEX IF NOT EXISTS idx_created_at ON tweets(created_at);
