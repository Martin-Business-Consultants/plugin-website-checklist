json.summary "#{@sites.size} #{"website".pluralize(@sites.size)}#{" needing attention" if @show == "attention"}"
json.websites @sites do |site|
  summary = site.summary
  json.merge! agent_ref(site)
  json.url website_checklist_site_url(site)
  json.extract! site, :name
  json.address site.url
  json.client agent_ref(site.client)
  json.checklist summary.to_h
  json.needs_attention website_attention_text(site, summary)
  json.next_step site.next_item&.title
end
