CREATE DATABASE IF NOT EXISTS twita_db;

USE twita_db;

DROP TABLE IF EXISTS tweets;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(100) UNIQUE,
    password VARCHAR(255),
    role VARCHAR(20) DEFAULT 'jelata',
    failed_attempts INT DEFAULT 0,
    last_attempt DATETIME DEFAULT NULL,
    locked_until DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_locked_until (locked_until)
);

CREATE TABLE tweets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    content TEXT,
    image_url VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_tweets (user_id),
    INDEX idx_created_at (created_at)
);

-- Insert sample users with hashed passwords
INSERT INTO users (username, email, password) VALUES
('alice', 'alice@example.com', 'password123'),
('bob', 'bob@example.com', 'qwerty');

INSERT INTO tweets (user_id, content) VALUES
(1, 'Hello world!'),
(2, 'Ini tweet dari Bob');
