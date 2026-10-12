summary = @site.summary
next_item = @site.next_item
json.merge! agent_ref(@site)
json.url website_checklist_site_url(@site)
json.summary "#{@site.name}: #{summary}#{"; next: #{next_item.title}" if next_item}"
json.extract! @site, :name
json.address @site.url
json.client agent_ref(@site.client)
json.checklist summary.to_h
json.next_step next_item && { id: next_item.id, title: next_item.title }
json.items website_item_groups(@items).flat_map(&:last).each_with_index.to_a do |(item, index)|
  json.step index + 1
  json.extract! item, :id, :key, :group, :title, :detail, :how, :example, :value, :confirmed_value, :state, :note,
    :confirmed_by_name, :confirmed_at, :custom
  if item.webhooks?
    json.webhooks item.webhooks do |webhook|
      json.extract! webhook, :id, :name, :url, :pairs
    end
  end
end
