# frozen_string_literal: true

module Fopost
  module Resources
    # `client.webhooks` — the outbound webhooks of a workspace and their
    # delivery log. Every call needs the `webhooks` scope. Verifying an
    # inbound delivery is `Fopost::Webhooks.verify`.
    class WebhookEndpoints < Base
      def list
        parse_list(Webhook, unwrap(http.get('/webhooks')))
      end

      # `secret` signs every delivery; FoPost makes one when none is given and
      # answers it once, on this call. `headers` are sent with every delivery.
      def create(workspace_id:, url:, events:, name: nil, secret: nil, headers: nil)
        body = { 'workspaceId' => workspace_id, 'url' => url, 'events' => events.to_a }
        body.merge!(compact_nil('name' => name, 'secret' => secret, 'headers' => headers))
        Webhook.new(unwrap(http.post('/webhooks', body)))
      end

      # Partial update. Pass an explicit nil `headers` to clear them, `name` to clear it.
      def update(webhook_id, name: UNSET, url: UNSET, events: UNSET, active: UNSET, secret: UNSET, headers: UNSET)
        body = compact_unset(
          'name' => name,
          'url' => url,
          'events' => UNSET.equal?(events) ? UNSET : events&.to_a,
          'active' => active,
          'secret' => secret,
          'headers' => headers
        )
        Webhook.new(unwrap(http.put("/webhooks/#{webhook_id}", body)))
      end

      def delete(webhook_id)
        http.delete("/webhooks/#{webhook_id}")
        nil
      end

      # Send a test event to the endpoint.
      def test(webhook_id)
        http.post("/webhooks/#{webhook_id}/test")
        nil
      end

      # Newest first. `status` is 'success' or 'failed'.
      def deliveries(webhook_id, status: nil, limit: nil)
        query = compact_nil('status' => status, 'limit' => limit)
        parse_list(WebhookDelivery, unwrap(http.get("/webhooks/#{webhook_id}/deliveries", query)))
      end

      # One delivery with the payload that was sent.
      def get_delivery(webhook_id, delivery_id)
        WebhookDelivery.new(unwrap(http.get("/webhooks/#{webhook_id}/deliveries/#{delivery_id}")))
      end

      # Send the delivery's payload again.
      def redeliver(webhook_id, delivery_id)
        http.post("/webhooks/#{webhook_id}/deliveries/#{delivery_id}/redeliver")
        nil
      end
    end
  end
end
