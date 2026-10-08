summary = @site.summary
json.merge! agent_ref(@site)
json.url website_checklist_site_url(@site)
json.summary "#{@site.name}: #{summary}#{"; #{website_attention_text(@site, summary)}" if website_attention_text(@site, summary)}"
json.extract! @site, :name
json.address @site.url
json.client agent_ref(@site.client)
json.read_from_cms @site.cms_linked?
json.cms_url @site.cms_url
json.extract! @site, :synced_at, :sync_error
json.checklist summary.to_h
json.items @items do |item|
  json.extract! item, :id, :key, :group, :subject, :title, :detail, :kind, :value, :confirmed_value, :state, :problem, :note,
    :confirmed_by_name, :confirmed_at, :custom
  json.cms_says item.detected_value if item.detected? && @site.cms_linked?
  json.differs_from_cms item.differs_from_cms?
  json.cms_href item.href
end
