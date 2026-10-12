module WebsiteChecklist
  # What an AI audit (Scan) suggests recording on one step: a value, a note, the fact it comes
  # from and how sure it is. A person approves it (as it is, or changed first), which records it
  # on the step as theirs and attaches any file it brought (the sitemap), or rejects it.
  class Recommendation < ApplicationRecord
    STATES = %w[pending approved rejected].freeze

    belongs_to :scan, inverse_of: :recommendations
    belongs_to :item

    validates :state, inclusion: { in: STATES }

    def pending? = state == "pending"

    def approve!(by:, value: self.value, note: self.note)
      value = value.to_s.strip.presence
      unless value
        errors.add(:value, "can't be blank")
        return false
      end

      transaction do
        item.record({ value: value, note: [ item.note, note.to_s.strip.presence ].compact.uniq.join("\n").presence }, by: by) or raise ActiveRecord::Rollback
        if attach_file.present? && (file = scan.files.attachments.find { it.filename.to_s == attach_file })
          item.add_file(io: StringIO.new(file.download), filename: file.filename.to_s, content_type: file.content_type)
        end
        update!(state: "approved", value: value, note: note.to_s.strip.presence, decided_by_name: by.display_name, decided_at: Time.current)
      end
      approved?
    end

    def reject!(by:) = update!(state: "rejected", decided_by_name: by.display_name, decided_at: Time.current)

    def approved? = state == "approved"
  end
end
