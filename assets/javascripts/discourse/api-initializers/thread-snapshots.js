import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const dialog = api.container.lookup("service:dialog");
  const siteSettings = api.container.lookup("service:site-settings");

  api.addTopicAdminMenuButton((topic) => {
    const currentUser = api.getCurrentUser();
    const personalMessage =
      topic?.isPrivateMessage || topic?.archetype === "private_message";

    if (siteSettings.thread_snapshots_enabled === false) {
      return;
    }

    if (!currentUser?.staff || !personalMessage) {
      return;
    }

    return {
      icon: "link",
      label: "thread_snapshots.share_snapshot",
      className: "thread-snapshots-share",
      action() {
        return ajax("/thread-snapshots", {
          type: "POST",
          data: { topic_id: topic.id },
        })
          .then((result) => {
            dialog.dialog({
              title: i18n("thread_snapshots.created_title"),
              message: i18n("thread_snapshots.created_body", {
                url: result.url,
                date: result.expires_at,
              }),
              buttons: [
                {
                  label: i18n("thread_snapshots.revoke"),
                  class: "btn-danger",
                  action() {
                    return ajax(`/thread-snapshots/${result.id}`, {
                      type: "DELETE",
                    })
                      .then(() => {
                        dialog.alert({
                          message: i18n("thread_snapshots.revoked"),
                        });
                      })
                      .catch(popupAjaxError);
                  },
                },
              ],
            });
          })
          .catch(popupAjaxError);
      },
    };
  });
});
