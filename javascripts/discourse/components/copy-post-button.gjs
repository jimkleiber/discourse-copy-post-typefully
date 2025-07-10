import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from '@ember/service'; // Still inject, but will use global as fallback
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

// Access the global Discourse object directly
const DiscourseNotification = window.Discourse && window.Discourse.Notification;

export default class SendToTypefullyButton extends Component {
  @service siteSettings;
  // @service notifications; // No longer directly using this injected service for notifications

  static hidden() {
    return false;
  }

  @tracked icon = "paper-plane";

  // Helper function to display notifications
  // This function will attempt to use the global Discourse.Notification
  // If that's not available, it will fall back to console.error/log
  _displayNotification(type, message) {
    if (DiscourseNotification && typeof DiscourseNotification[type] === 'function') {
      DiscourseNotification[type](message);
    } else {
      // Fallback if Discourse.Notification is not fully available
      console[type === 'error' ? 'error' : 'log'](`Notification (${type}): ${message}`);
      // As a last resort for visibility, if notifications are completely broken
      // alert(`Notification (${type}): ${message}`); // Re-enable for debugging if needed
    }
  }

  @action
  async sendToTypefully() {
    this.icon = "spinner";

    const postContents = await this.fetchRawPost(this.args.post.id);

    if (!postContents) {
      this._displayNotification("error", "Could not retrieve post content.");
      this.resetIcon();
      return;
    }

    const typefullyApiKey = this.siteSettings.typefully_api_key;

    if (!typefullyApiKey || typefullyApiKey === 'YOUR_TYPEFULLY_API_KEY_PLACEHOLDER') {
      this._displayNotification("error", "Typefully API key is not configured. Please set it in Discourse site settings.");
      this.resetIcon();
      return;
    }

    try {
      const payload = {
        content: postContents,
        threadify: true,
      };

      const response = await fetch('https://api.typefully.com/v1/drafts/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': typefullyApiKey,
        },
        body: JSON.stringify(payload),
      });

      if (response.ok) {
        const data = await response.json();
        this._displayNotification("success", `Draft sent to Typefully! Draft ID: ${data.id}`);
        this.icon = "check";
        console.log("Typefully API Response:", data);
      } else {
        const errorData = await response.json();
        const errorMessage = errorData.message || response.statusText;
        this._displayNotification("error", `Failed to send draft: ${errorMessage}`);
        this.icon = "exclamation-triangle";
        console.error("Typefully API Error:", errorData);
      }
    } catch (error) {
      this._displayNotification("error", `An error occurred: ${error.message}. Check console for details.`);
      this.icon = "exclamation-triangle";
      console.error("Network or API call error:", error);
      popupAjaxError(error); // Still use this for more detailed AJAX error popups
    } finally {
      discourseLater(() => {
        this.icon = "paper-plane";
      }, 2000);
    }
  }

  async fetchRawPost(postId) {
    try {
      const { raw } = await ajax(`/posts/${postId}.json`);
      return raw;
    } catch (error) {
      popupAjaxError(error);
      return null;
    }
  }

  resetIcon() {
    discourseLater(() => {
      this.icon = "paper-plane";
    }, 2000);
  }

  <template>
    <DButton
      class="post-action-menu__send-to-typefully btn-flat"
      @title={{themePrefix "send_to_typefully_title"}}
      @icon={{this.icon}}
      @action={{this.sendToTypefully}}
      ...attributes
    />
  </template>
}
