class AddStartedAtToRounds < ActiveRecord::Migration[8.0]
  def change
    add_column :rounds, :started_at, :datetime
  end
end
