class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games, id: false do |t|
      t.string :id, primary_key: true
      t.timestamps
    end
  end
end
