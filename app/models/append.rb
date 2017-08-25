class Append < ApplicationRecord

  belongs_to :topic

  after_commit :async_create_append_notify, on: :create
  def async_create_append_notify
    NotifyAppendJob.perform_later(id)
  end

  def self.notify_append_created(append_id)
    Rails.logger.error("append #{append_id}")
    append = Append.find_by_id(append_id)
    topic = append.topic
    return unless topic && topic.user

    reply_user_ids = topic.replies.pluck(:user_id)
    follower_ids = topic.user.follow_by_user_ids | reply_user_ids
    return if follower_ids.empty?

    notified_user_ids = topic.mentioned_user_ids
    Rails.logger.error("append111 #{append_id}")
    # 给关注者发通知
    default_note = { notify_type: "append", target_type: "Topic", target_id: topic.id, actor_id: topic.user_id }
    Notification.bulk_insert(set_size: 100) do |worker|
      follower_ids.each do |uid|
        # 排除同一个回复过程中已经提醒过的人
        next if notified_user_ids.include?(uid)
        # 排除回帖人
        next if uid == topic.user_id
        note = default_note.merge(user_id: uid)
        worker.add(note)
      end
    end
    true
  end
end