CREATE TABLE IF NOT EXISTS user_home_icon_orders (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  icon_order_json TEXT NOT NULL DEFAULT '[]'
);
