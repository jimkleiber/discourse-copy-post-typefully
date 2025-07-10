import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from '@ember/service'; // Still inject siteSettings for other potential uses, but not for theme settings
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

// Access the global Discourse object directly for notifications
const DiscourseNotification = window.Discourse && window.Discourse.Notification;

export default class SendToTypefullyButton extends Component {
  // We keep siteSettings injected in case other core settings are needed,
  // but for theme component settings, we'll use the global 'settings' object.
  @service siteSettings;

  static hidden() {
    return false;
  }

  @tracked icon = "paper-plane";

  // Helper function to display notifications
  _displayNotification(type, message) {
    if (DiscourseNotification && typeof DiscourseNotification[type] === 'function') {
      DiscourseNotification[type](message);
    } else {
      console[type === 'error' ? 'error' : 'log'](`Notification (${type}): ${message}`);
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

    // --- CRITICAL CHANGE HERE ---
    // Access theme component settings via the global 'settings' object
    // Ensure 'settings' is available in your theme component's context.
    // It should be if your theme component is set up correctly.
    const typefullyApiKey = settings.typefully_api_key;

    // --- DEBUGGING FOR SETTINGS ---
    console.log('DEBUG: Global settings object:', settings);
    console.log('DEBUG: typefully_api_key from settings:', typefullyApiKey);
    // --- END DEBUGGING ---

    if (!typefullyApiKey || typefullyApiKey === 'YOUR_TYPEFULLY_API_KEY_PLACEHOLDER') {
      this._displayNotification("error", "Typefully API key is not configured in your theme component settings. Please set it.");
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
      popupAjaxError(error);
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
