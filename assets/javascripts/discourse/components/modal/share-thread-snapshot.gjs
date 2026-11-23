import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

function formatLocalTime(iso) {
  if (!iso) {
    return "";
  }

  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return String(iso);
  }

  return date.toLocaleString();
}

export default class ShareThreadSnapshotModal extends Component {
  @tracked snapshot = this.args.model?.snapshot;
  @tracked others = [];
  @tracked copied = false;
  revokedIds = new Set();

  constructor(owner, args) {
    super(owner, args);
    this.loadOthers();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearTimeout(this.copyTimer);
  }

  get url() {
    return this.snapshot?.url || "";
  }

  get expiryLabel() {
    return i18n("thread_snapshots.expires", {
      date: formatLocalTime(this.snapshot?.expires_at),
    });
  }

  get copyLabelKey() {
    return this.copied ? "thread_snapshots.copied" : "thread_snapshots.copy";
  }

  get earlierSnapshots() {
    const currentId = this.snapshot?.id;

    return this.others
      .filter((row) => row.id !== currentId)
      .map((row) => ({
        ...row,
        expiryLabel: i18n("thread_snapshots.expires", {
          date: formatLocalTime(row.expires_at),
        }),
      }));
  }

  @action
  async loadOthers() {
    const topicId = this.args.model?.topicId;
    if (!topicId) {
      return;
    }

    try {
      const result = await ajax("/thread-snapshots", {
        data: { topic_id: topicId },
      });
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.others = (result?.thread_snapshots || []).filter(
        (row) => !this.revokedIds.has(row.id)
      );
    } catch {
      if (!this.isDestroying && !this.isDestroyed) {
        this.others = [];
      }
    }
  }

  @action
  selectInput(event) {
    event?.target?.select?.();
  }

  @action
  async copy() {
    const url = this.url;
    if (!url) {
      return;
    }

    let copied = false;

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
        copied = true;
      }
    } catch {
      copied = false;
    }

    if (!copied) {
      copied = this.copyFromInput();
    }

    this.copied = copied;
    clearTimeout(this.copyTimer);
    if (copied) {
      this.copyTimer = setTimeout(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          this.copied = false;
        }
      }, 2000);
    }
  }

  copyFromInput() {
    const input = document.querySelector(".thread-snapshot-share__url");
    if (!input) {
      return false;
    }

    input.focus();
    input.select();

    try {
      return document.execCommand("copy");
    } catch {
      return false;
    }
  }

  @action
  revokeCurrent() {
    return this.revoke(this.snapshot);
  }

  @action
  async revoke(row) {
    if (!row?.id) {
      return;
    }

    this.revokedIds.add(row.id);

    try {
      await ajax(`/thread-snapshots/${row.id}`, { type: "DELETE" });
    } catch (error) {
      this.revokedIds.delete(row.id);
      popupAjaxError(error);
      return;
    }

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.others = this.others.filter((item) => !this.revokedIds.has(item.id));
    if (row.id !== this.snapshot?.id) {
      return;
    }

    const next = this.others[0];
    if (next) {
      this.snapshot = next;
      this.copied = false;
      return;
    }

    this.args.closeModal?.();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "thread_snapshots.modal_title"}}
      class="thread-snapshot-share-modal"
    >
      <:body>
        <div class="thread-snapshot-share">
          <label class="thread-snapshot-share__label" for="thread-snapshot-url">
            {{i18n "thread_snapshots.link_label"}}
          </label>
          <input
            id="thread-snapshot-url"
            class="thread-snapshot-share__url"
            type="text"
            readonly={{true}}
            value={{this.url}}
            autocomplete="off"
            spellcheck="false"
            aria-label={{i18n "thread_snapshots.link_label"}}
            {{on "focus" this.selectInput}}
          />
          <p class="thread-snapshot-share__expiry">{{this.expiryLabel}}</p>

          {{#if this.earlierSnapshots.length}}
            <h2 class="thread-snapshot-share__earlier-title">
              {{i18n "thread_snapshots.earlier_links"}}
            </h2>
            <ul class="thread-snapshot-share__earlier">
              {{#each this.earlierSnapshots as |row|}}
                <li class="thread-snapshot-share__earlier-item">
                  <input
                    class="thread-snapshot-share__earlier-url"
                    type="text"
                    readonly={{true}}
                    value={{row.url}}
                    autocomplete="off"
                    spellcheck="false"
                    aria-label={{i18n "thread_snapshots.link_label"}}
                    {{on "focus" this.selectInput}}
                  />
                  <p>{{row.expiryLabel}}</p>
                  <DButton
                    class="btn-danger btn-small thread-snapshot-share__revoke-earlier"
                    @action={{fn this.revoke row}}
                    @label="thread_snapshots.revoke"
                  />
                </li>
              {{/each}}
            </ul>
          {{/if}}
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary thread-snapshot-share__copy"
          @action={{this.copy}}
          @label={{this.copyLabelKey}}
        />
        <DButton
          class="btn-danger thread-snapshot-share__revoke"
          @action={{this.revokeCurrent}}
          @label="thread_snapshots.revoke"
        />
        <DButton
          class="thread-snapshot-share__close"
          @action={{@closeModal}}
          @label="thread_snapshots.close"
        />
      </:footer>
    </DModal>
  </template>
}
