class AddCompletedAtToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :completed_at, :datetime
  end
end
