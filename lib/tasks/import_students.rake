require "csv"

namespace :students do
  desc "Import students from a CSV (default: db/seeds/clientes-13_05_2026.csv). Override path with CSV=..."
  task import: :environment do
    path = ENV.fetch("CSV", Rails.root.join("db/seeds/clientes-13_05_2026.csv").to_s)
    abort "CSV not found at #{path}" unless File.exist?(path)

    organizations = Organization.all.to_a
    case organizations.size
    when 0 then abort "No Organization in the database. Create one before importing."
    when 1 then # ok
    else abort "Multiple organizations found (#{organizations.map(&:name).join(', ')}). Refusing to guess; this task imports into the only org."
    end
    organization = organizations.first

    puts "Importing into organization: #{organization.name} (#{organization.id})"
    puts "Reading: #{path}"

    created = 0
    skipped_existing = 0
    skipped_blank = 0
    failed = 0

    CSV.foreach(path, headers: true) do |row|
      name = row["Nome"]&.strip
      if name.blank?
        skipped_blank += 1
        next
      end

      email = row["E-mail"]&.strip&.downcase.presence
      email = nil unless email&.include?("@") # drop junk values in the email column
      phone = row["Telefone"]&.strip.presence
      sex = sniff_sex(row)
      birthday = sniff_birthday(row)

      if email && organization.students.exists?(email: email, name: name)
        puts "  SKIP existing (name+email): #{name} <#{email}>"
        skipped_existing += 1
        next
      end

      begin
        organization.students.create!(
          name: name,
          email: email,
          phone: phone,
          sex: sex,
          birthday: birthday
        )
        created += 1
        puts "  OK    #{name}#{" <#{email}>" if email}"
      rescue ActiveRecord::RecordInvalid => e
        failed += 1
        puts "  FAIL  #{name}: #{e.record.errors.full_messages.to_sentence}"
      end
    end

    puts ""
    puts "Done. created=#{created} skipped_existing=#{skipped_existing} skipped_blank=#{skipped_blank} failed=#{failed}"
  end
end

# Look for "Masculino" or "Feminino" in any field on the row. Returns the
# canonical form or nil. The source CSV has malformed rows where columns shift,
# so we don't trust the Sexo column position.
def sniff_sex(row)
  row.fields.each do |value|
    next if value.nil?
    case value.to_s.strip.downcase
    when "masculino", "m", "masc" then return "Masculino"
    when "feminino",  "f", "fem"  then return "Feminino"
    end
  end
  nil
end

# Look for Excel/Sheets date serials anywhere on the row and pick the smallest
# one that lands in a plausible birth-year window (1920–2014). The source CSV
# has both "Data de nascimento" and "Data de cadastro" as serials, and columns
# shift in some rows — taking the smallest in-range value reliably yields the
# birthday over the registration date.
def sniff_birthday(row)
  excel_epoch = Date.new(1899, 12, 30)
  min_serial = (Date.new(1920, 1, 1) - excel_epoch).to_i
  max_serial = (Date.new(2014, 12, 31) - excel_epoch).to_i

  candidates = row.fields.filter_map do |value|
    next if value.nil?
    serial = Float(value.to_s.strip, exception: false)
    next if serial.nil?
    int = serial.to_i
    next unless int.between?(min_serial, max_serial)
    int
  end

  return nil if candidates.empty?
  excel_epoch + candidates.min
end
