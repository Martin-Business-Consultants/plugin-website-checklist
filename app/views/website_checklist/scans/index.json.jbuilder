json.summary @scan ? "#{@site.name}: audit of #{@scan.domain} #{@scan.working? ? "running" : @scan.failed? ? "failed" : "ready, #{@scan.pending.size} of #{@scan.recommendations.size} recommendations to review"}" : "#{@site.name} hasn't been audited yet"
json.ai_available @ai
if @scan
  json.scan do
    json.extract! @scan, :id, :domain, :state, :error, :started_at, :finished_at, :facts
    json.files @scan.files.map { it.filename.to_s }
    json.recommendations @scan.recommendations do |recommendation|
      json.extract! recommendation, :id, :state, :value, :note, :evidence, :confidence, :attach_file, :decided_by_name, :decided_at
      json.item do
        json.extract! recommendation.item, :id, :key, :title, :value, :state
      end
    end
  end
end
