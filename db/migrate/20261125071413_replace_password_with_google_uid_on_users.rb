# Users now sign in with Google and are keyed on Google's stable account id.
# The old password accounts can no longer sign in, so they are deleted
# (production had none; the only expected row is the dev seed user).
class ReplacePasswordWithGoogleUidOnUsers < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM sessions"
    execute "DELETE FROM users"

    remove_column :users, :password_digest
    add_column :users, :google_uid, :string, null: false
    add_index :users, :google_uid, unique: true

    # Email is for display only and can move between Google accounts.
    remove_index :users, :email_address
    add_index :users, :email_address
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
