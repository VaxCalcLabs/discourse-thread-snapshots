import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import ShareThreadSnapshotModal from "../components/modal/share-thread-snapshot";

export default apiInitializer((api) => {
  const dialog = api.container.lookup("service:dialog");
  const modal = api.container.lookup("service:modal");
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
            showSnapshot(modal, dialog, result, topic.id);
          })
          .catch(popupAjaxError);
      },
    };
  });
});

// dialog.dialog() sets show without a type, so Discourse draws the backdrop
// and then skips the dialog body. The modal service renders a real component.
// dialog.alert() is only a fallback: it sets type "alert", so the URL shows.
function showSnapshot(modal, dialog, result, topicId) {
  if (typeof modal?.show === "function") {
    try {
      modal.show(ShareThreadSnapshotModal, {
        model: {
          snapshot: result,
          topicId,
        },
      });
      return;
    } catch {
      // The modal service rejected the component. Fall through.
    }
  }

  dialog.alert(
    i18n("thread_snapshots.created_body", {
      url: result.url,
      date: result.expires_at,
    })
  );
}
