# frozen_string_literal: true

RSpec.describe DiscourseThreadSnapshots::ThreadSnapshotsController do
  fab!(:staff) { Fabricate(:moderator, name: "Snapshot Author") }
  fab!(:member) { Fabricate(:user) }
  fab!(:topic) do
    Fabricate(
      :private_message_topic,
      user: staff,
      recipient: member,
      title: "Original snapshot title",
    )
  end
  fab!(:original_post) { Fabricate(:post, topic: topic, user: staff, raw: "placeholder") }

  let(:cooked_html) { %(<p>FROZEN_SENTINEL_TEXT</p><p><a href="/t/secret/1">member link</a></p>) }

  before do
    SiteSetting.login_required = true
    SiteSetting.thread_snapshots_enabled = true
    original_post.update_column(:cooked, cooked_html)
  end

  def create_snapshot
    DiscourseThreadSnapshots::ThreadSnapshot.capture!(topic: topic, user: staff)
  end

  describe "the public page" do
    it "lets an anonymous visitor read a snapshot while login is required" do
      snapshot = create_snapshot

      get "/latest"
      expect(response.status).to eq(302)
      expect(response.location).to match(%r{/login(?:\?|\z)})

      get "/thread-snapshots/#{snapshot.token}"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Original snapshot title")
      expect(response.body).to include("FROZEN_SENTINEL_TEXT")
      expect(response.body).to include('href="/t/secret/1"')
      expect(response.body).to include("Snapshot Author")
      expect(response.body).to include(staff.username)
      expect(response.body).to include("<time")
      expect(response.body).to include("<img")
      expect(response.body).not_to include("main-outlet")
      expect(response.body).not_to include("data-preloaded")
    end

    it "keeps the copied posts and title after a reply and an edit" do
      snapshot = create_snapshot

      original_post.update!(raw: "EDITED_SENTINEL_TEXT")
      Fabricate(:post, topic: topic, user: member, raw: "LATER_REPLY_SENTINEL")
      topic.update!(title: "Renamed after the snapshot")

      get "/thread-snapshots/#{snapshot.token}"

      expect(response.status).to eq(200)
      expect(response.body).to include("FROZEN_SENTINEL_TEXT")
      expect(response.body).to include("Original snapshot title")
      expect(response.body).to include('href="/t/secret/1"')
      expect(response.body).not_to include("EDITED_SENTINEL_TEXT")
      expect(response.body).not_to include("LATER_REPLY_SENTINEL")
      expect(response.body).not_to include("Renamed after the snapshot")
      expect(snapshot.reload.frozen_posts.length).to eq(1)
    end

    it "returns 404 for an expired token" do
      snapshot = create_snapshot
      snapshot.update!(expires_at: 1.hour.ago)

      get "/thread-snapshots/#{snapshot.token}"

      expect(response.status).to eq(404)
    end

    it "returns 404 for an unknown token" do
      get "/thread-snapshots/#{SecureRandom.hex(32)}"

      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    it "lets staff create a snapshot of a personal message they can see" do
      sign_in(staff)

      post "/thread-snapshots.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["token"]).to match(/\A[a-f0-9]{64}\z/)
      expect(body["url"]).to end_with("/thread-snapshots/#{body["token"]}")
      expect(body["title"]).to eq("Original snapshot title")

      stored = DiscourseThreadSnapshots::ThreadSnapshot.find(body["id"])
      expect(stored.frozen_posts.first["cooked"]).to eq(cooked_html)
      expect(stored.frozen_posts.first["username"]).to eq(staff.username)
      expect(stored.frozen_posts.first["name"]).to eq("Snapshot Author")
      expect(stored.frozen_posts.first["avatar_url"]).to be_present
      expect(stored.frozen_posts.first["created_at"]).to be_present
    end

    it "does not let a non-staff participant create a snapshot" do
      sign_in(member)

      post "/thread-snapshots.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(DiscourseThreadSnapshots::ThreadSnapshot.count).to eq(0)
    end

    it "does not let staff snapshot a personal message they cannot see" do
      sign_in(Fabricate(:moderator))

      post "/thread-snapshots.json", params: { topic_id: topic.id }

      expect(response.status).to eq(404)
      expect(DiscourseThreadSnapshots::ThreadSnapshot.count).to eq(0)
    end

    it "does not snapshot a regular topic" do
      sign_in(staff)
      public_topic = Fabricate(:topic, user: staff, title: "A public topic")
      Fabricate(:post, topic: public_topic, user: staff)

      post "/thread-snapshots.json", params: { topic_id: public_topic.id }

      expect(response.status).to eq(403)
      expect(DiscourseThreadSnapshots::ThreadSnapshot.count).to eq(0)
    end
  end

  describe "#destroy" do
    it "lets staff revoke a snapshot" do
      snapshot = create_snapshot
      sign_in(staff)

      delete "/thread-snapshots/#{snapshot.id}.json"

      expect(response.status).to eq(200)

      get "/thread-snapshots/#{snapshot.token}"
      expect(response.status).to eq(404)
    end

    it "does not let a non-staff user revoke a snapshot" do
      snapshot = create_snapshot
      sign_in(member)

      delete "/thread-snapshots/#{snapshot.id}.json"

      expect(response.status).to eq(403)
      expect(DiscourseThreadSnapshots::ThreadSnapshot.exists?(snapshot.id)).to eq(true)
    end
  end

  describe "#index" do
    it "lists snapshots for staff" do
      snapshot = create_snapshot
      sign_in(staff)

      get "/thread-snapshots.json"

      expect(response.status).to eq(200)
      ids = response.parsed_body["thread_snapshots"].map { |row| row["id"] }
      expect(ids).to include(snapshot.id)
    end
  end
end
