module WebsiteChecklist
  # Keeps an Audit of every create, change and delete: the fields that changed, before and after,
  # written as people read them (a state's label, a client's name), with who did it. Inside the
  # save's transaction, so a change that's rolled back leaves no trace.
  module Audited
    extend ActiveSupport::Concern

    UNAUDITED = %w[id key site_id item_id position created_at updated_at confirmed_at confirmed_by_name].freeze

    included do
      after_create { audit "created", saved_changes.transform_values { [ nil, it.last ] } }
      after_update { audit "updated", saved_changes }
      after_destroy { audit "deleted", attributes.transform_values { [ it, nil ] } }
    end

    private
      def audit(action, changes)
        diff = changes.except(*UNAUDITED).to_h { |field, (before, after)| [ field, [ audit_value(field, before), audit_value(field, after) ] ] }
          .reject { |_, (before, after)| before == after }
        return if action == "updated" && diff.empty?

        Audit.create!(site_id: audit_site&.id, site_name: audit_site&.name, item_id: audit_item_id, record_type: self.class.name.demodulize,
          record_id: id, record_label: audit_label, action: audit_action(action, diff), diff: diff,
          actor_id: Current.user&.id, actor_name: Current.user&.display_name, source: Current.source.presence || "app",
          via: (Current.access_token.try(:name) if Current.agent?))
      end

      # A value as people read it; blank is nil.
      def audit_value(_field, value)
        case value
        when Array then value.map { it.is_a?(Hash) ? "#{it["key"]}: #{it["value"]}" : it.to_s }.join(", ").presence
        when true then "Yes"
        when false then "No"
        else value.to_s.presence
        end
      end

      def audit_action(action, _diff) = action
      def audit_item_id = nil
      def audit_label = to_s
  end
end
