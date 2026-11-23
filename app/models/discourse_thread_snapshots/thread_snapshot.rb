# frozen_string_literal: true

module DiscourseThreadSnapshots
  class ThreadSnapshot < ActiveRecord::Base
    self.table_name = "thread_snapshots"

    # New tokens are 16 bytes, hex-encoded (32 characters). The public route
    # also accepts tokens created earlier, which are 64 characters.
    TOKEN_BYTES = 16

    belongs_to :topic
    belongs_to :user

    validates :token, :title, :expires_at, presence: true
    validates :token, uniqueness: true

    before_validation :assign_token, on: :create

    scope :expired, -> { where("expires_at <= ?", Time.zone.now) }
    scope :active, -> { where("expires_at > ?", Time.zone.now) }

    def self.capture!(topic:, user:)
      create!(
        topic: topic,
        user: user,
        title: topic.title.to_s,
        posts_data: posts_data_for(topic),
        expires_at: expiry_from_now,
      )
    end

    def self.posts_data_for(topic)
      topic
        .posts
        .where(post_type: Post.types[:regular])
        .order(:post_number)
        .includes(:user)
        .map { |post| serialize_post(post) }
    end

    def self.serialize_post(post)
      author = post.user
      {
        "post_number" => post.post_number,
        "cooked" => post.cooked.to_s,
        "username" => post.username.to_s,
        "name" => author&.name.to_s,
        "avatar_url" => avatar_url_for(author),
        "created_at" => post.created_at&.iso8601,
      }
    end

    def self.avatar_url_for(user)
      return if user.nil?

      template = user.avatar_template
      return if template.blank?

      absolute_url(template.to_s.gsub("{size}", "48"))
    end

    def self.absolute_url(url)
      return if url.blank?
      return url if url.match?(%r{\Ahttps?:}i)

      if url.start_with?("//")
        scheme = Discourse.base_url[/\Ahttps?/] || "https"
        return "#{scheme}:#{url}"
      end

      return "#{Discourse.base_url}#{url}" if url.start_with?("/")

      url
    end

    def self.generate_token
      SecureRandom.hex(TOKEN_BYTES)
    end

    def self.expiry_from_now
      days = SiteSetting.thread_snapshots_expiry_days.to_i
      days = 7 if days < 1
      days.days.from_now
    end

    def self.format_timestamp(value)
      return "" if value.blank?

      Time.zone.parse(value.to_s)&.strftime("%Y-%m-%d %H:%M %Z").to_s
    rescue ArgumentError, TypeError
      value.to_s
    end

    def expired?
      expires_at <= Time.zone.now
    end

    def public_path
      "/thread-snapshots/#{token}"
    end

    def public_url
      "#{Discourse.base_url}#{public_path}"
    end

    def frozen_posts
      Array(posts_data).filter_map { |entry| entry.stringify_keys if entry.is_a?(Hash) }
    end

    def as_staff_json
      {
        id: id,
        token: token,
        url: public_url,
        path: public_path,
        title: title,
        topic_id: topic_id,
        expires_at: expires_at&.iso8601,
        created_at: created_at&.iso8601,
      }
    end

    private

    def assign_token
      self.token = self.class.generate_token if token.blank?
    end
  end
end
