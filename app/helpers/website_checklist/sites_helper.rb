module WebsiteChecklist
  module SitesHelper
    ITEM_TONES = { "unconfirmed" => "waiting", "confirmed" => "positive", "changed" => "negative", "not_applicable" => "neutral" }.freeze

    # An item's state, tinted like the core's status tags.
    def website_item_state_tag(item)
      tag.span item.state_label, class: "status-tag status-tag--#{ITEM_TONES.fetch(item.state)} txt-nowrap"
    end

    # A site's checklist in a few words: confirmed of total, and what needs a look.
    def website_summary_tag(site, summary = site.summary)
      tone = if site.sync_error.present? || summary.changed.positive? || summary.problems.positive? then "negative"
      elsif summary.ready? then "positive"
      else "waiting"
      end
      tag.span summary.to_s, class: "status-tag status-tag--#{tone} txt-nowrap"
    end

    # "2 changed · 1 problem · 4 to confirm", or nil when nothing needs a look.
    def website_attention_text(site, summary = site.summary)
      parts = []
      parts << "#{summary.changed} changed" if summary.changed.positive?
      parts << pluralize(summary.problems, "problem") if summary.problems.positive?
      parts << "#{summary.unconfirmed} to confirm" if summary.unconfirmed.positive?
      parts << "CMS not read" if site.sync_error.present?
      parts.join(" · ").presence
    end

    # [[group, items], …] in the checklist's order (Item::GROUPS, then any other group).
    def website_item_groups(items)
      grouped = items.group_by(&:group)
      (Item::GROUPS & grouped.keys).map { [ it, grouped[it] ] } + (grouped.keys - Item::GROUPS).map { [ it, grouped[it] ] }
    end

    def website_client_options = Client.ordered.pluck(:name, :id)
  end
end
