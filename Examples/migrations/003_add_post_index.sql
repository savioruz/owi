-- migrate:up
CREATE INDEX idx_posts_user_id ON posts(user_id);

-- migrate:down
DROP INDEX idx_posts_user_id;
