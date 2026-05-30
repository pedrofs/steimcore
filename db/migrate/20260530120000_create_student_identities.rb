class CreateStudentIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :student_identities, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email_address, null: false
      t.string :password_digest
      t.datetime :last_invited_at
      t.timestamps
    end

    add_index :student_identities, :email_address, unique: true
  end
end
