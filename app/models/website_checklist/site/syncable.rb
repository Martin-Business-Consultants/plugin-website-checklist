module WebsiteChecklist
  # A site run by the CMS fills in what the CMS can tell (Site::CmsReading): the sender, each
  # published form's emails and where it posts, the webhooks, the sitemap and the domain. What a
  # person confirmed stays; a detected value that no longer matches it shows as changed.
  module Site::Syncable
    extend ActiveSupport::Concern

    included do
      scope :cms_linked, -> { where.not(cms_url: nil) }
    end

    class_methods do
      # The nightly run: every site the CMS runs.
      def sync_all_later = cms_linked.find_each(&:sync_later)
    end

    def sync_later = Site::SyncJob.perform_later(self)

    # Never raises: what went wrong is kept in sync_error, and the checklist keeps working.
    def sync_now
      return false unless cms_linked?

      reading = Site::CmsReading.new(cms)
      transaction do
        apply(reading)
        update!(synced_at: Time.current, sync_error: reading.errors.join("\n").presence)
      end
      reading.errors.empty?
    rescue StandardError => error
      Rails.logger.error("[website_checklist] syncing site #{id}: #{error.class}: #{error.message}")
      update_columns(synced_at: Time.current, sync_error: "Couldn't sync: #{error.message}")
      false
    end

    def cms = Cms.new(cms_url, cms_token)

    private
      def apply(reading)
        existing = items.reload.index_by(&:key)
        last = existing.values.map(&:position).max.to_i
        reading.detections.each do |detection|
          item = existing[detection.key] || items.build(key: detection.key, group: detection.group, title: detection.title,
            detail: detection.detail, position: detection.position || (last += 1))
          item.subject = detection.subject if detection.subject
          if detection.detected
            item.detect(value: detection.value, problem: detection.problem, href: detection.href, detail: detection.detail)
          else
            item.save!
          end
        end
        apply_forms(reading.form_slugs) if reading.forms_read?
      end

      # The CMS's forms stand in for the standard Forms items once there are any (those nobody
      # has touched go), and a form no longer published says so rather than vanishing.
      def apply_forms(slugs)
        if slugs.any?
          items.where("key LIKE ?", "forms:any:%").where(state: "unconfirmed", value: nil, note: nil).delete_all
        end
        gone = items.where("key LIKE ?", "forms:%").where.not("key LIKE ?", "forms:any:%").pluck(:id, :key)
          .reject { |_, key| slugs.include?(key.split(":")[1]) }.map(&:first)
        items.where(id: gone).update_all(problem: "No longer a published form in the CMS.", updated_at: Time.current)
      end
  end
end
