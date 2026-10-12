module WebsiteChecklist
  # An AI audit of a site's domain. Site::Probe finds out what it can from outside (DNS, the
  # registry, the pages, robots.txt, the sitemap), keeping files worth having (the sitemap); the
  # install's AI (the AI plugin's Ai.structured) turns that into a Recommendation per step it
  # says something about, which a person approves, changes or rejects. Run in ScanJob.
  class Scan < ApplicationRecord
    STATES = %w[queued running ready failed].freeze
    STUCK_AFTER = 10.minutes
    CONFIDENCES = %w[high medium low].freeze

    belongs_to :site
    belongs_to :user
    has_many :recommendations, -> { order(:position, :id) }, dependent: :delete_all, inverse_of: :scan
    has_many_attached :files

    serialize :facts, coder: JSON, type: Hash

    normalizes :domain, with: ->(domain) { Site::Probe.normalize(domain) }

    validates :domain, presence: true, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/, message: "isn't a domain like example.com" }
    validates :state, inclusion: { in: STATES }

    scope :latest_first, -> { order(id: :desc) }

    # Whether the install's AI can run one for this site (the AI plugin, on, set up, within budget).
    def self.ai_available_for?(site)
      defined?(::Ai) && ::Ai.respond_to?(:structured) && ::Ai.available_for?(site)
    end

    def working? = state.in?(%w[queued running]) && updated_at > STUCK_AFTER.ago
    def ready? = state == "ready"
    def failed? = state == "failed" || (state.in?(%w[queued running]) && !working?)
    def pending = recommendations.select { it.state == "pending" }

    def run_later = ScanJob.perform_later(self)

    # Called by ScanJob. Never raises: what went wrong is kept in `error`.
    def run!
      update!(state: "running", started_at: Time.current)
      probe = Site::Probe.new(domain)
      update!(facts: probe.facts)
      probe.files.each { |name, (body, type)| files.attach(io: StringIO.new(body), filename: name, content_type: type) }

      answer = ::Ai.structured(user: user, name: "website_audit", schema: schema, instructions: instructions, prompt: prompt)
      add_recommendations(Array(answer["recommendations"]))
      update!(state: "ready", finished_at: Time.current)
    rescue => error
      Rails.logger.error("[website_checklist] AI audit #{id}: #{error.class}: #{error.message}")
      update_columns(state: "failed", error: "#{error.class.name.demodulize}: #{error.message}".truncate(500), finished_at: Time.current, updated_at: Time.current)
    end

    private
      def steps = @steps ||= site.items.to_a

      def add_recommendations(answers)
        by_key = steps.index_by(&:key)
        sitemap = files.attachments.find { it.filename.to_s == "sitemap.xml" }
        answers.each_with_index do |answer, index|
          item = by_key[answer["item_key"]] or next
          value = answer["value"].to_s.strip.presence or next
          next if item.confirmed? && item.value.to_s == value

          recommendations.create!(item: item, value: value, note: answer["note"].to_s.strip.presence,
            evidence: answer["evidence"].to_s.strip.presence, confidence: answer["confidence"].presence_in(CONFIDENCES),
            attach_file: ("sitemap.xml" if sitemap && item.key == "search:sitemap_url"), position: by_key.keys.index(item.key) || index)
        end
      end

      def schema
        { type: "object", additionalProperties: false, required: %w[recommendations], properties: {
          recommendations: { type: "array", items: { type: "object", additionalProperties: false,
            required: %w[item_key value note evidence confidence],
            properties: {
              item_key: { type: "string", enum: steps.map(&:key) },
              value: { type: "string", description: "What to record on the step, as a person would write it: short and specific." },
              note: { type: "string", description: "What's still to do or check, or \"\"." },
              evidence: { type: "string", description: "The fact it comes from (\"RDAP registrar\", \"MX records\")." },
              confidence: { type: "string", enum: CONFIDENCES }
            } } }
        } }
      end

      def instructions
        <<~TEXT
          You help a team take a client's website live. They keep a checklist of steps to gather and record: access to the domain, DNS, email, Google tools, forms, the launch itself and what follows. You are given facts found about the domain from outside, without logging in anywhere: its DNS records, the registry's RDAP record, how its addresses answer, its home page, robots.txt and sitemap.

          For each step the facts say something about, recommend what to record on it.
          - Only what the facts show. Never invent an account, a person, a date or access. Where the facts show what something is but not who can get in (a registrar, a DNS host, a Search Console verification), say what they show in value, and put what's still to do in note ("Ask the client to add us as a delegate").
          - value is short and specific, in the step's own words: names, IDs, addresses, dates (as 3 Mar 2027).
          - evidence names the fact it comes from. confidence: high when a fact states it, medium when it's inferred, low when it's a guess worth checking.
          - At most one recommendation per step; skip steps the facts say nothing about, and steps whose current value already says the same.
          - Write plainly, for anyone running a business: no jargon you don't need.
          Today is #{Date.current.to_fs(:long)}.
        TEXT
      end

      def prompt
        lines = steps.map do |item|
          "- #{item.key} | #{item.title} | #{item.detail} | now: #{item.value.presence || "nothing"} (#{item.state_label.downcase})"
        end
        "Domain: #{domain}\n\nThe checklist's steps (key | title | what it records | what's recorded now):\n#{lines.join("\n")}\n\n" \
          "Facts found about the domain (JSON):\n#{JSON.pretty_generate(facts)}"
      end
  end
end
