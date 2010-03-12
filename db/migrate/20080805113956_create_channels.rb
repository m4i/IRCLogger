class CreateChannels < ActiveRecord::Migration
  def self.up
    create_table :channels do |t|
      t.string :name,  :null => false, :limit => 255
      t.string :topic,                 :limit => 255
    end
    add_index :channels, :name, :unique => true
  end

  def self.down
    drop_table :channels
  end
end
