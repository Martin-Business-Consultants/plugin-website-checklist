module WebsiteChecklist
  # Runs an AI audit off the request (Scan#run!): reading the domain and asking the AI take a minute.
  class ScanJob < ApplicationJob
    def perform(scan) = scan.run!
  end
end
