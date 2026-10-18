# frozen_string_literal: true

module Fopost
  module Resources
    # `client.automations` — trigger-driven workflows, their saved versions
    # and their runs. Every call needs the `automations` scope.
    class Automations < Base
      def list
        parse_list(Automation, unwrap(http.get('/automations')))
      end

      # `steps` is a flat list of `{ action_type:, action_config: }`; `graph`
      # is `{ nodes:, edges: }` for a branching workflow. Keys may be snake_case
      # or camelCase. The answer carries `secret` for an `api_webhook` trigger.
      def create(workspace_id:, name:, trigger_type:, description: nil, trigger_config: nil, steps: nil,
                 graph: nil, active: nil)
        body = { 'workspaceId' => workspace_id, 'name' => name, 'triggerType' => trigger_type }
        body.merge!(
          compact_nil(
            'description' => description,
            'triggerConfig' => trigger_config,
            'steps' => steps && camelize(steps),
            'graph' => graph && camelize(graph),
            'active' => active
          )
        )
        Automation.new(unwrap(http.post('/automations', body)))
      end

      # Counts across the workspace's automations and the latest runs.
      def stats
        AutomationStats.new(unwrap(http.get('/automations/stats')))
      end

      def get(automation_id)
        Automation.new(unwrap(http.get("/automations/#{automation_id}")))
      end

      # Partial update; only the fields you pass are sent. Pass an explicit
      # nil `description` to clear it.
      def update(automation_id, name: UNSET, description: UNSET, trigger_type: UNSET, trigger_config: UNSET,
                 steps: UNSET, graph: UNSET, active: UNSET)
        body = compact_unset(
          'name' => name,
          'description' => description,
          'triggerType' => trigger_type,
          'triggerConfig' => trigger_config,
          'steps' => UNSET.equal?(steps) ? UNSET : steps && camelize(steps),
          'graph' => UNSET.equal?(graph) ? UNSET : graph && camelize(graph),
          'active' => active
        )
        Automation.new(unwrap(http.put("/automations/#{automation_id}", body)))
      end

      def delete(automation_id)
        http.delete("/automations/#{automation_id}")
        nil
      end

      # Saved versions of the graph, newest first, with what each one changed.
      def versions(automation_id, page: nil, per_page: nil)
        query = compact_nil('page' => page, 'per_page' => per_page)
        offset_page(AutomationVersion, http.get("/automations/#{automation_id}/versions", query))
      end

      # One version with its graph.
      def get_version(automation_id, version)
        AutomationVersion.new(unwrap(http.get("/automations/#{automation_id}/versions/#{version}")))
      end

      # Write the version's graph back as a new version.
      def restore_version(automation_id, version)
        body = unwrap(http.post("/automations/#{automation_id}/versions/#{version}/restore"))
        AutomationRestoredVersion.new(body)
      end

      def runs(automation_id, page: nil, per_page: nil)
        query = compact_nil('page' => page, 'per_page' => per_page)
        offset_page(AutomationRun, http.get("/automations/#{automation_id}/runs", query))
      end

      # One run with its step logs.
      def get_run(automation_id, run_id)
        AutomationRun.new(unwrap(http.get("/automations/#{automation_id}/runs/#{run_id}")))
      end

      private

      def offset_page(model, body)
        body = as_hash(body)
        meta = body['meta'].is_a?(Hash) ? body['meta'] : {}
        Page.new(items: parse_list(model, body['data']), meta: OffsetPageMeta.new(meta))
      end

      # The automation bodies are camelCase on the wire; callers write snake_case.
      def camelize(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, item), out| out[camel_key(key)] = camelize(item) }
        when Array then value.map { |item| camelize(item) }
        else value
        end
      end

      def camel_key(key)
        key.to_s.gsub(/_([a-z\d])/) { Regexp.last_match(1).upcase }
      end
    end
  end
end
