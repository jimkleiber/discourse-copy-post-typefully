import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from '@ember/service'; // Import service for siteSettings and notifications
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

export default class SendToTypefullyButton extends Component {
  // Inject the siteSettings service to access configured API keys
  @service siteSettings;
  // Inject the notifications service for user feedback
  @service notifications;

  // Define if the button should be hidden by default
  static hidden() {
    return false;
  }

  // Track the icon state for visual feedback (e.g., loading, success)
  @tracked icon = "paper-plane"; // Default icon for sending

  // Action to handle sending the post to Typefully
  @action
  async sendToTypefully() {
    // Show a loading spinner
    this.icon = "spinner";

    // Get the raw content of the post
    // The `fetchRawPost` method is ideal as Typefully expects plain text or markdown.
    const postContents = await this.fetchRawPost(this.args.post.id);

    if (!postContents) {
      this.notifications.error("Could not retrieve post content.");
      this.resetIcon();
      return;
    }

    // Retrieve the Typefully API key from Discourse site settings
    // You must create a site setting named 'typefully_api_key' in your Discourse admin.
    const typefullyApiKey = this.siteSettings.typefully_api_key;

    if (!typefullyApiKey || typefullyApiKey === 'YOUR_TYPEFULLY_API_KEY_PLACEHOLDER') {
      this.notifications.error("Typefully API key is not configured. Please set it in Discourse site settings.");
      this.resetIcon();
      return;
    }

    try {
      // Prepare the payload for the Typefully API
      const payload = {
        content: postContents,
        threadify: true, // This crucial parameter tells Typefully to auto-split the content
        // You can add other Typefully API options here, e.g.:
        // schedule_date: "next-free-slot",
        // share: true,
      };

      // Make the API call to Typefully
      const response = await fetch('https://api.typefully.com/v1/drafts/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': typefullyApiKey, // Use the API key from site settings
        },
        body: JSON.stringify(payload),
      });

      // Handle the API response
      if (response.ok) {
        const data = await response.json();
        this.notifications.success(`Draft sent to Typefully! Draft ID: ${data.id}`);
        this.icon = "check"; // Success icon
        console.log("Typefully API Response:", data);
      } else {
        const errorData = await response.json();
        const errorMessage = errorData.message || response.statusText;
        this.notifications.error(`Failed to send draft: ${errorMessage}`);
        this.icon = "exclamation-triangle"; // Error icon
        console.error("Typefully API Error:", errorData);
      }
    } catch (error) {
      // Catch network errors or issues with the fetch operation
      this.notifications.error(`An error occurred: ${error.message}. Check console for details.`);
      this.icon = "exclamation-triangle"; // Error icon
      console.error("Network or API call error:", error);
      // Use Discourse's popupAjaxError for more detailed debugging if needed
      popupAjaxError(error);
    } finally {
      // Reset the icon after a delay, regardless of success or failure
      discourseLater(() => {
        this.icon = "paper-plane";
      }, 2000);
    }
  }

  // Helper function to fetch the raw content of the post
  async fetchRawPost(postId) {
    try {
      const { raw } = await ajax(`/posts/${postId}.json`);
      return raw;
    } catch (error) {
      // Use popupAjaxError for network/server errors during raw post fetch
      popupAjaxError(error);
      return null; // Return null if fetching fails
    }
  }

  // Helper to reset the icon
  resetIcon() {
    discourseLater(() => {
      this.icon = "paper-plane";
    }, 2000);
  }

  // Template for the DButton component
  <template>
    <DButton
      class="post-action-menu__send-to-typefully btn-flat"
      @title={{themePrefix "send_to_typefully_title"}} // Use a theme prefix for translatable title
      @icon={{this.icon}}
      @action={{this.sendToTypefully}} // Call the new action
      ...attributes
    />
  </template>
}
