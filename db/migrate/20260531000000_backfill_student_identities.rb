class BackfillStudentIdentities < ActiveRecord::Migration[8.2]
  # Backfills the cross-organization StudentIdentity link for students that
  # predate identities (rows created before Student#sync_student_identity
  # existed). Mirrors that callback in SQL: find-or-create an identity keyed by
  # the normalised email, then point the student's FK at it. Students without an
  # email are left untouched — they have no identity to link.
  def up
    execute <<~SQL.squish
      INSERT INTO student_identities (email_address, created_at, updated_at)
      SELECT DISTINCT lower(btrim(email)), now(), now()
      FROM students
      WHERE email IS NOT NULL AND btrim(email) <> ''
      ON CONFLICT (email_address) DO NOTHING
    SQL

    execute <<~SQL.squish
      UPDATE students
      SET student_identity_id = student_identities.id
      FROM student_identities
      WHERE students.student_identity_id IS NULL
        AND students.email IS NOT NULL
        AND btrim(students.email) <> ''
        AND student_identities.email_address = lower(btrim(students.email))
    SQL
  end

  # No-op: a backfilled identity may since have been confirmed (password set)
  # or have sessions attached, so dropping identities on rollback is unsafe.
  # Leaving the links in place is harmless.
  def down
  end
end
