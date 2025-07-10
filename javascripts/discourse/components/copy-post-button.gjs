import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from '@ember/service';
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

export default class SendToTypefullyButton extends Component {
  @service siteSettings;
  @service notifications; // This is the service in question

  static hidden() {
    return false;
  }

  @tracked icon = "paper-plane";

  @action
  async sendToTypefully() {
    // --- DEBUGGING START ---
    console.log('DEBUG: this.notifications object:', this.notifications);
    if (this.notifications) {
      console.log('DEBUG: Type of this.notifications.error:', typeof this.notifications.error);
      if (typeof this.notifications.error !== 'function') {
        console.error('DEBUG: this.notifications exists, but .error is NOT a function. It is:', this.notifications.error);
        // Fallback for debugging if notifications.error is truly missing or not a function
        // In a real app, you'd want a more robust error display mechanism if the notification service fails.
        // For now, this helps confirm the issue.
        alert("Discourse Notifications service 'error' method is unavailable. Check console for details.");
      }
    } else {
      console.error('DEBUG: this.notifications object is undefined or null. Service injection might be failing.');
      alert("Discourse Notifications service is unavailable. Check console for details.");
    }
    // --- DEBUGGING END ---

    this.icon = "spinner";

    const postContents = await this.fetchRawPost(this.args.post.id);

    if (!postContents) {
      // Defensive check before calling notifications.error
      if (this.notifications && typeof this.notifications.error === 'function') {
        this.notifications.error("Could not retrieve post content.");
      } else {
        console.error("Could not retrieve post content, and notifications service is not fully functional.");
      }
      this.resetIcon();
      return;
    }

    const typefullyApiKey = this.siteSettings.typefully_api_key;

    if (!typefullyApiKey || typefullyApiKey === 'YOUR_TYPEFULLY_API_KEY_PLACEHOLDER') {
      if (this.notifications && typeof this.notifications.error === 'function') {
        this.notifications.error("Typefully API key is not configured. Please set it in Discourse site settings.");
      } else {
        console.error("Typefully API key is not configured, and notifications service is not fully functional.");
      }
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
        if (this.notifications && typeof this.notifications.success === 'function') {
          this.notifications.success(`Draft sent to Typefully! Draft ID: ${data.id}`);
        }
        this.icon = "check";
        console.log("Typefully API Response:", data);
      } else {
        const errorData = await response.json();
        const errorMessage = errorData.message || response.statusText;
        if (this.notifications && typeof this.notifications.error === 'function') {
          this.notifications.error(`Failed to send draft: ${errorMessage}`);
        } else {
          console.error(`Failed to send draft: ${errorMessage}, and notifications service is not fully functional.`);
        }
        this.icon = "exclamation-triangle";
        console.error("Typefully API Error:", errorData);
      }
    } catch (error) {
      if (this.notifications && typeof this.notifications.error === 'function') {
        this.notifications.error(`An error occurred: ${error.message}. Check console for details.`);
      } else {
        console.error(`An error occurred: ${error.message}, and notifications service is not fully functional.`);
      }
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
