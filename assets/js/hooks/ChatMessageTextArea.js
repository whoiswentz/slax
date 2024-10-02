const ChatMessageTextArea = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      console.log("ajsdkasjdkasjdkasjdk");
      if (e.key == "Enter" && !e.shiftKey) {
        const form = document.getElementById("new-message-form");
        form.dispatchEvent(
          new Event("change", { bubbles: true, cancelable: true })
        );
        form.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true })
        );
      }
    });

    const typingTimeout = 500;
    let typingTimer;

    this.el.addEventListener("keyup", (e) => {
      clearTimeout(typingTimer);
      this.pushEvent("user_typing");

      typingTimer = setTimeout(() => {
        this.pushEvent("user_stop_typing");
      }, typingTimeout);
    });
  },
};

export default ChatMessageTextArea;
