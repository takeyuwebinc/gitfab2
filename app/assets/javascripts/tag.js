$(function() {
  $(document).on("ajax:success", ".delete-tag", function() {
    const link = $(this);
    const li = link.closest("li");
    li.remove();
  });

  $(document).on("ajax:success", "#tag-form", function(event) {
    const form = $(this);
    const ul = form.siblings(".tags");
    ul.append(event.detail[0].html);
    const list = ul.find("li");
    if (list.length > 10) {
      const link = $(list.get(0)).find(".delete-tag");
      link.click();
    }
  });

  $(document).on("ajax:error", "#tag-form, .delete-tag", function(event) {
    let response = event.detail[0];
    // レスポンスが文字列の場合はJSONとしてパースを試みる
    if (typeof response === "string") {
      try {
        response = JSON.parse(response);
      } catch (e) {
        // パースに失敗した場合はそのまま使用
      }
    }
    const message = (response && (response.message || response.error)) || "An error occurred";
    alert(message);
    event.preventDefault();
  });

  $(document).on("click", "#show-tag-form", function(event) {
    $("#tag-form").show();
    $(this).hide();
    event.preventDefault();
  });
});
