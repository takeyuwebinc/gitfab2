//= require jquery.colorbox
let editor = null;

const setupNicEditor = function() {
  editor = new nicEditor({
    buttonList: ["material", "tool", "blueprint", "attachment", "ol", "ul", "bold", "italic", "underline"]
  });
  editor.panelInstance("markup-area");
  $(".nicEdit-main").addClass("validate");
};

const descriptionText = function() {
  for (let instance of editor.nicInstances) {
    const html_text = instance.getContent();
    return html_text.replace(/<("[^"]*"|'[^']*'|[^'">])*>/g, '');
  }
};

const validateForm = function(event, is_note_card_form) {
  if (!is_note_card_form) {
    if (descriptionText().length > 300) {
      alert("Description text should be less than 300.");
      event.preventDefault();
    }
  }

  let validated = false;
  $(".card-form:first-child .validate").each(function(index, element) {
    if (($(element).val() !== "") || ($(element).text() !== "")) {
      validated = true;
    }
  });
  if (!validated) {
    alert("You cannot make empty card.");
    event.preventDefault();
  }
};

const focusOnTitle = () => $(".card-title").first().focus();

const hideTemplateForms = function() {
  $("#card-form-container").css("display", "none");
  $("#state-convert-dialog").css("display", "none");
};

$(function() {
  $.rails.ajax = function(option) {
    option.xhr =  function() {
      const xhr = $.ajaxSettings.xhr();
      const form = $(`form[action='${option.url}']`);
      if (form && xhr.upload) {
        xhr.upload.addEventListener("progress", e => form.trigger("ajax:progress", [e]));
      }
      return xhr;
    };
    return $.ajax(option);
  };

  const formContainer = $(document.createElement("div"));
  formContainer.attr("id", "card-form-container");
  formContainer.appendTo(document.body);

  let cards_top = [];

  const getCardsTop = function() {
    cards_top = [];
    const cards = $("#making-list .state");
    //11 TODO: Show annotations index of focused status
    for (let card of cards) {
      cards_top.push(card.offsetTop);
    }
    return cards_top;
  };
  getCardsTop();

  const reloadRecipeCardsList = function() {
    if ($("#recipes-show").length < 1) { return; }
    const owner_id = $("#recipes-show").data("owner");
    const project_id = $("#recipes-show").data("project");
    const recipe_cards_index_url = `/users/${owner_id}/projects/${project_id}/recipe_cards_list`;
    $.ajax({
      type: "GET",
      url: recipe_cards_index_url,
      dataType: "json",
      success(data) {
        $("#recipe-cards-list").replaceWith(data.html);
        const scrollTop = $(window).scrollTop();
        const result = [];
        for (let i = 0; i < cards_top.length; i++) {
          const card_top = cards_top[i];
          if (scrollTop >= card_top) {
            result.push(setSelectorPosition(i));
          }
        }
        return result;
      },
      error(data) {
        alert(data.message);
      }
    });
  };

  const setSelectorPosition = function(n) {
    const link_height_in_card_index = 15;
    $("#recipe-cards-list .selector").css("margin-top", ((n * link_height_in_card_index) + 1) + "px");
  };

  $(window).on("load scroll resize", function(event) {
    const scrollTop = $(window).scrollTop();
    const result = [];
    for (let i = 0; i < cards_top.length; i++) {
      const card_top = cards_top[i];
      if (scrollTop >= card_top) {
        result.push(setSelectorPosition(i));
      }
    }
    return result;
  });
    //11 TODO: Show annotations index of focused status

  $(document).on("ajax:beforeSend", ".delete-card", () => confirm("Are you sure to remove this item?"));

  $(document).on("ajax:error", ".new-card, .edit-card, .delete-card", function(event, xhr, status, error) {
    alert(error.message);
    event.preventDefault();
  });

  $(document).on("click", ".card-form .submit", function(event) {
    const is_note_card_form = $(this).closest("form").attr("id").match(new RegExp("note_card", "g"));
    validateForm(event, is_note_card_form);
  });

  $(document).on("submit", ".card-form", function() {
    $(this).find(".submit")
    .off()
    .fadeTo(80, 0.01);
    $.colorbox.close();
  });

  $(document).on("ajax:success", ".new-card", function(xhr, data) {
    const link = $(this);
    const list = $(link.attr("data-list"));
    const template = $(link.attr("data-template") + " > :first");
    const className  = link.attr("data-classname");
    const li = $(document.createElement("li"));
    li.addClass("card-wrapper");
    li.addClass(className);
    let card = null;
    formContainer.html(data.html);
    setupNicEditor();
    setTimeout(focusOnTitle, 500);
    formContainer.find("form")
    .bind("submit", function(e) {
      card = template.clone();
      wait4save($(this), card);
      li.append(card);
      list.append(li);
  }).bind("ajax:success", function(xhr, data) {
      updateCard(card, data);
      if (li.hasClass("state-wrapper")) { fixCommentFormAction(li); }
    }).bind("ajax:error", function(xhr, status, error) {
      li.remove();
      alert(status);
    });
  });

  $(document).on("ajax:success", ".edit-card", function(xhr, data) {
    const li = $(this).closest("li");
    const card = $(li).children().first();
    formContainer.html(data.html);
    setupNicEditor();
    setTimeout(focusOnTitle, 1);
    formContainer.find("form")
    .bind("submit", function(e) {
      wait4save($(this), card);
  }).bind("ajax:success", function(xhr, data) {
      updateCard(card, data);
      if (li.hasClass("state-wrapper")) { fixCommentFormAction(li); }
    }).bind("ajax:error", (e, xhr, status, error) => alert(status));
  });

  $(document).on("ajax:success", ".new-card, .edit-card", function() {
    const form_object = $("#card-form-container");
    form_object.css("display", "block");
    $.colorbox({
      inline: true,
      href: form_object,
      width: "auto",
      maxHeight: "90%",
      opacity: 0.6,
      overlayClose: false,
      trapFocus: false,
      className: "colorbox-card-form"
    });
  });

  $(document).on("ajax:success", ".delete-card", function(xhr, data) {
    const link = $(this);
    const li = link.closest("li");
    li.remove();
    checkStateConvertiblity();
    setStateIndex();
    markup();
    setTimeout(getCardsTop, 100);
    reloadRecipeCardsList();
  });

  $(document).on("click", "#cboxClose", function(event) {
    event.preventDefault();
    $.colorbox.close();
    hideTemplateForms();
  });

  $(document).on("card-order-changed", "#recipe-card-list", event => setStateIndex());

  $(document).on("click", "#cboxOverlay.colorbox-card-form", function(event) {
    event.preventDefault();
    if (confirm("Are you sure to discard all changes on this dialog?")) {
      $.colorbox.close();
      hideTemplateForms();
    }
  });

  $(document).on("keyup", "#inner_content .nicEdit-main", function(event) {
    const description_text_length = descriptionText().length;
    $("#inner_content .plain-text-length").html(description_text_length);
    if (description_text_length > 300) {
      $(".text-length").css("color", "red");
    } else {
      $(".text-length").css("color", "black");
    }
  });

  $(document).on("click", ".convert-card", function(event) {
    event.preventDefault();
    const state = $(this).closest(".state");
    const src_data_position = state.data("position");
    const state_id = state.attr("id");
    if ($(".state").length > 2) {
      $("#state-convert-dialog .src").text(src_data_position);
      $("#state-convert-dialog").data("target", state_id);

      const select = $("#target_state");
      select.empty();
      const states = $(".state");
      states.each(function(index, element) {
        const position = $(element).data("position");
        const title = $(element).find(".title").first().text();
        const text = position + ": " + title;

        if ((position !== src_data_position) && (position !== "")) {
          select.append($("<option>").html(text).val(position));
        }
      });

      const state_convert_dialog = $("#state-convert-dialog");
      state_convert_dialog.css("display", "block");
      $.colorbox({
        inline: true,
        href: state_convert_dialog,
        width: "auto",
        maxHeight: "90%",
        opacity: 0.6
      });

    } else {
      alert("First, make 2 or more state.");
    }
  });

  $(document).on("click", "#state-convert-dialog .ok-btn", function(event) {
    event.preventDefault();
    const dst_data_position = $("#target_state").val();
    const dst_state = $(`.state[data-position=${dst_data_position}]`);
    const dst_state_id = dst_state.attr("id");

    const recipe_url = $("#recipes-show").data("url");
    const state_id = $("#state-convert-dialog").data("target");
    const convert_url = recipe_url + "/states/" + state_id + "/to_annotation";

    $.ajax({
      url: convert_url,
      type: "GET",
      data: {
              dst_position: dst_data_position,
              dst_state_id
            },
      dataType: "json",
      success(data) {
        const new_annotation_id = data.$oid;
        const new_annotation_url = recipe_url + "/states/" + dst_state_id + "/annotations/" + new_annotation_id;
        $.colorbox.close();
        const loading = $("#loading");
        const img = loading.find("img");
        const left = (loading.width() - img.width()) / 2;
        const top = (loading.height() - img.height()) / 2;
        $(img).css("left", left + "px").css("top", top + "px");
        loading.show();

        $.ajax({
          url: new_annotation_url,
          type: "GET",
          dataType: "json",
          success(data) {
            //TODO: refactoring: make card append function
            const annotation_template = $("#annotation-template > :first");
            const card = annotation_template.clone();
            const li = $(document.createElement("li"));
            li.addClass("card-wrapper");
            li.addClass("annotation-wrapper");
            li.append(card);
            $(`#${dst_state_id} .annotation-list`).append(li);
            $(`#${state_id}`).closest(".state-wrapper").remove();

            const article_id = $(data.html).find(".slick").closest("article").attr("id");
            const selector = `#${article_id} .slick`;
            card.replaceWith(data.html);
            setupFigureSlider(selector);
            $("#loading").hide();
            checkStateConvertiblity();
            setStateIndex();
            markup();
          },
          error(data) {
            alert(data.message);
          }
        });
      },

      error(data) {
        alert(data.message);
      }
    });
  });


  $(document).on("click", ".to-state", function(event) {
    event.preventDefault();
    const convert_url = $(this).attr("href");
    const recipe_url = $("#recipes-show").data("url");
    const annotation_id = $(this).closest(".annotation").attr("id");

    $.ajax({
      url: convert_url,
      type: "GET",
      dataType: "json",
      success(data) {
        const new_state_id = data.$oid;
        const new_state_url = recipe_url + "/states/" + new_state_id;
        const loading = $("#loading");
        const img = loading.find("img");
        const left = (loading.width() - img.width()) / 2;
        const top = (loading.height() - img.height()) / 2;
        $(img).css("left", left + "px").css("top", top + "px");
        loading.show();

        $.ajax({
          url: new_state_url,
          type: "GET",
          dataType: "json",
          success(data) {
            //TODO: refactoring: make card append function
            const state_template = $("#state-template > :first");
            const card = state_template.clone();
            const li = $(document.createElement("li"));
            li.addClass("card-wrapper");
            li.addClass("state-wrapper");
            li.append(card);
            $("#recipe-card-list").append(li);

            const article_id = $(data.html).find(".slick").closest("article").attr("id");
            const selector = `#${article_id} .slick`;
            card.replaceWith(data.html);
            setupFigureSlider(selector);
            $("#loading").hide();
            $(`#${annotation_id}`).closest("li").remove();
            checkStateConvertiblity();
            setStateIndex();
            markup();
          },
          error(data) {
            alert(data.message);
          }
        });
      },
      error(data) {
        alert(data.message);
      }
    });
  });

  const wait4save = function(form, card) {
    card.addClass("wait4save");
    const card_content = card.find(".card-content:first");
    const title = form.find(".card-title").val();
    card_content.find(".title").text(title);

    const ul = card_content.find("figure ul");
    ul.empty();
    const figures = form.find(".card-figure-content");
    for (let figure of figures) {
      let src;
      if (figure.files.length > 0) {
        src = window.URL.createObjectURL(figure.files[0]);
      } else {
        src = $(figure).val();
      }
      const img = $(document.createElement("img"));
      img.attr("src", src);
      const li = $(document.createElement("li"));
      li.append(img);
      ul.append(li);
    }
    let description = form.find(".card-description").val();
    if ((description === "") || (description === null)) {
      description = $("#inner_content").find(".nicEdit-main").html();
      form.find(".card-description").html(description);
    }
    card_content.find(".description").html(description);
    const progress = $(document.createElement("progress"));
    progress.attr("max", 1.0);
    progress.attr("form", form.attr("id"));
    card_content.append(progress);
    form.bind("ajax:progress", (e, progressEvent) => progress.attr("value", progressEvent.loaded / progressEvent.total));
  };

  const markup = function() {
    const attachments = $(".attachment");
    for (let attachment of attachments) {
      const markupid = attachment.getAttribute("data-markupid");
      const content = attachment.getAttribute("data-content");
      if (content && (content.length > 0)) {
        $(`#${markupid}`).attr("href", content);
      }
    }
    $(document.body).trigger("attachment-markuped");
  };
  markup();

  const checkStateConvertiblity = function() {
    const states = $(".state");
    states.each(function(index, element) {
      if ($(element).find(".annotation").length === 0) {
        $(element).find(".convert-card").show();
      } else {
        $(element).find(".convert-card").hide();
      }
    });
  };
  checkStateConvertiblity();

  const setStateIndex = function() {
    const states = $(".state-wrapper");
    states.each(function(index, element) {
      $(element).find("h1.number").text(index + 1);
      $(element).find(".state").data("position", index + 1);
    });
    if (states.length > 1) {
      $(".order-change-btn").show();
    } else {
      $(".order-change-btn").hide();
    }
  };
  setStateIndex();

  const setupFigureSlider = selector =>
    $(selector).slick({
      adaptiveHeight: true,
      dots: true,
      infinite: true,
      speed: 300
    });

  const updateCard = function(card, data) {
    formContainer.empty();
    const article_id = $(data.html).find(".slick").closest("article").attr("id");
    const selector = `#${article_id} .slick`;
    card.replaceWith(data.html);
    checkStateConvertiblity();
    setStateIndex();
    markup();
    setTimeout(() => setupFigureSlider(selector)
    , 100);
    setTimeout(getCardsTop, 100);
    reloadRecipeCardsList();

    if (card.length === 0) {
      location.reload();
    }
  };

  const fixCommentFormAction = function(li) {
    const card = li.find(".card");
    const card_id = card.attr("id");
    const comment_form = card.find("#new_comment");
    const comment_form_action = comment_form.attr("action");
    const new_comment_form_action = comment_form_action.replace(/\/states\/.+\/comments/, `/states/${card_id}/comments`);
    comment_form.attr("action", new_comment_form_action);
  };
});