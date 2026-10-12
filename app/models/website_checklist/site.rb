module WebsiteChecklist
  # A client's website and the checklist to take it live: what to gather and record, step by
  # step, each recorded and confirmed by a person.
  class Site < ApplicationRecord
    include Audited

    # Left from reading a CMS (before 0.3); dropped in a later release.
    self.ignored_columns += %w[cms_url cms_token synced_at sync_error]

    Summary = Data.define(:total, :confirmed, :unconfirmed, :not_applicable) do
      def ready? = total.positive? && confirmed == total
      def to_h = super.merge(ready: ready?)
      def to_s = ready? ? "All #{total} confirmed" : "#{confirmed} of #{total} confirmed"
    end

    # Before the items go, without a callback each: what points at them, and their files.
    before_destroy do
      Webhook.where(item_id: items.select(:id)).delete_all
      Recommendation.where(item_id: items.select(:id)).delete_all
      todo_links.delete_all
      ActiveStorage::Attachment.where(record_type: Item.name, record_id: items.select(:id)).find_each(&:purge_later)
    end

    belongs_to :client
    has_many :items, -> { ordered }, dependent: :delete_all
    has_many :scans, dependent: :destroy
    has_many :todo_links, dependent: :delete_all

    normalizes :url, with: ->(url) { url.strip.chomp("/").presence }
    normalizes :name, with: ->(name) { name.strip }

    validates :name, presence: true
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_nil: true

    after_create :apply_standard_checklist

    # By address, A to Z, without its scheme or a leading "www."; those without one last, by name.
    ADDRESS = "LOWER(REPLACE(REPLACE(url, 'https://', ''), 'http://', ''))"
    scope :ordered, -> { order(Arel.sql("url IS NULL, CASE WHEN #{ADDRESS} LIKE 'www.%' THEN SUBSTR(#{ADDRESS}, 5) ELSE #{ADDRESS} END, name")) }

    # The address's host, without a leading "www.".
    def host
      (URI.parse(url.to_s).host || url)&.delete_prefix("www.")
    rescue URI::InvalidURIError
      url
    end

    def revise(attributes) = update(attributes)

    # Counts over the items that apply (not the ones marked not applicable).
    def summary
      list = items.to_a
      applicable = list.reject(&:not_applicable?)
      Summary.new(total: applicable.size, confirmed: applicable.count(&:confirmed?),
        unconfirmed: applicable.count { !it.confirmed? }, not_applicable: list.size - applicable.size)
    end

    def needs_attention? = !summary.ready?

    def to_s = name

    # The first step still to do, in order: where the checklist picks up.
    def next_item = items.find { !it.settled? }

    # The standard checklist (Site::Defaults), added where missing and put in its order with its
    # current wording. Custom items follow, in the order they were added.
    def apply_standard_checklist
      existing = items.reload.index_by(&:key)
      now = Time.current
      Defaults::ITEMS.each_with_index do |default, index|
        attributes = default.slice(:group, :title, :detail).merge(position: index * 10)
        if (item = existing[default[:key]])
          item.update_columns(attributes.merge(updated_at: now)) if attributes.any? { |name, value| item[name] != value }
        else
          Item.insert!(attributes.merge(key: default[:key], site_id: id, created_at: now, updated_at: now))
        end
      end
      items.reset
    end

    private
      def audit_site = self
      def audit_value(field, value) = field == "client_id" ? Client.find_by(id: value)&.name : super
  end
end
