class AddDrawingModelToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :drawing_model, :string, default: "gpt-6-astra", null: false
  end
end
