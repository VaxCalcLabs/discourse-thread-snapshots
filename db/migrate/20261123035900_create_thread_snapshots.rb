# frozen_string_literal: true

class CreateThreadSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :thread_snapshots do |t|
      t.bigint :topic_id, null: false
      t.bigint :user_id, null: false
      t.string :token, null: false
      t.text :title, null: false
      t.jsonb :posts_data, null: false, default: []
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :thread_snapshots, :token, unique: true
    add_index :thread_snapshots, :expires_at
    add_index :thread_snapshots, :topic_id
  end
end
