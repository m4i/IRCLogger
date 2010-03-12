class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.string   :command,    :null => false, :limit => 255
      t.integer  :channel_id, :null => false
      t.integer  :user_id,    :null => false
      t.string   :nickname,   :null => false, :limit => 255
      t.text     :message,    :null => false
      t.datetime :timestamp,  :null => false
    end
    add_index :messages, :channel_id
    add_index :messages, :user_id
    add_index :messages, :timestamp
  end

  def self.down
    drop_table :messages
  end
end
