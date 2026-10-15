class ReimaginePixel < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :display_name, :string
    add_column :users, :guest, :boolean, default: false, null: false
    add_column :games, :mode, :string, default: "party", null: false
    add_column :games, :category, :string, default: "mix", null: false
    add_column :games, :round_limit, :integer, default: 5, null: false
    add_column :games, :edition, :integer, default: 1, null: false
    add_column :rounds, :category, :string
    add_column :rounds, :aliases, :json, default: [], null: false
    add_column :rounds, :hint, :string
    add_column :rounds, :status, :string, default: "pending", null: false
    add_column :rounds, :svg, :text
    add_column :rounds, :model, :string
    add_column :rounds, :generation_token, :string
    add_column :rounds, :generation_started_at, :datetime
    add_column :rounds, :generation_seconds, :float
    add_column :rounds, :ended_at, :datetime
    add_column :rounds, :error_message, :string
    add_column :players, :last_seen_at, :datetime
    # Preserve historical records, removing only duplicate memberships / scores.
    reversible do |dir|
      dir.up do
        execute "DELETE FROM players WHERE id NOT IN (SELECT MIN(id) FROM players GROUP BY game_id, user_id)"
        execute "DELETE FROM scores WHERE id NOT IN (SELECT MIN(id) FROM scores GROUP BY round_id, user_id)"
      end
    end
    add_index :players, [ :game_id, :user_id ], unique: true
    add_index :scores, [ :round_id, :user_id ], unique: true
    add_index :rounds, [ :game_id, :number ], unique: true
  end
end
