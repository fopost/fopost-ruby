# frozen_string_literal: true

module Fopost
  module Resources
    # `client.queue` — the posting queue: weekly slots a post lands in when it
    # is created with `schedule: 'queue'`. Every call needs the `posts` scope.
    class Queue < Base
      def slots(workspace_id:)
        parse_list(QueueSlot, unwrap(http.get('/queue/slots', { 'workspace_id' => workspace_id })))
      end

      # `weekday` is 0 (Sunday) to 6, `time` is "HH:MM" in `timezone`. Leave
      # `account_id` out for a slot shared by every account.
      def create_slot(workspace_id:, weekday:, time:, timezone:, account_id: nil)
        body = {
          'workspace_id' => workspace_id,
          'weekday' => weekday,
          'time' => time,
          'timezone' => timezone
        }
        body['account_id'] = account_id unless account_id.nil?
        QueueSlot.new(unwrap(http.post('/queue/slots', body)))
      end

      # Partial update; posts already in the slot move with it and come back
      # in `moved`. Pass an explicit nil `account_id` to make the slot shared.
      def update_slot(slot_id, account_id: UNSET, weekday: UNSET, time: UNSET, timezone: UNSET)
        body = compact_unset(
          'account_id' => account_id,
          'weekday' => weekday,
          'time' => time,
          'timezone' => timezone
        )
        QueueSlotUpdated.new(unwrap(http.put("/queue/slots/#{slot_id}", body)))
      end

      # Posts in the slot move to the next free one and come back in `moved`.
      def delete_slot(slot_id)
        QueueSlotDeleted.new(unwrap(http.delete("/queue/slots/#{slot_id}")))
      end

      # The next free slot time, or nil when the workspace has no slots.
      def next(workspace_id:, account_id: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id)
        body = as_hash(unwrap(http.get('/queue/next', query)))
        body['next'].nil? ? nil : Model.parse_time(body['next'])
      end

      # The upcoming slot times, as `Time`s.
      def preview(workspace_id:, account_id: nil, count: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id, 'count' => count)
        data = unwrap(http.get('/queue/preview', query))
        data.is_a?(Array) ? data.filter_map { |at| Model.parse_time(at) } : []
      end
    end
  end
end
