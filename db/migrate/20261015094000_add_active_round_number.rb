class AddActiveRoundNumber < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :active_round_number, :integer, default: 1, null: false
  end
end
