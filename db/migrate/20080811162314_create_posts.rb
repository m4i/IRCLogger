class CreatePosts < ActiveRecord::Migration
  def self.up
    create_table :posts do |t|
      t.string   :command,    :null => false, :limit => 255
      t.integer  :channel_id, :null => false
      t.text     :message,    :null => false
      t.datetime :created_at, :null => false
      t.datetime :posted_at
    end
    add_index :posts, :posted_at
  end

  def self.down
    drop_table :posts
  end
end
