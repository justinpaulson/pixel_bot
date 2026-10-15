class IndexReusableDrawings < ActiveRecord::Migration[8.0]
  def change
    # Existing edition-2 drawings were all made with the current instructions.
    add_column :rounds, :artwork_version, :integer, default: 1, null: false
    add_index :rounds, [ :category, :word, :model, :artwork_version ], name: "index_rounds_on_reusable_artwork"
  end
end
