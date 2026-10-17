# frozen_string_literal: true

module Fopost
  module Resources
    # `client.broadcasts` — one message into every conversation the workspace
    # already has with a segment of its contacts.
    #
    # Nothing is sent into a closed messaging window. Messenger and Instagram
    # take a business-initiated message only within 24 hours of the contact's
    # last one, so recipients outside it come back skipped with
    # `window_closed` rather than attempted — which is why the number sent is
    # often lower than the audience. Telegram, Slack, Bluesky and Reddit have
    # no window.
    #
    # Reading needs the `inbox` scope; {#send} and {#cancel} also need
    # `publish`.
    class Broadcasts < Base
      # One page of broadcasts, newest first. The result is Enumerable over
      # its items.
      #
      # Omit `workspace_id` to span every workspace the key can reach; each
      # broadcast then carries `workspace_id`.
      def list(workspace_id: nil, status: nil, page: 1, per_page: 25)
        body = http.get(
          '/broadcasts',
          { 'workspace_id' => workspace_id, 'status' => status, 'page' => page, 'per_page' => per_page }
        )
        paged(Broadcast, body)
      end

      def get(broadcast_id)
        Broadcast.new(unwrap(http.get("/broadcasts/#{broadcast_id}")))
      end

      # Create it without sending.
      #
      # Give `scheduled_at` to have it go out on its own at that time;
      # otherwise call {#send}. An omitted `audience` means every contact in
      # the workspace.
      def create(workspace_id:, account_id:, name:, text:, media_id: nil, audience: nil, scheduled_at: nil)
        body = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'name' => name,
          'text' => text,
          'media_id' => media_id,
          'audience' => audience,
          'scheduled_at' => scheduled_at
        )
        Broadcast.new(unwrap(http.post('/broadcasts', body)))
      end

      # Partial update: only what you pass is sent. Only a draft or scheduled
      # broadcast can be edited.
      def update(broadcast_id, name: UNSET, text: UNSET, media_id: UNSET, audience: UNSET, scheduled_at: UNSET)
        body = compact_unset(
          'name' => name,
          'text' => text,
          'media_id' => media_id,
          'audience' => audience,
          'scheduled_at' => scheduled_at
        )
        Broadcast.new(unwrap(http.request(:patch, "/broadcasts/#{broadcast_id}", json: body)))
      end

      # Freeze the audience into a recipient list and start sending.
      #
      # The returned `recipients` count is how many contacts matched, not how
      # many will be messaged — the messaging window decides that. Needs the
      # `publish` scope as well as `inbox`.
      def send(broadcast_id)
        as_hash(unwrap(http.post("/broadcasts/#{broadcast_id}/send", {})))
      end

      # Stop it where it stands. Anyone not yet written to stays unsent;
      # messages already delivered are not recalled. Needs `publish`.
      def cancel(broadcast_id)
        as_hash(unwrap(http.post("/broadcasts/#{broadcast_id}/cancel", {})))
      end

      # One row per contact, with what became of their message. A skipped row
      # carries `skip_reason`.
      def recipients(broadcast_id, status: nil, page: 1, per_page: 50)
        body = http.get(
          "/broadcasts/#{broadcast_id}/recipients",
          { 'status' => status, 'page' => page, 'per_page' => per_page }
        )
        paged(BroadcastRecipient, body)
      end

      # Removes the broadcast and its recipient records. Messages already sent
      # stay in the conversations they went to.
      def delete(broadcast_id)
        http.delete("/broadcasts/#{broadcast_id}")
        nil
      end

      private

      # Broadcast lists answer `{data, pagination}`, not `{data, meta}`.
      def paged(model, body)
        hash = as_hash(body)
        raw_meta = hash['pagination']
        Page.new(
          items: parse_list(model, hash['data']),
          meta: ContactPageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {})
        )
      end
    end

    # `client.sequences` — a series of messages, each a delay after the one
    # before, walked per enrolled contact.
    #
    # The messaging window applies to every step. A step that comes due
    # outside it is skipped rather than sent, and the enrollment carries on —
    # so someone can complete a sequence having received only some of its
    # messages.
    class Sequences < Base
      def list(workspace_id: nil, page: 1, per_page: 25)
        body = http.get('/sequences', { 'workspace_id' => workspace_id, 'page' => page, 'per_page' => per_page })
        paged(Sequence, body)
      end

      def get(sequence_id)
        Sequence.new(unwrap(http.get("/sequences/#{sequence_id}")))
      end

      # Creating a sequence enrolls nobody.
      #
      # Each step is `{ 'delay_hours' => n, 'text' => '...' }`, with
      # `delay_hours` counted from the previous step.
      def create(workspace_id:, account_id:, name:, steps:, status: nil)
        body = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'name' => name,
          'steps' => steps,
          'status' => status
        )
        Sequence.new(unwrap(http.post('/sequences', body)))
      end

      # Partial update. Pausing stops every enrollment from firing without
      # ending any of them; resuming picks them up where they stood.
      def update(sequence_id, name: UNSET, steps: UNSET, status: UNSET)
        body = compact_unset('name' => name, 'steps' => steps, 'status' => status)
        Sequence.new(unwrap(http.request(:patch, "/sequences/#{sequence_id}", json: body)))
      end

      # Put contacts on the sequence, by id or by the same audience filter a
      # broadcast takes.
      #
      # Re-enrolling someone restarts their walk from the first step rather
      # than running two in parallel. Needs `publish` as well as `inbox`.
      def enroll(sequence_id, contact_ids: nil, audience: nil)
        body = compact_nil('contact_ids' => contact_ids, 'audience' => audience)
        as_hash(unwrap(http.post("/sequences/#{sequence_id}/enroll", body)))
      end

      # Nothing further fires for them. Needs `publish`.
      def unenroll(sequence_id, contact_ids)
        as_hash(unwrap(http.post("/sequences/#{sequence_id}/unenroll", { 'contact_ids' => contact_ids })))
      end

      # Who is on it, what step they are at, and when the next one is due.
      def enrollments(sequence_id, page: 1, per_page: 50)
        body = http.get("/sequences/#{sequence_id}/enrollments", { 'page' => page, 'per_page' => per_page })
        paged(Enrollment, body)
      end

      # Removes the sequence and every enrollment on it.
      def delete(sequence_id)
        http.delete("/sequences/#{sequence_id}")
        nil
      end

      private

      def paged(model, body)
        hash = as_hash(body)
        raw_meta = hash['pagination']
        Page.new(
          items: parse_list(model, hash['data']),
          meta: ContactPageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {})
        )
      end
    end
  end
end
