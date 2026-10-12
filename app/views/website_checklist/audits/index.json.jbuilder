json.summary "#{@audits.size} #{"change".pluralize(@audits.size)}#{" to #{@item&.title || @site.name}" if @site}, newest first"
json.audits @audits do |audit|
  json.extract! audit, :id, :created_at, :action, :source, :site_id, :site_name, :item_id, :record_type, :record_id
  json.who audit.actor_label
  json.subject audit.subject_label
  json.changes(audit.diff.map { |field, (before, after)| { field: WebsiteChecklist::Audit.field_label(field), before: before, after: after } })
end
json.older_before @older
