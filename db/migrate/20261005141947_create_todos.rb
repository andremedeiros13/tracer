class CreateTodos < ActiveRecord::Migration[8.1]
  def change
    create_table :todos do |t|
      t.string :title, null: false
      t.integer :origin, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :snoozed_until
      t.integer :notified_count, null: false, default: 0

      t.timestamps
    end

    add_index :todos, :status
    add_index :todos, :snoozed_until
  end
end
