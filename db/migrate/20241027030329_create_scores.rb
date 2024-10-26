class CreateScores < ActiveRecord::Migration[8.0]
  def change
    create_table :scores do |t|
      t.references :user, null: false, foreign_key: true
      t.references :round, null: false, foreign_key: true
      t.integer :points

      t.timestamps
    end
  end
end
