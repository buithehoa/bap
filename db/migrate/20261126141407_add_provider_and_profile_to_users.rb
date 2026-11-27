class AddProviderAndProfileToUsers < ActiveRecord::Migration[8.1]
  # Roll forward only: once Facebook users exist (or any user has no email) this can't be rolled back,
  # and old releases expect `google_uid`, so don't redeploy a pre-migration image.
  def change
    rename_column :users, :google_uid, :uid

    # Existing rows were all created through Google, so the default backfills them.
    add_column :users, :provider, :string, null: false, default: "google_oauth2"
    change_column_default :users, :provider, from: "google_oauth2", to: nil

    remove_index :users, :uid, unique: true
    add_index :users, [ :provider, :uid ], unique: true

    add_column :users, :name, :string
    add_column :users, :image_url, :string

    change_column_null :users, :email_address, true
  end
end
