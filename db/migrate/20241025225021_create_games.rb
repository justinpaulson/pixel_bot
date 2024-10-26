class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games, id: false do |t|
      t.string :id, primary_key: true
      t.datetime :started_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
